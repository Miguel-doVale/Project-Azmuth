"""Project Azmuth — telas e projetor (Central → Telas · `azmuth display`).

Modos (como o "Projetar" do Windows):
  mirror     espelhar o notebook no projetor/monitor
  extend     estender (posição: left | right | up | down em relação ao notebook)
  external   só o projetor (o notebook desliga — só se houver tela externa conectada)
  internal   só o notebook (a tela externa desliga)

A escolha fica em settings.json → display e é reaplicada no restore (login, `hyprctl reload`)
e quando um monitor é conectado (Context Engine). As regras são enviadas ao Hyprland com
`hyprctl eval hl.monitor{...}`; o hyprland.lua continua com as regras-base.

    azmuth display status [--json]
    azmuth display set <mode|position|scale|resolution> <valor>
    azmuth display apply
    azmuth display force [<conector>]     liga a porta à força (cabo/projetor com sinal instável)
"""
import json
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import core  # noqa: E402

DRM = Path("/sys/class/drm")
MODES = ("mirror", "extend", "external", "internal")
POSITIONS = {"left": "auto-left", "right": "auto-right", "up": "auto-up", "down": "auto-down"}
SCALES = (1.0, 1.25, 1.5, 2.0)
INTERNAL_PREFIX = ("eDP", "LVDS", "DSI")
DEBOUNCE = 4.0
DEFAULTS = {"mode": "mirror", "position": "right", "scale": 1.0, "resolution": "preferred", "internal_scale": 1.2}


def settings() -> dict:
    return {**DEFAULTS, **(core.read_settings().get("display") or {})}


def is_internal(name: str) -> bool:
    return name.startswith(INTERNAL_PREFIX)


def connectors() -> list[dict]:
    """Portas físicas e se o hardware vê algo ligado (independe do Hyprland)."""
    out = []
    for path in sorted(DRM.glob("card*-*")):
        try:
            status = (path / "status").read_text().strip()
        except OSError:
            continue
        name = path.name.split("-", 1)[1]
        if name.startswith(("Writeback", "Virtual")):
            continue
        out.append({"name": name, "sysfs": str(path), "status": status, "internal": is_internal(name)})
    return out


def monitors() -> list[dict]:
    try:
        data = json.loads(subprocess.run(["hyprctl", "monitors", "all", "-j"], capture_output=True,
                                         text=True, timeout=5).stdout or "[]")
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError):
        return []
    return [{
        "name": m["name"], "internal": is_internal(m["name"]),
        "label": " ".join(x for x in (m.get("make"), m.get("model")) if x) or m.get("description") or m["name"],
        "width": m["width"], "height": m["height"], "refresh": round(m.get("refreshRate", 0)),
        "scale": m.get("scale", 1), "x": m.get("x", 0), "y": m.get("y", 0),
        "disabled": bool(m.get("disabled")), "mirror": m.get("mirrorOf") not in (None, "none", ""),
        "modes": [mode.split("@")[0] + "@" + str(round(float(mode.split("@")[1].rstrip("Hz")))) for mode in m.get("availableModes", [])],
    } for m in data]


def status() -> dict:
    mons = monitors()
    conns = connectors()
    internal = next((m["name"] for m in mons if m["internal"]), None) or next((c["name"] for c in conns if c["internal"]), "eDP-1")
    externals = [m for m in mons if not m["internal"]]
    # porta com cabo detectado pelo hardware, mas que o Hyprland ainda não mostrou
    pending = [c for c in conns if not c["internal"] and c["status"] == "connected" and c["name"] not in {m["name"] for m in mons}]
    return {"ok": True, "settings": settings(), "internal": internal, "monitors": mons,
            "externals": [m["name"] for m in externals], "connectors": conns, "pending": [c["name"] for c in pending]}


