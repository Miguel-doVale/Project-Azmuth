"""Azmuth: processos, desempenho e inicialização, sem dependências extras."""
from __future__ import annotations

import configparser
import fcntl
import hashlib
import json
import os
import pwd
import re
import shutil
import signal
import subprocess
import sys
import time
from functools import lru_cache
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "azmuth"
DATA = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share"))
PROC = Path("/proc")
CLOCK = os.sysconf("SC_CLK_TCK")
PAGE = os.sysconf("SC_PAGE_SIZE")
UID = os.getuid()
UI = ROOT / "taskmanager"
REQUEST = STATE / "tasks-request.json"
PROTECTED = {
    "hyprland", "quickshell", "qs", "quickshell-launcher", "quickshell-laun",
    "systemd", "dbus-broker", "dbus-daemon", "dbus-broker-lau", "hyprpolkitagent",
    "hypridle", "hyprpaper", "pipewire", "wireplumber", "pipewire-pulse",
    "networkmanager", "gnome-keyring-d", "kwalletd6", "sddm", "sddm-helper",
}
STATES = {"R": "Executando", "S": "Em espera", "D": "Aguardando disco",
          "T": "Pausado", "t": "Em depuração", "Z": "Finalizado", "I": "Ocioso"}
SIGNALS = {"term": signal.SIGTERM, "kill": signal.SIGKILL,
           "stop": signal.SIGSTOP, "cont": signal.SIGCONT}


def atomic(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".azmuth.tmp")
    if path.exists():
        temp.write_text(text)
        temp.chmod(path.stat().st_mode & 0o777)
    else:
        temp.write_text(text)
        temp.chmod(0o600)
    temp.replace(path)


def parse_stat(text: str):
    head, _, tail = text.rpartition(")")
    pid, _, name = head.partition(" (")
    f = tail.split()
    if not name or len(f) < 22:
        raise ValueError("Registro de processo incompleto.")
    return {
        "pid": int(pid), "name": name, "state": f[0], "ppid": int(f[1]),
        "ticks": int(f[11]) + int(f[12]), "nice": int(f[16]),
        "threads": int(f[17]), "start": int(f[19]),
        "vms": int(f[20]), "rss": max(0, int(f[21])) * PAGE,
    }


@lru_cache(maxsize=256)
def username(uid):
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return str(uid)


def read_process(pid: int):
    path = PROC / str(pid)
    value = parse_stat((path / "stat").read_text())
    value["uid"] = path.stat().st_uid
    try:
        argv = (path / "cmdline").read_bytes().decode("utf-8", "replace").strip("\0").split("\0")
        value["argv"] = argv if argv != [""] else []
    except OSError:
        value["argv"] = []
    try:
        value["exe"] = os.readlink(path / "exe")
    except OSError:
        value["exe"] = ""
    value["command"] = " ".join(value["argv"]) or "[" + value["name"] + "]"
    value["key"] = f"{pid}:{value['start']}"
    value["user"] = username(value["uid"])
    value["status"] = STATES.get(value["state"], value["state"])
    value["reason"] = protected_reason(value)
    value["can_signal"] = not value["reason"]
    return value


def protected_reason(p):
    if p["pid"] <= 1 or p["pid"] in (os.getpid(), os.getppid()):
        return "Componente do diagnóstico ou da sessão."
    if p["uid"] != UID:
        return "Este processo pertence a outro usuário."
    exe = Path(p.get("exe", "")).name.casefold()
    if p["name"].casefold() in PROTECTED or exe in PROTECTED:
        return "Componente que mantém sua sessão funcionando."
    args = p.get("argv", [])
    if str(ROOT / "src/core.py") in args and "tasks" in args:
        return "Leitor do próprio gerenciador."
    if not args:
        return "Processo interno do sistema."
    return ""


def cpu_counters():
    out = {}
    for line in (PROC / "stat").read_text().splitlines():
        parts = line.split()
        if parts and re.fullmatch(r"cpu\d*", parts[0]):
            values = list(map(int, parts[1:9]))
            if len(values) >= 5:
                out[parts[0]] = (sum(values), values[3] + values[4])
    return out


def memory():
    m = {}
    for line in (PROC / "meminfo").read_text().splitlines():
        key, _, value = line.partition(":")
        m[key] = int(value.split()[0]) * 1024
    total = m.get("MemTotal", 1)
    available = m.get("MemAvailable", m.get("MemFree", 0))
    return {"total": total, "used": total - available,
            "percent": 100 * (1 - available / total),
            "swap_total": m.get("SwapTotal", 0),
            "swap_used": m.get("SwapTotal", 0) - m.get("SwapFree", 0)}


