"""Recuperação idempotente e diagnóstico dos componentes da sessão Azmuth."""
from __future__ import annotations

import fcntl
import json
import os
import shlex
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

import core


def command(args, timeout=5):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return subprocess.CompletedProcess(args, 1, "", str(exc))


def main_instances():
    result = command(["qs", "-p", str(core.SHELL_DIR), "list", "-j"])
    try:
        return json.loads(result.stdout) if result.returncode == 0 else []
    except ValueError:
        return []


def own_processes():
    rows = []
    for path in Path("/proc").iterdir():
        if not path.name.isdecimal():
            continue
        try:
            if path.stat().st_uid != os.getuid():
                continue
            args = (path / "cmdline").read_bytes().decode("utf-8", "replace").strip("\0").split("\0")
            rows.append((int(path.name), args))
        except OSError:
            pass
    return rows


def notification_info():
    # Consultar o dono primeiro evita ativar um daemon de reserva por acidente.
    bus = ["busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus"]
    owner = command(bus + ["GetNameOwner", "s", "org.freedesktop.Notifications"])
    if owner.returncode:
        return {"pid": 0, "process": "", "name": "", "uid": -1}
    try:
        name = shlex.split(owner.stdout)[1]
        pid = int(shlex.split(command(bus + ["GetConnectionUnixProcessID", "s", name]).stdout)[1])
        path = Path("/proc") / str(pid)
        process = (path / "comm").read_text().strip()
        uid = path.stat().st_uid
        info = command(["busctl", "--user", "call", "org.freedesktop.Notifications", "/org/freedesktop/Notifications", "org.freedesktop.Notifications", "GetServerInformation"])
        server = shlex.split(info.stdout)[1] if info.returncode == 0 else process
        return {"pid": pid, "process": process, "name": server, "uid": uid}
    except (OSError, ValueError, IndexError):
        return {"pid": 0, "process": "", "name": "", "uid": -1}


def reclaim_notifications():
    if not core.shell_running():
        return {"ok": False, "message": "A interface ainda não está pronta."}
    info = notification_info()
    if info["process"] == "dunst" and info["uid"] == os.getuid():
        command(["systemctl", "--user", "stop", "dunst.service"])
        # Também atende um Dunst aberto manualmente, sem atingir outras sessões.
        remaining = notification_info()
        if remaining["pid"] == info["pid"] and remaining["process"] == "dunst":
            try:
                fd = os.pidfd_open(info["pid"])
                try:
                    path = Path("/proc") / str(info["pid"])
                    if path.stat().st_uid == os.getuid() and (path / "comm").read_text().strip() == "dunst":
                        signal.pidfd_send_signal(fd, signal.SIGTERM)
                finally:
                    os.close(fd)
            except (OSError, AttributeError):
                pass
    deadline = time.monotonic() + 3
    pids = {row["pid"] for row in main_instances()}
    while True:
        info = notification_info()
        if info["pid"] in pids:
            return {"ok": True, "message": "Notificações do Omnitrix ativas."}
        if time.monotonic() >= deadline:
            return {"ok": False, "message": "Notificações atendidas por " + (info["name"] or "nenhum servidor") + "."}
        time.sleep(.1)


def ensure_process(name, args, rows, suffix=None):
    if any((suffix in argv if suffix else argv and Path(argv[0]).name == name) for _, argv in rows):
        return
    if not shutil.which(args[0]):
        core.log("[AVISO] Componente ausente: " + name)
        return
    with open(core.STATE_DIR / ("context.log" if name == "context" else name + ".log"), "a") as output:
        subprocess.Popen(args, stdout=output, stderr=output, start_new_session=True)
    core.log("[OK] Iniciado: " + name)


