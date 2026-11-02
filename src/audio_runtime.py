"""Detecta e recupera a saída de áudio PipeWire quando cai no Dummy Output."""
from __future__ import annotations

import fcntl
import json
import os
import re
import shutil
import socket
import subprocess
import time
from pathlib import Path


RESTART_SERVICES = [
    "systemctl", "--user", "restart",
    "pipewire.service", "wireplumber.service", "pipewire-pulse.service",
]


def command(argv, timeout=6):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired) as exc:
        return subprocess.CompletedProcess(argv, 1, "", str(exc))


def is_dummy(name: str) -> bool:
    lowered = name.lower().strip()
    return not lowered or lowered in {"null", "auto_null"} or "dummy" in lowered


def snapshot() -> dict:
    info = command(["pactl", "info"])
    if info.returncode:
        raise RuntimeError(info.stderr.strip() or "Não consegui consultar o servidor PipeWire/PulseAudio.")
    default = ""
    for line in info.stdout.splitlines():
        if line.startswith("Default Sink:"):
            default = line.split(":", 1)[1].strip()
            break

    result = command(["pactl", "list", "short", "sinks"])
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Não consegui listar as saídas de áudio.")
    sinks = []
    for line in result.stdout.splitlines():
        fields = line.split()
        if len(fields) >= 2:
            sinks.append(fields[1])
    return {"default": default, "sinks": sinks}


def playback_holders() -> list[dict]:
    """Lista processos do usuário que abrem diretamente um PCM de reprodução ALSA."""
    ignored = {"pipewire", "pipewire-pulse", "wireplumber"}
    holders = []
    for process in Path("/proc").iterdir():
        if not process.name.isdecimal() or int(process.name) == os.getpid():
            continue
        try:
            if process.stat().st_uid != os.getuid():
                continue
            comm = (process / "comm").read_text(encoding="utf-8").strip()
            if comm in ignored:
                continue
            executable = os.readlink(process / "exe").removesuffix(" (deleted)")
            name = Path(executable).name or comm
            for fd in (process / "fd").iterdir():
                try:
                    target = os.readlink(fd)
                except OSError:
                    continue
                if target.startswith("/dev/snd/pcmC") and target.endswith("p"):
                    holders.append({"pid": int(process.name), "name": name})
                    break
        except (OSError, PermissionError):
            continue
    return sorted(holders, key=lambda holder: holder["pid"])

def is_healthy(state: dict) -> bool:
    default = state.get("default", "")
    return default in state.get("sinks", []) and not is_dummy(default)


def status() -> int:
    try:
        state = snapshot()
    except RuntimeError as exc:
        print(f"[ERRO] {exc}")
        return 1
    if is_healthy(state):
        print(f"[OK] Saída de áudio ativa: {state['default']}")
        return 0
    print(f"[ATENÇÃO] Saída indisponível: {state['default'] or 'nenhuma'} (Dummy Output)")
    return 1


def _move_streams(target: str) -> int:
    result = command(["pactl", "list", "short", "sink-inputs"])
    if result.returncode:
        return 0
    moved = 0
    for line in result.stdout.splitlines():
        fields = line.split()
        if fields and fields[0].isdigit():
            routed = command(["pactl", "move-sink-input", fields[0], target])
            moved += routed.returncode == 0
    return moved