def io_counters():
    disks = {}
    for line in (PROC / "diskstats").read_text().splitlines():
        p = line.split()
        if len(p) < 10:
            continue
        name = p[2]
        if not (Path("/sys/block") / name).exists() or name.startswith(("loop", "ram", "zram", "dm-")):
            continue
        disks[name] = (int(p[5]) * 512, int(p[9]) * 512)
    net = {}
    for line in (PROC / "net/dev").read_text().splitlines()[2:]:
        name, _, raw = line.partition(":")
        name = name.strip()
        values = raw.split()
        if name != "lo" and len(values) >= 9:
            net[name] = (int(values[0]), int(values[8]))
    physical = {k: v for k, v in net.items() if (Path("/sys/class/net") / k / "device").exists()}
    return disks, physical or net


@lru_cache(maxsize=1)
def machine():
    cpu = "Processador"
    for line in (PROC / "cpuinfo").read_text().splitlines():
        if line.startswith("model name"):
            cpu = line.partition(":")[2].strip()
            break
    temp = None
    for zone in Path("/sys/class/thermal").glob("thermal_zone*"):
        try:
            kind = (zone / "type").read_text().strip()
            if temp is None or kind in ("x86_pkg_temp", "cpu-thermal"):
                temp = zone / "temp"
            if kind in ("x86_pkg_temp", "cpu-thermal"):
                break
        except OSError:
            pass
    return {"cpu_model": cpu, "cores": os.cpu_count() or 1, "temp_path": temp}


class Sampler:
    def __init__(self):
        self.previous = {}
        self.old_cpu = {}
        self.old_time = None
        self.old_disk = {}
        self.old_net = {}

    def sample(self):
        now = time.monotonic()
        uptime = float((PROC / "uptime").read_text().split()[0])
        cpus = cpu_counters()
        total = cpus["cpu"][0]
        delta = total - self.old_cpu.get("cpu", cpus["cpu"])[0]
        dt = max(.01, now - self.old_time) if self.old_time is not None else 0
        processes, current = [], {}
        for path in PROC.iterdir():
            if not path.name.isdecimal():
                continue
            try:
                p = read_process(int(path.name))
                previous = self.previous.get(p["key"], p["ticks"])
                p["cpu"] = round(max(0., min(100., (p["ticks"] - previous) / delta * 100)), 2) if delta > 0 else 0.
                p["age"] = max(0, uptime - p["start"] / CLOCK)
                current[p["key"]] = p["ticks"]
                p.pop("ticks")
                p.pop("argv")
                processes.append(p)
            except (OSError, ValueError, IndexError):
                continue
        loads = {}
        for name, (ticks, idle) in cpus.items():
            old_ticks, old_idle = self.old_cpu.get(name, (ticks, idle))
            loads[name] = round(max(0, min(100, 100 * (1 - (idle - old_idle) / (ticks - old_ticks)))), 1) if ticks > old_ticks else 0.
        disks, net = io_counters()

        def rates(current, old):
            return [{"name": name, "read": max(0, values[0] - old.get(name, values)[0]) / dt if dt else 0,
                     "write": max(0, values[1] - old.get(name, values)[1]) / dt if dt else 0}
                    for name, values in current.items()]

        disk_rates, net_rates = rates(disks, self.old_disk), rates(net, self.old_net)
        info = machine()
        temp = 0.
        if info["temp_path"]:
            try:
                temp = int(info["temp_path"].read_text()) / 1000
            except (OSError, ValueError):
                pass
        self.previous, self.old_cpu, self.old_time = current, cpus, now
        self.old_disk, self.old_net = disks, net
        return {"ok": True, "sampled": bool(dt), "timestamp": time.time(),
                "system": {"cpu": loads["cpu"], "cores": [v for k, v in loads.items() if k != "cpu"],
                           "cpu_model": info["cpu_model"], "core_count": info["cores"],
                           "memory": memory(), "temperature": temp, "uptime": uptime,
                           "process_count": len(processes), "threads": sum(p["threads"] for p in processes),
                           "disks": disk_rates, "network": net_rates},
                "processes": processes, "groups": group_processes(processes)}


# ───────────── agrupamento (como no Gerenciador de Tarefas do Windows) ─────────────
# Cada processo sobe pela árvore até a "raiz" da sessão (Hyprland, systemd); a raiz e seus
# descendentes formam um grupo. Grupos com janela = Aplicativos.

