"""Project Azmuth — apps que abrem maximizados (`settings.json → windows.maximize`).

As regras vão para o Hyprland com `hyprctl eval`, como as das telas (src/display.py). Um
`hyprctl reload` apaga regras de runtime; o `azmuth restore` reaplica.

    azmuth windows apply
"""
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import core  # noqa: E402

STATE = core.STATE_DIR / "window-rules.json"   # classes aplicadas da última vez (para desligar as removidas)


def classes() -> list[str]:
    return core.read_settings()["windows"]["maximize"]


def _lua_str(text: str) -> str:
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _regex(text: str) -> str:
    """Escapa só os metacaracteres do RE2 (o hífen de "google-chrome" fica como está)."""
    return re.sub(r"([.^$*+?()\[\]{}|\\])", r"\\\1", text)


def rules(names: list[str], on: bool = True) -> list[str]:
    out = []
    for cls in names:
        ident = re.sub(r"[^a-z0-9]+", "-", cls.lower()).strip("-") or "app"
        out.append(f"hl.window_rule({{ name = {_lua_str('azmuth-max-' + ident)}, "
                   f"match = {{ class = {_lua_str('^(' + _regex(cls) + ')$')} }}, maximize = {'true' if on else 'false'} }})")
    return out


def _previous() -> list[str]:
    try:
        return json.loads(STATE.read_text())
    except (OSError, ValueError):
        return []


def apply() -> dict:
    """Regras das classes atuais; as que saíram da lista são desligadas (maximize = false)."""
    current = classes()
    removed = [c for c in _previous() if c not in current]
    errors = []
    for rule in rules(removed, on=False) + rules(current):
        r = subprocess.run(["hyprctl", "eval", rule], capture_output=True, text=True, timeout=5)
        out = (r.stdout + r.stderr).strip()
        if r.returncode or "error" in out.lower():
            errors.append(out[:200])
    try:
        STATE.parent.mkdir(parents=True, exist_ok=True)
        STATE.write_text(json.dumps(current))
    except OSError:
        pass
    if errors:
        return {"ok": False, "error": "O Hyprland recusou a regra: " + errors[0]}
    return {"ok": True, "message": f"{len(classes())} app(s) abrem maximizados."}


def main(args: list[str]) -> None:
    if args[:1] != ["apply"]:
        raise SystemExit("Uso: azmuth windows apply")
    result = apply()
    print(json.dumps(result, ensure_ascii=False))
    if not result["ok"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main(sys.argv[1:])