def _lua(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(float(value)) if isinstance(value, float) else str(value)
    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def _rule(spec: dict) -> str:
    return "hl.monitor({ " + ", ".join(f"{k} = {_lua(v)}" for k, v in spec.items()) + " })"


def rules(st: dict) -> list[str]:
    """Regras do Hyprland para o modo escolhido. Sem tela externa, o notebook sempre fica ligado."""
    cfg = st["settings"]
    internal = st["internal"]
    externals = st["externals"]
    # o Hyprland MESCLA regras de monitor: espelho e "desligado" antigos continuam valendo se a regra
    # nova não disser o contrário — por isso disabled/mirror vão sempre explícitos
    inner = {"output": internal, "mode": "preferred", "position": "0x0", "scale": float(cfg["internal_scale"]),
             "disabled": False, "mirror": ""}
    if not externals:
        return [_rule(inner)]
    mode = cfg["mode"] if cfg["mode"] in MODES else "mirror"
    res = cfg["resolution"] if cfg["resolution"] != "preferred" else "preferred"
    out = []
    for name in externals:
        ext = {"output": name, "mode": res, "position": "auto", "scale": float(cfg["scale"]),
               "disabled": False, "mirror": ""}
        if mode == "mirror":
            ext["mirror"] = internal
        elif mode == "extend":
            # posição numérica: "auto-*" não é refeita quando o monitor já existe
            inner_w = round(next((m["width"] / m["scale"] for m in st["monitors"] if m["name"] == internal), 1600))
            inner_h = round(next((m["height"] / m["scale"] for m in st["monitors"] if m["name"] == internal), 900))
            ew = round(next((m["width"] / float(cfg["scale"]) for m in st["monitors"] if m["name"] == name), 1024))
            eh = round(next((m["height"] / float(cfg["scale"]) for m in st["monitors"] if m["name"] == name), 768))
            ext["position"] = {"left": f"{-ew}x0", "right": f"{inner_w}x0", "up": f"0x{-eh}",
                               "down": f"0x{inner_h}"}.get(cfg["position"], f"{inner_w}x0")
        elif mode == "external":
            ext["position"] = "0x0"
        elif mode == "internal":
            ext = {"output": name, "disabled": True}
        out.append(_rule(ext))
    out.insert(0, _rule({"output": internal, "disabled": True}) if mode == "external" else _rule(inner))
    return out


def apply(force: bool = False) -> dict:
    stamp = core.STATE_DIR / ".display-applied"
    if not force and stamp.exists() and time.time() - stamp.stat().st_mtime < DEBOUNCE:
        return {"ok": True, "message": "Telas aplicadas há instantes."}
    st = status()
    errors = []
    for rule in rules(st):
        r = subprocess.run(["hyprctl", "eval", rule], capture_output=True, text=True, timeout=5)
        if r.returncode or "error" in (r.stdout + r.stderr).lower():
            errors.append((r.stdout + r.stderr).strip()[:200])
    stamp.parent.mkdir(parents=True, exist_ok=True)
    stamp.touch()
    if errors:
        return {"ok": False, "error": "O Hyprland recusou a regra: " + errors[0]}
    labels = {"mirror": "Espelhando", "extend": "Estendendo", "external": "Só a tela externa", "internal": "Só o notebook"}
    msg = labels.get(st["settings"]["mode"], "Telas aplicadas") if st["externals"] else "Sem tela externa: só o notebook"
    return {"ok": True, "message": msg + "."}


def set_value(key: str, raw: str) -> dict:
    if key == "mode" and raw in MODES:
        value = raw
    elif key == "position" and raw in POSITIONS:
        value = raw
    elif key in ("scale", "internal_scale"):
        value = float(raw)
        if not 0.5 <= value <= 3:
            raise ValueError("Escala fora do intervalo (0.5 a 3).")
    elif key == "resolution" and (raw == "preferred" or (raw.count("x") == 1 and "@" in raw)):
        value = raw
    else:
        raise ValueError(f"Valor inválido para {key}: {raw}")
    core.set_setting("display." + key, value)
    return apply(force=True)


def force(name: str | None = None) -> dict:
    """Liga a porta à força (o projetor fica 'piscando' a detecção) e faz o Hyprland procurar de novo."""
    conns = [c for c in connectors() if not c["internal"]]
    target = next((c for c in conns if c["name"] == name), None) if name else next(
        (c for c in conns if c["name"].startswith("HDMI")), conns[0] if conns else None)
    if not target:
        raise ValueError("Nenhuma porta de vídeo externa encontrada.")
    r = subprocess.run(["pkexec", "sh", "-c", 'echo on > "$1/status"', "sh", target["sysfs"]],
                       capture_output=True, text=True, timeout=120)
    if r.returncode:
        raise ValueError("Autorização negada ou falhou ao ligar " + target["name"] + ".")
    time.sleep(1.5)
    subprocess.run(["hyprctl", "reload"], capture_output=True, timeout=10)   # o Hyprland só enxerga após recarregar
    time.sleep(2)
    result = apply(force=True)
    found = target["name"] in status()["externals"]
    return {"ok": found, "message": target["name"] + " ligada à força. " + result.get("message", ""),
            **({} if found else {"error": target["name"] + " ligada, mas nenhuma imagem foi detectada. Confira cabo e entrada do projetor."})}


def main(args: list[str]) -> None:
    action = args[0] if args else "status"
    try:
        if action == "status":
            result = status()
            if "--json" not in args:
                cfg = result["settings"]
                print(f"Modo: {cfg['mode']} · externas: {', '.join(result['externals']) or 'nenhuma'}"
                      + (f" · cabo detectado sem imagem: {', '.join(result['pending'])}" if result["pending"] else ""))
                return
        elif action == "apply":
            result = apply(force="--force" in args)
        elif action == "set" and len(args) == 3:
            result = set_value(args[1], args[2])
        elif action == "force":
            result = force(args[1] if len(args) > 1 else None)
        else:
            raise ValueError("Uso: azmuth display [status|apply|set <chave> <valor>|force [conector]]")
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        result = {"ok": False, "error": str(exc)}
    print(json.dumps(result, ensure_ascii=False))
    if not result.get("ok"):
        raise SystemExit(1)


if __name__ == "__main__":
    main(sys.argv[1:])