KNOWN = {   # nome do processo → (nome amigável, o que é)
    "chrome": ("Google Chrome", "Navegador · cada aba e extensão roda num processo próprio"),
    "chromium": ("Chromium", "Navegador · um processo por aba e extensão"),
    "firefox": ("Firefox", "Navegador"),
    "claude-desktop": ("Claude Desktop", "App do Claude (Electron: vários processos auxiliares)"),
    "claude": ("Claude Code", "Assistente de programação no terminal"),
    "codex": ("Codex", "Assistente de programação no terminal"),
    "electron": ("App Electron", "App feito com Electron (vários processos auxiliares)"),
    "code": ("Visual Studio Code", "Editor de código (Electron)"),
    "obsidian": ("Obsidian", "Notas"),
    "kitty": ("Kitty", "Terminal · inclui o que está rodando dentro dele"),
    "dolphin": ("Dolphin", "Explorador de arquivos"),
    "Docker Desktop": ("Docker Desktop", "Contêineres e máquina virtual do Docker"),
    "com.docker.back": ("Docker Desktop · backend", "Serviço do Docker Desktop"),
    "dockerd": ("Docker", "Serviço de contêineres"),
    "containerd": ("containerd", "Execução de contêineres do Docker"),
    "Hyprland": ("Hyprland", "Compositor: desenha as janelas e a tela"),
    "Xwayland": ("Xwayland", "Compatibilidade com apps antigos (X11)"),
    "pipewire": ("PipeWire", "Servidor de áudio e captura de tela"),
    "pipewire-pulse": ("PipeWire · Pulse", "Compatibilidade de áudio com apps PulseAudio"),
    "wireplumber": ("WirePlumber", "Escolhe saídas e entradas de áudio"),
    "easyeffects": ("EasyEffects", "Equalizador do painel de Som"),
    "xdg-desktop-portal": ("Portal do desktop", "Diálogos de arquivo, compartilhar tela, permissões"),
    "xdg-desktop-por": ("Portal do desktop", "Diálogos de arquivo, compartilhar tela, permissões"),
    "xdg-document-po": ("Portal de documentos", "Acesso a arquivos por apps isolados"),
    "xdg-permission-": ("Portal de permissões", "Guarda as permissões dadas a apps"),
    "dbus-broker": ("D-Bus", "Barramento de mensagens entre programas"),
    "dbus-broker-lau": ("D-Bus", "Barramento de mensagens entre programas"),
    "dbus-daemon": ("D-Bus", "Barramento de mensagens entre programas"),
    "systemd": ("systemd", "Inicia e vigia os serviços do sistema"),
    "systemd-journal": ("Registros do sistema", "Guarda os logs (journalctl)"),
    "systemd-logind": ("Login e sessões", "Controla sessões, suspensão e botão de energia"),
    "systemd-udevd": ("Dispositivos", "Detecta o que é conectado (USB, fones…)"),
    "systemd-timesyn": ("Relógio", "Acerta a hora pela internet"),
    "systemd-userwor": ("systemd · usuários", "Consulta de contas do sistema"),
    "systemd-userdbd": ("systemd · usuários", "Consulta de contas do sistema"),
    "systemd-resolve": ("DNS", "Traduz nomes de sites"),
    "NetworkManager": ("NetworkManager", "Wi-Fi e rede"),
    "wpa_supplicant": ("wpa_supplicant", "Autenticação Wi-Fi"),
    "bluetoothd": ("Bluetooth", "Serviço Bluetooth (BlueZ)"),
    "upowerd": ("UPower", "Bateria e energia"),
    "udisksd": ("UDisks", "Discos e pendrives"),
    "polkitd": ("polkit", "Decide pedidos de permissão de administrador"),
    "hyprpolkitagent": ("Senha de administrador", "Mostra a janela de senha do polkit"),
    "sddm": ("SDDM", "Tela de login"),
    "sddm-helper": ("SDDM", "Sessão aberta pela tela de login"),
    "Xorg": ("Xorg", "Servidor gráfico da tela de login"),
    "hypridle": ("hypridle", "Bloqueio e tela desligada por inatividade"),
    "hyprpaper": ("hyprpaper", "Papel de parede"),
    "wl-paste": ("Área de transferência", "Guarda o histórico (cliphist)"),
    "ollama": ("Ollama", "IA local (reserva do assistente)"),
    "gnome-keyring-d": ("Chaveiro", "Guarda senhas de apps"),
    "kwalletd6": ("KWallet", "Guarda senhas de apps KDE"),
    "gvfsd": ("GVfs", "Lixeira, pendrives e arquivos remotos"),
    "at-spi-bus-laun": ("Acessibilidade", "Leitores de tela e acessibilidade"),
    "cupsd": ("CUPS", "Impressoras"),
    "avahi-daemon": ("Avahi", "Descoberta de dispositivos na rede"),
    "crond": ("cron", "Tarefas agendadas"),
    "sshd": ("SSH", "Acesso remoto"),
    "notify-send": ("Notificação", "Notificação esperando um clique"),
    "chrome_crashpad": ("Chrome · relatório de falhas", "Envia relatórios quando o Chrome trava"),
    "cowork-linux-he": ("Claude · auxiliar", "Processo auxiliar do Claude Desktop"),
    "start-hyprland": ("Sessão Hyprland", "Mantém o Hyprland e toda a sua sessão de pé"),
    "mariadbd": ("MariaDB", "Banco de dados (MySQL)"),
    "postgres": ("PostgreSQL", "Banco de dados"),
    "docker-proxy": ("Docker · rede", "Encaminha portas dos contêineres"),
    "rtkit-daemon": ("RealtimeKit", "Prioridade para áudio sem cortes"),
    "power-profiles-": ("Perfis de energia", "Economia, equilibrado ou desempenho"),
}
SESSION_ROOTS = {"Hyprland", "systemd", "sddm", "sddm-helper", "init"}
SHELLS = {"sh", "bash", "zsh", "fish", "dash"}