def restore() -> int:
    try:
        initial = snapshot()
    except RuntimeError as exc:
        print(f"[ERRO] {exc}")
        return 1
    if is_healthy(initial):
        print(f"[OK] O áudio já está usando {initial['default']}.")
        return 0

    holders = playback_holders()
    if holders:
        details = ", ".join(f"{holder['name']} (PID {holder['pid']})" for holder in holders)
        helper = any(holder["name"] == "ridiculous-audio-helper" for holder in holders)
        print(f"[ERRO] Um aplicativo está segurando a saída ALSA diretamente: {details}.")
        if helper:
            print("No VS Code, configure `ridiculousCoding.soundBackend` como `webview`; depois rode `azmuth audio` novamente.")
        else:
            print("Feche ou configure esse aplicativo para usar PipeWire/PulseAudio e rode `azmuth audio` novamente.")
        return 1

    print("[AZMUTH] Saída dummy detectada; reiniciando o áudio e procurando uma saída física…")
    restarted = command(RESTART_SERVICES, timeout=20)
    if restarted.returncode:
        detail = restarted.stderr.strip() or restarted.stdout.strip() or "falha ao reiniciar os serviços"
        print(f"[ERRO] Não consegui reiniciar PipeWire/WirePlumber: {detail}")
        return 1

    deadline = time.monotonic() + 10
    fallback_set = False
    last_state = initial
    while time.monotonic() < deadline:
        try:
            current = snapshot()
            last_state = current
        except RuntimeError:
            time.sleep(0.35)
            continue

        if is_healthy(current):
            pinned = command(["pactl", "set-default-sink", current["default"]])
            if pinned.returncode:
                detail = pinned.stderr.strip() or pinned.stdout.strip()
                if detail:
                    print(f"[AVISO] A saída voltou, mas não consegui salvá-la como padrão: {detail}")
            moved = _move_streams(current["default"])
            suffix = f" {moved} fluxo(s) de áudio redirecionado(s)." if moved else ""
            print(f"[OK] Saída recuperada: {current['default']}.{suffix}")
            return 0

        physical = [sink for sink in current["sinks"] if not is_dummy(sink)]
        if physical and not fallback_set:
            # Dá tempo ao WirePlumber para escolher por prioridade; se continuar
            # no Dummy, seleciona uma saída real que já apareceu no PipeWire.
            elapsed = 10 - max(0, deadline - time.monotonic())
            if elapsed >= 1.2:
                selected = command(["pactl", "set-default-sink", physical[0]])
                fallback_set = True
                if selected.returncode:
                    detail = selected.stderr.strip() or selected.stdout.strip()
                    if detail:
                        print(f"[AVISO] Não consegui selecionar {physical[0]}: {detail}")
        time.sleep(0.35)

    print("[ERRO] PipeWire reiniciou, mas nenhuma saída física ficou disponível.")
    if last_state.get("sinks"):
        print("Saídas detectadas: " + ", ".join(last_state["sinks"]))
    print("Confira a placa com `wpctl status` e `journalctl --user -u pipewire -u wireplumber -n 80`.")
    return 1



# ── inventário, rotas físicas e equalizador ──
EQ_NAME = "ProjectAzmuth-10Band"
EQ_FREQUENCIES = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
EQ_DEFAULT_GAINS = [0.0] * 10


def _emit_json(ok: bool, message: str = "", **extra) -> None:
    payload = {"ok": ok}
    if message:
        payload["message"] = message
    payload.update(extra)
    print(json.dumps(payload, ensure_ascii=False))


def _pactl_json(kind: str) -> list[dict]:
    result = command(["pactl", "-f", "json", "list", kind])
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"Não consegui consultar {kind} no PipeWire.")
    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"A lista PipeWire de {kind} não é JSON válido.") from exc
    if not isinstance(payload, list):
        raise RuntimeError(f"A resposta de {kind} tem formato inesperado.")
    return payload


def _availability(value: str) -> str:
    value = str(value or "").strip().lower()
    if "not available" in value or value in {"no", "unavailable"}:
        return "no"
    if value == "available" or value == "yes":
        return "yes"
    return "unknown"


def _audio_nodes(kind: str) -> list[dict]:
    result = []
    for obj in _pactl_json(kind):
        name = str(obj.get("name") or "")
        if not name or (kind == "sources" and name.endswith(".monitor")):
            continue
        props = obj.get("properties") or {}
        ports = [{
            "name": str(port.get("name") or ""),
            "description": str(port.get("description") or port.get("name") or ""),
            "type": str(port.get("type") or ""),
            "availability": _availability(port.get("availability")),
        } for port in obj.get("ports") or []]
        result.append({
            "name": name, "description": str(obj.get("description") or name),
            "active_port": str(obj.get("active_port") or ""), "ports": ports,
            "form_factor": str(props.get("device.form_factor") or ""),
            "bus": str(props.get("device.bus") or ""),
        })
    return result


def inventory() -> int:
    try:
        outputs, inputs = _audio_nodes("sinks"), _audio_nodes("sources")
    except RuntimeError as exc:
        _emit_json(False, str(exc), outputs=[], inputs=[])
        return 1
    _emit_json(True, outputs=outputs, inputs=inputs)
    return 0


def set_route(direction: str, node_name: str, port_name: str) -> int:
    if direction not in {"output", "input"}:
        raise RuntimeError("A rota deve ser output ou input.")
    kind = "sinks" if direction == "output" else "sources"
    node = next((item for item in _audio_nodes(kind) if item["name"] == node_name), None)
    if node is None:
        raise RuntimeError("Esse dispositivo não está mais conectado.")
    port = next((item for item in node["ports"] if item["name"] == port_name), None)
    if port is None:
        raise RuntimeError("Essa rota não pertence ao dispositivo selecionado.")
    if port["availability"] == "no":
        raise RuntimeError("O hardware informa que essa saída ou entrada não está conectada.")
    action = "set-sink-port" if direction == "output" else "set-source-port"
    result = command(["pactl", action, node_name, port_name])
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "O PipeWire recusou a mudança de rota.")
    _emit_json(True, f"Rota alterada: {port['description']}.")
    return 0


