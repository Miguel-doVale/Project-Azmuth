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
                "processes": processes}


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