@lru_cache(maxsize=1)
def desktop_index():
    """classe da janela / nome do executável → (nome, ícone) a partir dos .desktop."""
    out = {}
    for d in application_dirs():
        for f in d.glob("*.desktop") if d.exists() else []:
            try:
                e = read_desktop(f)
            except (OSError, configparser.Error):
                continue
            name, icon = e.get("Name", ""), e.get("Icon", "")
            if not name or e.get("NoDisplay", "").lower() == "true":
                continue
            keys = {f.stem.lower(), f.stem.split(".")[-1].lower()}
            if e.get("StartupWMClass"):
                keys.add(e["StartupWMClass"].lower())
            cmd = (e.get("Exec", "").split() or [""])[0]
            if cmd:
                keys.add(Path(cmd).name.lower())
            for k in keys:
                out.setdefault(k, (name, icon))
    return out


def window_pids():
    try:
        clients = json.loads(subprocess.run(["hyprctl", "clients", "-j"], capture_output=True,
                                            text=True, timeout=3).stdout or "[]")
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return {}
    out = {}
    for c in clients:
        if c.get("pid", 0) > 0:
            out.setdefault(c["pid"], []).append({"class": c.get("class", ""), "title": c.get("title", "")})
    return out


def is_component(p):
    """Parte da rice: a shell (qs) do projeto ou um script Python de src/ e bin/."""
    cmd = p["command"]
    if p["name"] in ("qs", "quickshell"):
        return str(ROOT) in cmd or "-p" not in cmd   # [qs] zumbi/sem argumentos também é da shell
    return p["name"].startswith("python") and (str(ROOT / "src") + "/" in cmd or str(ROOT / "bin") + "/" in cmd)


def group_processes(processes):
    by_pid = {p["pid"]: p for p in processes}
    wins = window_pids()

    def root_of(p):
        seen = set()
        while True:
            parent = by_pid.get(p["ppid"])
            if (parent is None or parent["pid"] in seen or parent["pid"] <= 1
                    or parent["name"] in SESSION_ROOTS or parent["uid"] != p["uid"]):
                return p
            seen.add(p["pid"])
            p = parent

    groups = {}
    for p in processes:
        if p["pid"] == 2 or p["ppid"] == 2:
            gid = "kernel"
        else:
            # toda a rice num grupo só, onde quer que cada parte tenha sido iniciada (até de um terminal)
            q, seen, azmuth = p, set(), False
            while q and q["pid"] not in seen and q["pid"] > 1 and q["name"] not in SESSION_ROOTS:
                if is_component(q):
                    azmuth = True
                    break
                seen.add(q["pid"])
                q = by_pid.get(q["ppid"])
            gid = "azmuth" if azmuth else "g" + str(root_of(p)["pid"])
        p["group"] = gid
        groups.setdefault(gid, []).append(p)

    index = desktop_index()
    result = []
    for gid, members in groups.items():
        members.sort(key=lambda m: m["pid"])
        root = by_pid.get(int(gid[1:])) if gid.startswith("g") else None
        windows = [w for m in members for w in wins.get(m["pid"], [])]
        # nome representativo: o dono da janela, senão o primeiro que não é shell
        lead = next((m for m in members if m["pid"] in wins), None) or next(
            (m for m in members if m["name"] not in SHELLS), members[0])
        if gid == "kernel":
            kind, name, desc, icon = "kernel", "Kernel do Linux", "Threads internas do kernel (não são programas)", ""
        else:
            cls = windows[0]["class"].lower() if windows else ""
            entry = index.get(cls) or index.get(lead["name"].lower()) or index.get(Path(lead.get("exe", "")).name.lower())
            known = KNOWN.get(lead["name"]) or KNOWN.get(Path(lead.get("exe", "")).name)
            name = (entry[0] if entry else None) or (known[0] if known else None) or (windows[0]["class"] if windows else lead["name"])
            desc = known[1] if known else (windows[0]["title"] if windows else "")
            icon = entry[1] if entry else (cls or lead["name"].lower())
            if gid == "azmuth":
                kind, name, desc, icon = "azmuth", "Project Azmuth", "Barra, Omnitrix, widgets e serviços da rice", ""
            elif windows:
                kind = "app"
            elif lead["uid"] != UID:
                kind = "system"
            else:
                kind = "background"
        lead_ref = root or lead
        reasons = [m["reason"] for m in members if m["reason"]]
        # um componente de sessão dentro do grupo protege o grupo todo (ex.: start-hyprland → Hyprland)
        session = next((r for r in reasons if "sessão" in r), "")
        result.append({
            "id": gid, "kind": kind, "name": name, "desc": desc, "icon": icon,
            "count": len(members), "windows": len(windows),
            "cpu": round(sum(m["cpu"] for m in members), 2), "rss": sum(m["rss"] for m in members),
            "user": lead_ref["user"], "root_pid": lead_ref["pid"], "root_start": lead_ref["start"],
            "members": [m["key"] for m in members],
            "can_signal": kind not in ("kernel", "system", "azmuth") and not lead_ref["reason"] and not session,
            "reason": ("Threads do kernel não podem ser encerradas." if kind == "kernel"
                       else "Componente da rice: use azmuth send para reiniciar." if kind == "azmuth"
                       else session or lead_ref["reason"] or (reasons[0] if kind == "system" and reasons else "")),
        })
    return result