def _eq_state_path() -> Path:
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
    return state_home / "azmuth" / "audio.json"


def _eq_read_state() -> dict:
    try:
        data = json.loads(_eq_state_path().read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        data = {}
    raw = data.get("gains", EQ_DEFAULT_GAINS)
    gains = []
    for i in range(10):
        try:
            value = float(raw[i])
        except (IndexError, TypeError, ValueError):
            value = 0.0
        gains.append(max(-12.0, min(12.0, value)))
    return {"gains": gains, "enabled": bool(data.get("enabled", False))}


def _eq_write_state(gains: list[float], enabled: bool) -> None:
    path = _eq_state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {"gains": [round(float(v), 1) for v in gains], "enabled": bool(enabled)}
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def _eq_preset_path() -> Path:
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    return data_home / "easyeffects" / "output" / f"{EQ_NAME}.json"


def _eq_preset(gains: list[float]) -> dict:
    equalizer = {
        "balance": 0.0, "bypass": False, "decramp": "Off", "input-gain": 0.0,
        "mode": "IIR", "num-bands": 10, "output-gain": -max(0.0, max(gains)),
        "pitch-left": 0.0, "pitch-right": 0.0, "split-channels": False,
    }
    for channel in ("left", "right"):
        equalizer[channel] = {
            f"band{i}": {
                "frequency": float(freq), "gain": float(gains[i]), "mode": "RLC (BT)",
                "mute": False, "q": 1.0, "slope": "x1", "solo": False,
                "type": "Bell", "width": 4.0,
            }
            for i, freq in enumerate(EQ_FREQUENCIES)
        }
    return {"output": {"blocklist": [], "equalizer#0": equalizer, "plugins_order": ["equalizer#0"]}}


def _eq_write_preset(gains: list[float]) -> None:
    path = _eq_preset_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(_eq_preset(gains), indent=4, sort_keys=True) + "\n", encoding="utf-8")
    temporary.replace(path)


def _ee_socket() -> Path:
    runtime = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return Path(runtime) / "EasyEffectsServer"


def _ee_send(message: str, timeout: float = 1.6) -> str:
    path = _ee_socket()
    if not path.exists():
        raise RuntimeError("O servidor local do EasyEffects não está ativo.")
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(timeout)
            client.connect(str(path))
            client.sendall((message + "\n").encode("utf-8"))
            client.shutdown(socket.SHUT_WR)
            chunks = []
            while True:
                try:
                    chunk = client.recv(4096)
                except socket.timeout:
                    break
                if not chunk:
                    break
                chunks.append(chunk)
            return b"".join(chunks).decode("utf-8", "replace").strip()
    except OSError as exc:
        raise RuntimeError(f"Falha ao acessar o servidor do EasyEffects: {exc}") from exc


def _eq_status() -> dict:
    state = _eq_read_state()
    installed = shutil.which("easyeffects") is not None
    ready, bypass = False, None
    if _ee_socket().exists():
        try:
            raw = _ee_send("get_global_bypass").strip().lower()
            ready = bool(raw)
            if raw in {"1", "true", "enabled"}:
                bypass = True
            elif raw in {"0", "2", "false", "disabled"}:
                bypass = False
        except RuntimeError:
            ready = False
    enabled = ready and (not bypass if bypass is not None else state["enabled"])
    return {"ok": True, "installed": installed, "ready": ready, "enabled": enabled, "gains": state["gains"]}


def _eq_check_version() -> None:
    binary = shutil.which("easyeffects")
    if not binary:
        raise RuntimeError("EasyEffects não está instalado. No Arch, use sudo pacman -S --needed easyeffects.")
    result = command([binary, "--version"])
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", result.stdout + result.stderr)
    if match and tuple(map(int, match.groups())) < (8, 2, 8):
        raise RuntimeError("EasyEffects 8.2.8 ou mais recente é necessário para controlar as bandas pelo painel.")