def start(login=False):
    if not os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or not os.environ.get("WAYLAND_DISPLAY"):
        raise ValueError("Execute dentro da sessão do Hyprland.")
    core.STATE_DIR.mkdir(parents=True, exist_ok=True)
    with open(core.STATE_DIR / ".session-start.lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        rows = own_processes()
        ensure_process("hyprpaper", ["hyprpaper"], rows)
        if not core.shell_running():
            result = command(["qs", "-n", "-d", "-p", str(core.SHELL_DIR)], timeout=15)
            if result.returncode:
                raise ValueError(result.stderr.strip() or result.stdout.strip() or "A interface não iniciou.")
            deadline = time.monotonic() + 5
            while not core.shell_running() and time.monotonic() < deadline:
                time.sleep(.1)
        if not core.shell_running():
            raise ValueError("A interface não respondeu. Consulte os logs do Quickshell.")
        result = reclaim_notifications()
        core.log(("[OK] " if result["ok"] else "[AVISO] ") + result["message"])
        ensure_process("context", [sys.executable, "-u", str(core.ROOT / "src/context_engine.py")], rows,
                       suffix=str(core.ROOT / "src/context_engine.py"))
        ensure_process("hypridle", ["hypridle"], rows)
        if not any("wl-paste" == Path(a[0]).name and "--watch" in a and "cliphist" in a for _, a in rows if a):
            ensure_process("wl-paste", ["wl-paste", "--watch", "cliphist", "store"], [])
        core.cmd_restore()
        if login:
            import task_manager
            task_manager.startup_run()
        core.log("[OK] Sessão do Azmuth pronta.")


def diagnose():
    rows = own_processes()
    instances = main_instances()
    notes = []
    def check(name, ok, detail):
        notes.append({"name": name, "ok": bool(ok), "detail": detail})
    check("Interface e IPC", core.shell_running() and len(instances) == 1, str(len(instances)) + " instância(s) da shell")
    info = notification_info()
    check("Notificações", info["pid"] in {r["pid"] for r in instances}, info["name"] or "sem servidor")
    for name, match in [
        ("Context Engine", lambda a: str(core.ROOT / "src/context_engine.py") in a),
        ("Inatividade e suspensão", lambda a: a and Path(a[0]).name == "hypridle"),
        ("Wallpaper", lambda a: a and Path(a[0]).name == "hyprpaper"),
        ("Histórico da área de transferência", lambda a: a and Path(a[0]).name == "wl-paste" and "--watch" in a and "cliphist" in a),
    ]:
        count = sum(bool(match(a)) for _, a in rows)
        check(name, count == 1, str(count) + " processo(s)")
    result = command(["hyprctl", "configerrors"])
    check("Configuração do Hyprland", result.returncode == 0 and not result.stdout.strip(), result.stdout.strip() or "sem erros")
    missing = [name for name in ["qs", "hyprctl", "hypridle", "hyprpaper", "wpctl", "wl-copy", "wl-paste", "cliphist", "grim", "slurp", "wf-recorder", "dolphin", "kitty", "gio"] if not shutil.which(name)]
    check("Ferramentas da rice", not missing, ", ".join(missing) if missing else "todas encontradas")
    try:
        count = 0
        for path in core.DNA_DIR.glob("*.yaml"):
            if path.name == "omnitrix.yaml":
                continue
            data = core.load_dna(path)
            for section, key in [("wallpaper", "path"), ("hud", "art")]:
                ref = data.get(section, {}).get(key)
                if ref and not (core.ROOT / ref).is_file():
                    raise ValueError("Asset ausente: " + ref)
            count += 1
        check("DNAs e artes", count > 0, str(count) + " DNA(s) válidos")
    except (OSError, ValueError, KeyError, SystemExit, core.yaml.YAMLError) as exc:
        check("DNAs e artes", False, str(exc))
    for rel in ["desktop.json", "playlists.json", "events.json", "theme.json"]:
        try:
            value = json.loads((core.STATE_DIR / rel).read_text())
            check(rel, isinstance(value, (dict, list)), "JSON válido")
        except (OSError, ValueError) as exc:
            check(rel, False, str(exc))
    return {"ok": all(n["ok"] for n in notes), "checks": notes,
            "optional": [{"name": "Assistente de IA", "detail": "Interface disponível; provedor atual: Claude Code. Conta e consulta não verificadas."}]}


def main(args):
    try:
        action = args[0] if args else "doctor"
        if action == "start":
            start("--login" in args)
            return
        if action == "notifications":
            result = reclaim_notifications()
        elif action == "doctor":
            result = diagnose()
            if "--json" not in args:
                for check in result["checks"]:
                    print(("[OK] " if check["ok"] else "[ATENÇÃO] ") + check["name"] + ": " + check["detail"])
                for item in result.get("optional", []):
                    print("[INFO] " + item["name"] + ": " + item["detail"])
                return
        else:
            raise ValueError("Use azmuth send, azmuth start ou azmuth doctor [--json].")
    except (OSError, ValueError) as exc:
        result = {"ok": False, "message": str(exc)}
    print(json.dumps(result, ensure_ascii=False))