def control_group(action: str, refs: list[str]):
    """Sinal para um grupo inteiro: encerrar manda TERM à raiz; forçar manda KILL a todos."""
    pairs = []
    for ref in refs:
        pid, _, start = ref.partition(":")
        pairs.append((int(pid), int(start)))
    if not pairs:
        raise ValueError("Grupo vazio.")
    targets = pairs if action in ("kill", "stop", "cont") else pairs[:1]
    done, errors = 0, []
    for pid, start in targets:
        try:
            control_process(pid, start, action)
            done += 1
        except (ValueError, ProcessLookupError, OSError) as exc:
            errors.append(str(exc))
    if not done:
        raise ValueError(errors[0] if errors else "Nada foi encerrado.")
    labels = {"term": "Pedido de encerramento enviado.", "kill": f"Encerramento forçado: {done} processo(s).",
              "stop": f"{done} processo(s) pausado(s).", "cont": f"{done} processo(s) retomado(s)."}
    return {"ok": True, "message": labels[action]}


def control_process(pid: int, start: int, action: str):
    if pid <= 1 or action not in SIGNALS:
        raise ValueError("Ação ou processo inválido.")
    if not hasattr(os, "pidfd_open") or not hasattr(signal, "pidfd_send_signal"):
        raise ValueError("O controle de processos precisa de pidfd neste sistema.")
    fd = os.pidfd_open(pid)
    try:
        process = read_process(pid)
        if process["start"] != start:
            raise ValueError("O processo selecionado terminou. Atualize a lista.")
        reason = protected_reason(process)
        if reason:
            raise ValueError(reason)
        signal.pidfd_send_signal(fd, SIGNALS[action])
        if action == "term" and process["state"] == "T":
            # SIGTERM fica pendente num processo pausado até que ele seja retomado.
            try:
                signal.pidfd_send_signal(fd, signal.SIGCONT)
            except ProcessLookupError:
                pass
    finally:
        os.close(fd)
    labels = {"term": "Pedido de encerramento enviado.", "kill": "Encerramento forçado solicitado.",
              "stop": "Processo pausado.", "cont": "Processo retomado."}
    return {"ok": True, "message": labels[action]}


def read_desktop(path):
    c = configparser.ConfigParser(interpolation=None, strict=False)
    c.optionxform = str
    c.read(path, encoding="utf-8")
    return dict(c["Desktop Entry"]) if c.has_section("Desktop Entry") else {}


def flag(value):
    return str(value).casefold() == "true"


def desktop_name(d, fallback):
    return d.get("Name[pt_BR]") or d.get("Name[pt]") or d.get("Name") or fallback


def write_desktop(path, values):
    import file_manager
    if path.is_symlink():
        raise ValueError("O arquivo de inicialização é um link; edite a origem.")
    before = path.read_text() if path.exists() else ""
    if before and not (STATE / "startup-backups" / path.name).exists():
        atomic(STATE / "startup-backups" / path.name, before)
    atomic(path, file_manager.merged_config(before, {"Desktop Entry": values}))


def startup_dirs():
    others = os.environ.get("XDG_CONFIG_DIRS", "/etc/xdg").split(":")
    return [CONFIG / "autostart"] + [Path(p) / "autostart" for p in others if p]


def in_desktop(d):
    desktops = set(os.environ.get("XDG_CURRENT_DESKTOP", "Hyprland").split(":"))
    only = set(filter(None, d.get("OnlyShowIn", "").split(";")))
    no = set(filter(None, d.get("NotShowIn", "").split(";")))
    return (not only or bool(only & desktops)) and not bool(no & desktops)