def _eq_start_app() -> None:
    if not shutil.which("easyeffects"):
        raise RuntimeError("EasyEffects não está instalado. No Arch, use sudo pacman -S --needed easyeffects.")
    if not _ee_socket().exists():
        subprocess.Popen(["easyeffects"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
        deadline = time.monotonic() + 8.0
        while time.monotonic() < deadline:
            if _ee_socket().exists():
                return
            time.sleep(0.2)
        raise RuntimeError("EasyEffects abriu, mas o servidor local não respondeu. Habilite-o nas preferências e tente novamente.")


def _eq_activate(gains: list[float]) -> None:
    _eq_check_version()
    _eq_write_preset(gains)
    _eq_start_app()
    _ee_send(f"load_preset:output:{EQ_NAME}")
    _ee_send("global_bypass:0")
    _eq_write_state(gains, True)


def eq_action(args: list[str]) -> int:
    if args == ["status", "--json"]:
        print(json.dumps(_eq_status(), ensure_ascii=False))
        return 0
    action, state = args[0] if args else "", _eq_read_state()
    if action == "enable" and len(args) == 1:
        _eq_activate(state["gains"])
        _emit_json(True, "Equalizador ligado.", enabled=True, gains=state["gains"])
        return 0
    if action == "open" and len(args) == 1:
        if not shutil.which("easyeffects"):
            raise RuntimeError("EasyEffects não está instalado. No Arch, use sudo pacman -S --needed easyeffects.")
        if _ee_socket().exists():
            _ee_send("show_window")
        else:
            subprocess.Popen(["easyeffects"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        _emit_json(True, "Janela do EasyEffects aberta.")
        return 0
    if action == "bypass" and len(args) == 2 and args[1] in {"on", "off"}:
        bypass = args[1] == "on"
        _ee_send("global_bypass:1" if bypass else "global_bypass:0")
        _eq_write_state(state["gains"], not bypass)
        _emit_json(True, "Equalizador pausado." if bypass else "Equalizador ligado.",
                   enabled=not bypass, gains=state["gains"])
        return 0
    if action == "gain" and len(args) == 3:
        try:
            index, value = int(args[1]), float(args[2])
        except ValueError as exc:
            raise RuntimeError("Informe o índice da banda e o ganho em dB.") from exc
        if not 0 <= index < 10:
            raise RuntimeError("A banda deve ter índice entre 0 e 9.")
        value = round(max(-12.0, min(12.0, value)), 1)
        lock_path = _eq_state_path().with_name(".audio-eq.lock")
        lock_path.parent.mkdir(parents=True, exist_ok=True)
        with open(lock_path, "a", encoding="utf-8") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX)
            state = _eq_read_state()
            gains = state["gains"][:]
            gains[index] = value
            _ee_send(f"set_property:output:equalizer:0:left:band{index}Gain:{value}")
            _ee_send(f"set_property:output:equalizer:0:right:band{index}Gain:{value}")
            _ee_send(f"set_property:output:equalizer:0:outputGain:{-max(0.0, max(gains))}")
            _eq_write_state(gains, state["enabled"])
            _emit_json(True, gains=gains, enabled=state["enabled"])
        return 0
    if action == "preset" and len(args) == 2:
        presets = {
            "flat": [0.0] * 10,
            "bass": [3.0, 2.5, 1.5, 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            "voice": [-1.0, -0.5, 0.5, 1.5, 2.0, 1.0, 1.5, 1.0, 0.0, -0.5],
            "treble": [-1.0, -0.5, 0.0, 0.0, 0.0, 0.5, 1.0, 2.0, 2.5, 2.0],
        }
        if args[1] not in presets:
            raise RuntimeError("Curva inválida; escolha flat, bass, voice ou treble.")
        gains = presets[args[1]]
        _eq_activate(gains)
        _emit_json(True, "Curva aplicada.", enabled=True, gains=gains)
        return 0
    raise RuntimeError("Uso: azmuth audio eq status --json | enable | open | bypass on|off | gain <0-9> <dB> | preset <flat|bass|voice|treble>")


def main(args: list[str]) -> None:
    action = args[0] if args else "restore"
    try:
        if action == "status" and len(args) == 1:
            result = status()
        elif action in {"restore", "fix"} and len(args) <= 1:
            result = restore()
        elif action == "inventory" and args[1:] in ([], ["--json"]):
            result = inventory()
        elif action == "route" and len(args) == 4:
            result = set_route(args[1], args[2], args[3])
        elif action == "eq":
            result = eq_action(args[1:])
        else:
            raise RuntimeError("Uso: azmuth audio [restore|status|inventory --json|route <output|input> <device> <port>|eq …]")
    except RuntimeError as exc:
        if action in {"inventory", "route", "eq"}:
            _emit_json(False, str(exc))
        else:
            print(f"[ERRO] {exc}")
        raise SystemExit(1)
    if result:
        raise SystemExit(result)