def startup_records():
    seen = set()
    rows = []
    for directory in startup_dirs():
        if not directory.exists():
            continue
        for path in sorted(directory.glob("*.desktop")):
            if path.name in seen:
                continue
            seen.add(path.name)
            try:
                d = read_desktop(path)
                if d.get("Type", "Application") != "Application" or not in_desktop(d):
                    continue
                if not d.get("Exec") and not flag(d.get("DBusActivatable", "false")):
                    continue
                probe = d.get("TryExec")
                if probe and not (Path(probe).is_file() or shutil.which(probe)):
                    continue
                rows.append({"id": "xdg:" + path.name, "name": desktop_name(d, path.stem),
                             "description": d.get("Comment[pt_BR]") or d.get("Comment", ""),
                             "command": d.get("Exec", ""), "icon": d.get("Icon", ""),
                             "kind": "login", "source": "Login · Azmuth" if flag(d.get("X-Azmuth-Managed", "false")) else "Login · XDG",
                             "managed": flag(d.get("X-Azmuth-Managed", "false")) or flag(d.get("X-Azmuth-Added", "false")),
                             "enabled": not flag(d.get("Hidden", "false")) and d.get("X-GNOME-Autostart-enabled", "true") != "false",
                             "removable": flag(d.get("X-Azmuth-Added", "false")),
                             "path": str(path), "data": d})
            except (OSError, configparser.Error, ValueError):
                continue
    return rows


# serviços do usuário que o Azmuth já controla ou que são o encanamento da sessão
SERVICE_SKIP = ("pipewire", "wireplumber", "xdg-", "dbus", "at-spi", "systemd-", "p11-kit", "gcr-", "gnome-keyring",
                "filter-chain", "hypridle", "hyprpaper", "hyprpolkitagent", "waybar", "cliphist", "appmenu")
SESSION_TARGETS = {"graphical-session.target", "default.target"}


def user_services():
    """Serviços `systemctl --user` que sobem com a sessão (ex.: Docker Desktop), ligados ou não."""
    try:
        listing = subprocess.run(["systemctl", "--user", "list-unit-files", "--type=service", "--no-legend", "--no-pager"],
                                 capture_output=True, text=True, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return []
    rows = []
    for line in listing.splitlines():
        parts = line.split()
        if len(parts) < 2 or parts[1] not in ("enabled", "disabled") or "@" in parts[0] or parts[0].startswith(SERVICE_SKIP):
            continue
        unit = parts[0]
        text = subprocess.run(["systemctl", "--user", "cat", unit], capture_output=True, text=True, timeout=5).stdout
        wanted = {w for line in text.splitlines() if line.startswith("WantedBy=") for w in line[9:].split()}
        if not wanted & SESSION_TARGETS:
            continue
        name = next((line[12:].strip() for line in text.splitlines() if line.startswith("Description=")), unit)
        rows.append({"id": "service:" + unit, "name": name, "description": "Serviço do usuário (systemd) que sobe no login.",
                     "command": "systemctl --user start " + unit, "icon": "", "kind": "service", "source": "Serviço",
                     "managed": False, "enabled": parts[1] == "enabled", "removable": False, "unit": unit})
    return rows


def dna_records():
    import core
    settings = core.read_settings()
    rows = []
    installed = catalog()
    for path in sorted((ROOT / "dna").glob("*.yaml")):
        if path.name == "omnitrix.yaml":
            continue
        data = core.load_dna(path)
        dna_id = data["dna"]["id"]
        prefs = settings["dna"].get(dna_id, {})
        enabled = prefs.get("autostart_apps", True)
        disabled = prefs.get("disabled_apps", [])
        for app in data.get("apps", {}).get("autostart", []):
            command = app if isinstance(app, str) else app["cmd"]
            ident = hashlib.sha256(command.encode()).hexdigest()[:12]
            program = Path(command.split()[0]).name
            entry = next((a for a in installed if Path(a["command"].split()[0]).name == program
                          or a["name"].casefold() == program.casefold()), None)
            rows.append({"id": f"dna:{dna_id}:{ident}", "name": entry["name"] if entry else program,
                         "description": "Abre ao transformar neste DNA.",
                         "command": command, "icon": entry["icon"] if entry else "", "kind": "dna",
                         "source": data["dna"]["name"], "enabled": enabled and command not in disabled,
                         "group_enabled": enabled, "removable": False, "dna": dna_id})
    return rows


def startup_list():
    rows = [{k: v for k, v in row.items() if k not in ("path", "data")} for row in startup_records()]
    rows += user_services()
    rows += dna_records()
    components = [
        {"name": "Shell do Omnitrix", "description": "Barra, widgets, notificações e bloqueio.", "command": "qs"},
        {"name": "Context Engine", "description": "Contexto e acompanhamento do sistema.", "command": "azmuth"},
        {"name": "Wallpaper e inatividade", "description": "Hyprpaper e Hypridle, definidos na integração da sessão.", "command": "hyprpaper / hypridle"},
        {"name": "Área de transferência", "description": "Captura do histórico pelo wl-paste e cliphist.", "command": "wl-paste"},
    ]
    return {"ok": True, "entries": rows, "components": components}


def get_startup(ident):
    for row in startup_records():
        if row["id"] == ident:
            return row
    raise ValueError("Este item de inicialização não existe mais. Atualize a lista.")


def startup_toggle(ident, enabled):
    if not isinstance(enabled, bool):
        raise ValueError("Use true ou false.")
    if ident.startswith("dna:"):
        import core
        row = next((r for r in dna_records() if r["id"] == ident), None)
        if row is None:
            raise ValueError("Aplicativo do DNA não encontrado.")
        prefs = core.read_settings()["dna"].get(row["dna"], {})
        disabled = set(prefs.get("disabled_apps", []))
        if enabled:
            if prefs.get("autostart_apps", True) is False:
                disabled.update(r["command"] for r in dna_records() if r["dna"] == row["dna"])
            disabled.discard(row["command"])
            core.set_setting("dna." + row["dna"] + ".autostart_apps", True)
        else:
            disabled.add(row["command"])
        core.set_setting("dna." + row["dna"] + ".disabled_apps", sorted(disabled))
        return {"ok": True, "message": "Preferência salva para a próxima transformação."}
    if ident.startswith("service:"):
        row = next((r for r in user_services() if r["id"] == ident), None)
        if row is None:
            raise ValueError("Este serviço não existe mais. Atualize a lista.")
        r = subprocess.run(["systemctl", "--user", "enable" if enabled else "disable", row["unit"]],
                           capture_output=True, text=True, timeout=15)
        if r.returncode:
            raise ValueError("O systemd recusou: " + (r.stderr or r.stdout).strip()[:200])
        return {"ok": True, "message": "Serviço " + ("ligado" if enabled else "desligado") + " no login."}
    row = get_startup(ident)
    destination = CONFIG / "autostart" / Path(row["path"]).name
    d = dict(row["data"])
    d.update({"Hidden": str(not enabled).lower(), "X-GNOME-Autostart-enabled": str(enabled).lower(), "X-Azmuth-Managed": "true"})
    write_desktop(destination, d)
    return {"ok": True, "message": "Inicialização atualizada. Vale no próximo login."}


def application_dirs():
    dirs = [DATA]
    dirs += [Path(p) for p in os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share").split(":") if p]
    dirs += [HOME / ".local/share/flatpak/exports/share", Path("/var/lib/flatpak/exports/share")]
    return [d / "applications" for d in dict.fromkeys(dirs)]


def catalog():
    apps, seen = [], set()
    for directory in application_dirs():
        if not directory.exists():
            continue
        for path in sorted(directory.rglob("*.desktop")):
            key = str(path.relative_to(directory)).replace("/", "-")
            if key in seen:
                continue
            seen.add(key)
            try:
                d = read_desktop(path)
                if d.get("Type") != "Application" or flag(d.get("NoDisplay", "false")) or flag(d.get("Hidden", "false")):
                    continue
                if not d.get("Exec") or flag(d.get("Terminal", "false")):
                    continue
                if d.get("TryExec") and not (Path(d["TryExec"]).is_file() or shutil.which(d["TryExec"])):
                    continue
                apps.append({"id": key, "name": desktop_name(d, path.stem), "icon": d.get("Icon", ""),
                             "command": d["Exec"], "path": str(path)})
            except (OSError, configparser.Error, ValueError):
                pass
    return sorted(apps, key=lambda p: p["name"].casefold())


def startup_add(ident):
    app = next((a for a in catalog() if a["id"] == ident), None)
    if app is None:
        raise ValueError("Aplicativo não encontrado.")
    filename = "azmuth-" + hashlib.sha256(ident.encode()).hexdigest()[:16] + ".desktop"
    destination = CONFIG / "autostart" / filename
    if destination.is_symlink():
        raise ValueError("A configuração existente é um link; edite a origem.")
    if destination.exists():
        d = read_desktop(destination)
        if not flag(d.get("X-Azmuth-Added", "false")) or d.get("X-Azmuth-AppId") != ident:
            raise ValueError("Já existe outra configuração com este nome.")
    else:
        d = read_desktop(Path(app["path"]))
    d.update({"Hidden": "false", "X-GNOME-Autostart-enabled": "true",
              "X-Azmuth-Added": "true", "X-Azmuth-Managed": "true", "X-Azmuth-AppId": ident})
    d.pop("OnlyShowIn", None)
    d.pop("NotShowIn", None)
    # A cópia é do próprio Azmuth; ela não é uma configuração do aplicativo.
    atomic(destination, "[Desktop Entry]\n" + "".join(k + "=" + str(v) + "\n" for k, v in d.items()))
    return {"ok": True, "message": app["name"] + " será iniciado no próximo login."}


def startup_remove(ident):
    row = get_startup(ident)
    path = Path(row["path"])
    if not row["removable"] or path.parent != CONFIG / "autostart" or path.is_symlink():
        raise ValueError("Só é possível remover os itens adicionados pelo Azmuth.")
    path.unlink()
    return {"ok": True, "message": "Removido da inicialização. O aplicativo continua instalado."}


def startup_run():
    session = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not session:
        return {"ok": False, "error": "A inicialização precisa de uma sessão do Hyprland."}
    stamp = STATE / ("autostart-" + hashlib.sha256(session.encode()).hexdigest()[:16] + ".json")
    stamp.parent.mkdir(parents=True, exist_ok=True)
    with open(stamp, "a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        lock.seek(0)
        if lock.read().strip():
            return {"ok": True, "message": "Inicialização desta sessão já executada."}
        gio = shutil.which("gio")
        if not gio:
            raise ValueError("O comando gio é necessário para iniciar os aplicativos.")
        results = []
        for row in startup_records():
            if not row["enabled"] or not row["managed"]:
                continue
            try:
                r = subprocess.run([gio, "launch", row["path"]], capture_output=True, text=True, timeout=15)
                results.append({"name": row["name"], "ok": r.returncode == 0})
            except (OSError, subprocess.TimeoutExpired):
                results.append({"name": row["name"], "ok": False})
        lock.seek(0)
        lock.write(json.dumps({"time": time.time(), "items": results}))
        lock.flush()
    return {"ok": True, "items": results}


def install_entry():
    destination = DATA / "applications/azmuth-task-manager.desktop"
    text = ("[Desktop Entry]\nType=Application\nName=Gerenciador de tarefas · Azmuth\n"
            "Comment=Processos, desempenho e inicialização do Omnitrix\n"
            "Exec=" + str(HOME / ".local/bin/azmuth") + " tasks\n"
            "Icon=" + str(ROOT / "filemanager/omnitrix.svg") + "\n"
            "Terminal=false\nCategories=System;Monitor;\nKeywords=task;processos;cpu;memoria;startup;omnitrix;\n")
    atomic(destination, text)
    destination.chmod(0o644)


def launch(tab="processes"):
    if tab not in ("processes", "performance", "startup"):
        raise ValueError("Aba inválida.")
    install_entry()
    atomic(REQUEST, json.dumps({"tab": tab, "time": time.time()}))
    existing = subprocess.run(["qs", "-p", str(UI), "ipc", "call", "manager", "show", tab],
                              capture_output=True, text=True, timeout=4)
    if existing.returncode == 0:
        # A janela é uma aplicação normal, para continuar trabalhando com ela aberta.
        try:
            clients = json.loads(subprocess.check_output(["hyprctl", "-j", "clients"], timeout=3))
            for client in clients:
                if client.get("title") == "Azmuth · Gerenciador de tarefas":
                    address = client.get("address", "")
                    if re.fullmatch(r"0x[0-9a-fA-F]+", address):
                        subprocess.run(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({window=" + json.dumps("address:" + address) + "}))"],
                                       capture_output=True, timeout=3)
                    break
        except (OSError, ValueError, subprocess.SubprocessError):
            pass
        return {"ok": True}
    with open(STATE / "tasks-ui.log", "a") as log:
        subprocess.Popen(["qs", "-n", "-p", str(UI)], stdout=log, stderr=log, start_new_session=True)
    return {"ok": True}


def main(args):
    try:
        if args and args[0] == "--watch":
            sampler = Sampler()
            while True:
                print(json.dumps(sampler.sample(), ensure_ascii=False), flush=True)
                time.sleep(1.5)
        elif args and args[0] == "--snapshot":
            sampler = Sampler()
            sampler.sample()
            time.sleep(.25)
            result = sampler.sample()
        elif args and args[0] == "--signal" and len(args) == 4:
            result = control_process(int(args[1]), int(args[2]), args[3])
        elif args and args[0] == "--signal-group" and len(args) == 3:
            result = control_group(args[1], args[2].split(","))
        elif args and args[0] == "--startup-list":
            result = startup_list()
        elif args and args[0] == "--catalog":
            result = {"ok": True, "apps": catalog()}
        elif args and args[0] == "--startup-toggle" and len(args) == 3:
            result = startup_toggle(args[1], json.loads(args[2]))
        elif args and args[0] == "--startup-add" and len(args) == 2:
            result = startup_add(args[1])
        elif args and args[0] == "--startup-remove" and len(args) == 2:
            result = startup_remove(args[1])
        elif args and args[0] == "--autostart-run":
            result = startup_run()
        elif not args or (args[0] == "--tab" and len(args) == 2):
            result = launch(args[1] if args else "processes")
        else:
            raise ValueError("Use azmuth tasks [--tab processes|performance|startup].")
    except (KeyboardInterrupt, BrokenPipeError):
        return
    except (ValueError, OSError, configparser.Error, subprocess.SubprocessError) as exc:
        result = {"ok": False, "error": str(exc)}
    print(json.dumps(result, ensure_ascii=False))
