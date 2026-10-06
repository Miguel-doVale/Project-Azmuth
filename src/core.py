#!/usr/bin/env python3
"""
Project Azmuth - Core Engine

Lê um DNA (dna/<id>.yaml), valida contra o schema e transforma o sistema:
Hyprland (via `hyprctl eval`), wallpaper (hyprpaper, todos os monitores),
waybar, rofi, dunst, daemons, apps e som de transformação.

Uso:
  azmuth apply <id | dna/arquivo.yaml>   transforma no DNA
  azmuth slot <0-9>                      Master Control (Super + Numpad)
  azmuth neutral                         rollback para o Neutral (Super + Esc)
  azmuth random                          Randomizer (Super + Shift + R)
  azmuth accept                          aceita a sugestão do Context Engine (Super + Y)
  azmuth master [on|off|toggle]          Master Control: troca automática pelo Context Engine
  azmuth hud [toggle|prev|next|confirm]  Omnitrix HUD (Quickshell; cai para rofi se ausente)
  azmuth current [--json]                DNA ativo
  azmuth roster --json                   catálogo do Omnitrix (usado pelo HUD)
  azmuth restore                         reaplica o último DNA (boot da sessão)
  azmuth wallpaper                       reaplica o wallpaper (hotplug de monitor)
  azmuth lock                            bloqueia a tela (Super + M)
  azmuth power                           menu de energia (Super + Shift + Q)
  azmuth install                         liga as configs do sistema ao projeto

Compatível com o uso original: python src/core.py dna/neutral.yaml
"""

import fcntl
import json
import os
import random
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from string import Template

import yaml

ROOT = Path(__file__).resolve().parent.parent
DNA_DIR = ROOT / "dna"
HUD_DIR = ROOT / "hud"
HOME = Path.home()
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "azmuth"
STATE_FILE = STATE_DIR / "state.json"

WAYBAR_STYLE = HOME / ".config/waybar/style.css"
ROFI_THEME = HOME / ".config/rofi/azmuth.rasi"
DUNST_RC = HOME / ".config/dunst/dunstrc"
HYPRLOCK_CONF = HOME / ".config/hypr/hyprlock.conf"
WAYBAR_SIGNAL = 8          # custom/omnitrix escuta SIGRTMIN+8
SUGGESTION_WINDOW = 6.0    # segundos para aceitar sugestão com Super+Y

REQUIRED_TOP_LEVEL = ["dna", "palette", "hyprland", "wallpaper", "waybar", "rofi"]
REQUIRED_DNA = ["id", "name", "core", "description"]
REQUIRED_PALETTE = ["primary", "secondary", "background", "foreground", "border_active", "border_inactive"]
REQUIRED_HYPRLAND = ["gaps_in", "gaps_out", "border_size", "rounding", "animations_enabled", "layout"]
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")


# ───────────────────────────── utilidades ─────────────────────────────

def log(msg: str) -> None:
    print(msg, flush=True)


def run(cmd: list[str], **kw) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kw)


def spawn(cmd: list[str]) -> None:
    """Processo solto (som, IPC do HUD) — não segura o core.py."""
    if shutil.which(cmd[0]):
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def lua_str(s: str) -> str:
    return "[==[" + s + "]==]"


def hypr_eval(lua: str) -> str | None:
    """Executa Lua no Hyprland. Retorna None em sucesso ou a mensagem de erro."""
    r = run(["hyprctl", "eval", lua])
    out = (r.stdout + r.stderr).strip()
    if r.returncode != 0 or "error" in out.lower():
        return out or f"rc={r.returncode}"
    return None


def hypr_exec(cmd: str, rules: dict | None = None) -> None:
    """Lança um processo com o Hyprland como pai (sobrevive ao core.py)."""
    if rules:
        tbl = ", ".join(f"{k} = {lua_str(str(v))}" for k, v in rules.items())
        err = hypr_eval(f"hl.exec_cmd({lua_str(cmd)}, {{ {tbl} }})")
    else:
        err = hypr_eval(f"hl.exec_cmd({lua_str(cmd)})")
    if err:
        log(f"[AVISO] exec falhou ({cmd}): {err}")


def hypr_json(what: str) -> list:
    r = run(["hyprctl", what, "-j"])
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return []


def notify(title: str, body: str = "", urgency: str = "low", timeout: int = 2200) -> None:
    spawn(["notify-send", "-a", "Azmuth", "-u", urgency, "-t", str(timeout),
           "-h", "string:x-canonical-private-synchronous:azmuth", title, body])


def play(path: Path | str | None) -> None:
    if path and Path(path).exists():
        spawn(["pw-play", str(path)])


def sound(name: str) -> Path:
    return ROOT / "assets/sounds" / f"{name}.wav"


# ───────────────────────────── estado ─────────────────────────────

def read_state() -> dict:
    try:
        return json.loads(STATE_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def update_state(**changes) -> dict:
    """Read-modify-write com lock (core.py e Context Engine escrevem no mesmo arquivo)."""
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with open(STATE_DIR / ".lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = read_state()
        state.update(changes)
        tmp = STATE_FILE.with_suffix(".tmp")
        tmp.write_text(json.dumps(state, indent=2))
        tmp.replace(STATE_FILE)
    return state


# ───────────────────────────── DNA: carga e validação ─────────────────────────────

def load_roster() -> dict:
    return yaml.safe_load((DNA_DIR / "omnitrix.yaml").read_text())


def resolve(ref: str) -> Path:
    p = Path(ref)
    if p.suffix == ".yaml":
        return p if p.is_absolute() or p.exists() else ROOT / p
    return DNA_DIR / f"{ref}.yaml"


def available(dna_id: str) -> bool:
    return (DNA_DIR / f"{dna_id}.yaml").exists()


def load_dna(path: Path) -> dict:
    with open(path) as f:
        data = yaml.safe_load(f)
    validate(data, path)
    return data


def validate(data: dict, path: Path) -> None:
    def need(section: dict, keys: list[str], where: str) -> None:
        for key in keys:
            if key not in section:
                raise ValueError(f"Campo obrigatório ausente{where}: '{key}'")

    if not isinstance(data, dict):
        raise ValueError("arquivo vazio ou não é um mapa YAML")
    need(data, REQUIRED_TOP_LEVEL, "")
    need(data["dna"], REQUIRED_DNA, " em 'dna'")
    need(data["palette"], REQUIRED_PALETTE, " em 'palette'")
    need(data["hyprland"], REQUIRED_HYPRLAND, " em 'hyprland'")
    need(data["wallpaper"], ["path"], " em 'wallpaper'")
    need(data["waybar"], ["style"], " em 'waybar'")
    need(data["rofi"], ["theme"], " em 'rofi'")

    if data["dna"]["core"] not in ("arch", "kali"):
        raise ValueError(f"'dna.core' deve ser 'arch' ou 'kali', recebido: {data['dna']['core']}")
    if data["dna"]["id"] != path.stem:
        raise ValueError(f"'dna.id' ({data['dna']['id']}) diferente do nome do arquivo ({path.stem})")
    for key, value in data["palette"].items():
        if not isinstance(value, str) or not HEX.match(value):
            raise ValueError(f"'palette.{key}' deve ser \"#rrggbb\", recebido: {value!r}")
    for key in ("gaps_in", "gaps_out", "border_size", "rounding"):
        if not isinstance(data["hyprland"][key], int):
            raise ValueError(f"'hyprland.{key}' deve ser inteiro")
    if not isinstance(data["hyprland"]["animations_enabled"], bool):
        raise ValueError("'hyprland.animations_enabled' deve ser true/false")
    if data["hyprland"]["layout"] not in ("dwindle", "master"):
        raise ValueError("'hyprland.layout' deve ser 'dwindle' ou 'master'")
    # arquivos de tema são obrigatórios: falhar ANTES de mexer em qualquer coisa
    for key, rel in (("waybar.style", data["waybar"]["style"]), ("rofi.theme", data["rofi"]["theme"])):
        if not (ROOT / rel).exists():
            raise ValueError(f"'{key}' aponta para arquivo inexistente: {rel}")
    for app in (data.get("apps") or {}).get("autostart") or []:
        if not (isinstance(app, str) or (isinstance(app, dict) and "cmd" in app)):
            raise ValueError(f"'apps.autostart' aceita string ou {{cmd, class?, workspace?}}: {app!r}")
    for trig in (data.get("context_engine") or {}).get("triggers") or []:
        if "match" not in trig:
            raise ValueError("todo trigger do context_engine precisa de 'match'")


# ───────────────────────────── aplicadores ─────────────────────────────

def rgba(hex_color: str, alpha: str = "ff") -> str:
    return f"rgba({hex_color.lstrip('#')}{alpha})"


def apply_hyprland(data: dict) -> None:
    hl, pal = data["hyprland"], data["palette"]
    lua = (
        "hl.config({"
        "general = {"
        f"gaps_in = {hl['gaps_in']}, gaps_out = {hl['gaps_out']}, "
        f"border_size = {hl['border_size']}, layout = \"{hl['layout']}\", "
        "col = { "
        f"active_border = {{ colors = {{\"{rgba(pal['border_active'])}\", \"{rgba(pal['secondary'])}\"}}, angle = 45 }}, "
        f"inactive_border = \"{rgba(pal['border_inactive'], 'aa')}\" "
        "} }, "
        f"decoration = {{ rounding = {hl['rounding']}, shadow = {{ color = 0x55{pal['primary'].lstrip('#')} }} }}, "
        f"animations = {{ enabled = {str(hl['animations_enabled']).lower()} }}"
        "})"
    )
    err = hypr_eval(lua)
    log(f"[ERRO] hyprctl eval falhou: {err}" if err else "[OK] Hyprland")


def apply_wallpaper(data: dict, retries: int = 1) -> None:
    path = ROOT / data["wallpaper"]["path"]
    if not path.exists():
        log(f"[AVISO] Wallpaper não encontrado: {path} — pulando")
        return
    for attempt in range(retries):
        monitors = [m["name"] for m in hypr_json("monitors")]
        ok = all(run(["hyprctl", "hyprpaper", "wallpaper", f"{m},{path}"]).returncode == 0 for m in monitors)
        if ok:
            active = run(["hyprctl", "hyprpaper", "listactive"]).stdout
            if monitors and all(f"{m}: {path}" in active for m in monitors):
                log(f"[OK] Wallpaper ({', '.join(monitors)})")
                return
        if attempt < retries - 1:
            time.sleep(0.5)
    log("[AVISO] hyprpaper não confirmou o wallpaper (está rodando?)")


def palette_vars(pal: dict) -> dict:
    return {k: v for k, v in pal.items()}


def apply_waybar(data: dict) -> None:
    pal = data["palette"]
    header = "\n".join(f"@define-color {k} {v};" for k, v in palette_vars(pal).items())
    css = (
        f"/* GERADO pelo Project Azmuth — DNA: {data['dna']['id']}. Não edite aqui; edite os CSS em waybar/ no projeto. */\n"
        f"{header}\n\n{(ROOT / 'waybar/base.css').read_text()}\n"
        f"/* ── overrides do DNA ── */\n{(ROOT / data['waybar']['style']).read_text()}"
    )
    WAYBAR_STYLE.parent.mkdir(parents=True, exist_ok=True)
    WAYBAR_STYLE.write_text(css)
    if run(["pgrep", "-x", "waybar"]).returncode == 0:
        run(["pkill", "-SIGUSR2", "-x", "waybar"])  # recarrega config + estilo sem matar
    else:
        hypr_exec("waybar")
    log("[OK] Waybar")


def apply_rofi(data: dict) -> None:
    pal = data["palette"]
    vars_ = "\n".join(f"    {k.replace('_', '-')}: {v};" for k, v in pal.items())
    vars_ += f"\n    background-alpha: {pal['background']}e6;\n    primary-dim: {pal['primary']}33;"
    ROFI_THEME.parent.mkdir(parents=True, exist_ok=True)
    ROFI_THEME.write_text(
        f"/* GERADO pelo Project Azmuth — DNA: {data['dna']['id']} */\n"
        f"* {{\n{vars_}\n}}\n"
        f"@import \"{ROOT / 'rofi/base.rasi'}\"\n"
        f"@import \"{ROOT / data['rofi']['theme']}\"\n"
    )
    log("[OK] Rofi")


def apply_dunst(data: dict) -> None:
    tmpl = ROOT / "dunst/dunstrc.tmpl"
    if not tmpl.exists() or not shutil.which("dunst"):
        return
    DUNST_RC.parent.mkdir(parents=True, exist_ok=True)
    DUNST_RC.write_text(Template(tmpl.read_text()).substitute(palette_vars(data["palette"]), dna=data["dna"]["id"]))
    if run(["dunstctl", "reload"]).returncode != 0:
        run(["pkill", "-x", "dunst"])  # o D-Bus reativa o dunst sob demanda com o rc novo
    log("[OK] Dunst")


def apply_hyprlock(data: dict) -> None:
    """A tela de bloqueio também se transforma: cores + wallpaper do DNA."""
    tmpl = ROOT / "hypr/hyprlock.conf.tmpl"
    colors = {k: v.lstrip("#") for k, v in data["palette"].items()}
    HYPRLOCK_CONF.write_text(Template(tmpl.read_text()).safe_substitute(
        colors, dna=data["dna"]["id"], name=data["dna"]["name"].upper(),
        wallpaper=ROOT / data["wallpaper"]["path"]))


def unit_exists(name: str) -> bool:
    return run(["systemctl", "--user", "cat", name]).returncode == 0


def daemon_start(name: str) -> None:
    if unit_exists(name):
        run(["systemctl", "--user", "start", name])
    elif run(["pgrep", "-x", name.split()[0]]).returncode != 0:
        hypr_exec(name)


def daemon_stop(name: str) -> None:
    if unit_exists(name):
        run(["systemctl", "--user", "stop", name])
    else:
        run(["pkill", "-x", name.split()[0]])


def apply_daemons(data: dict, state: dict) -> dict:
    """Cada DNA é autocontido: o que o DNA anterior ligou/desligou é desfeito,
    a não ser que o novo DNA reafirme a mesma coisa."""
    d = data.get("daemons") or {}
    enable, disable = list(d.get("enable") or []), list(d.get("disable") or [])
    prev = state.get("daemons") or {}
    for name in prev.get("enabled", []):
        if name not in enable:
            daemon_stop(name)
    for name in prev.get("disabled", []):
        if name not in disable:
            daemon_start(name)
    for name in enable:
        daemon_start(name)
    for name in disable:
        daemon_stop(name)
    if enable or disable or prev.get("enabled") or prev.get("disabled"):
        log(f"[OK] Daemons (+{len(enable)} / -{len(disable)})")
    return {"enabled": enable, "disabled": disable}


def apply_apps(data: dict) -> None:
    apps = (data.get("apps") or {}).get("autostart") or []
    if not apps:
        return
    classes = [c.get("class", "") for c in hypr_json("clients")]
    launched = []
    for app in apps:
        if isinstance(app, str):
            app = {"cmd": app}
        cmd = app["cmd"]
        pattern = app.get("class")
        if pattern:
            running = any(re.search(pattern, c) for c in classes)
        else:
            running = run(["pgrep", "-x", cmd.split()[0]]).returncode == 0
        if running:
            continue
        rules = {"workspace": app["workspace"]} if "workspace" in app else None
        hypr_exec(cmd, rules)
        launched.append(cmd.split()[0])
    log(f"[OK] Apps: {', '.join(launched) if launched else 'já abertos'}")


def signal_waybar_module() -> None:
    run(["pkill", f"-RTMIN+{WAYBAR_SIGNAL}", "-x", "waybar"])


def hud_running() -> bool:
    return bool(shutil.which("qs")) and run(["pgrep", "-f", f"qs.*{HUD_DIR}"]).returncode == 0


def hud_ipc(*args: str) -> None:
    spawn(["qs", "-p", str(HUD_DIR), "ipc", "call", "hud", *args])


# ───────────────────────────── transformação ─────────────────────────────

def transform(ref: str, source: str = "manual", quiet: bool = False, apps: bool = True) -> dict:
    path = resolve(ref)
    if not path.exists():
        raise FileNotFoundError(f"DNA não encontrado: {path}")
    data = load_dna(path)  # falha aqui = nada foi alterado
    state = read_state()
    t0 = time.monotonic()

    log(f"Aplicando DNA: {data['dna']['name']} ({data['dna']['id']})")
    if not quiet:
        snd = (data.get("sound") or {}).get("transform")
        play(ROOT / snd if snd else None)
        if hud_running():
            hud_ipc("flash", data["palette"]["primary"])
    apply_hyprland(data)
    apply_waybar(data)
    apply_wallpaper(data, retries=12 if quiet else 2)
    apply_rofi(data)
    apply_dunst(data)
    apply_hyprlock(data)
    daemons = apply_daemons(data, state)
    if apps:
        apply_apps(data)

    previous = state.get("current")
    update_state(
        current=data["dna"]["id"],
        previous=previous if previous != data["dna"]["id"] else state.get("previous"),
        changed_at=time.time(),
        source=source,
        daemons=daemons,
        pending=None,
    )
    signal_waybar_module()
    if not quiet:
        notify(f"DNA: {data['dna']['name']}", data["dna"]["description"])
    log(f"Transformação concluída em {(time.monotonic() - t0) * 1000:.0f} ms.")
    return data


def locked(name: str) -> None:
    play(sound("error"))
    notify("DNA bloqueado", f"{name} ainda não foi sequenciado (dna/*.yaml inexistente).", "normal")
    log(f"[BLOQUEADO] {name}")


# ───────────────────────────── comandos ─────────────────────────────

def cmd_slot(key: str) -> None:
    roster = load_roster()
    slot = next((s for s in roster["slots"] if str(s["key"]) == key), None)
    if slot is None:
        raise SystemExit(f"[ERRO] slot inexistente: {key}")
    if not available(slot["id"]):
        return locked(slot["name"])
    transform(slot["id"], source="master_control")


def cmd_neutral() -> None:
    transform(load_roster()["neutral"], source="rollback")


def window_hits(dna: dict, classes: list[str]) -> int:
    hits = 0
    for trig in (dna.get("context_engine") or {}).get("triggers") or []:
        kind, _, pattern = trig["match"].partition(":")
        if kind == "class":
            hits += sum(bool(re.search(pattern, c)) for c in classes)
    return hits


def cmd_random() -> None:
    """Sorteio ponderado pelas métricas atuais: janelas abertas que casam com os
    gatilhos de cada DNA + carga da CPU (alta carga puxa para o Neutral)."""
    roster = load_roster()
    current = read_state().get("current")
    ids = [roster["neutral"]] + [s["id"] for s in roster["slots"] if available(s["id"])]
    candidates = [i for i in ids if i != current] or ids
    classes = [c.get("class", "") for c in hypr_json("clients")]
    load1 = os.getloadavg()[0] / (os.cpu_count() or 1)
    weights = []
    for dna_id in candidates:
        dna = yaml.safe_load(resolve(dna_id).read_text())
        w = 1.0 + 2.0 * window_hits(dna, classes)
        if dna_id == roster["neutral"]:
            w += 2.0 * load1
        weights.append(w)
    choice = random.choices(candidates, weights=weights)[0]
    log(f"[RANDOMIZER] pesos: {dict(zip(candidates, (round(w, 2) for w in weights)))} → {choice}")
    transform(choice, source="randomizer")


def cmd_accept() -> None:
    pending = read_state().get("pending")
    if not pending or time.time() - pending.get("ts", 0) > SUGGESTION_WINDOW:
        log("Nenhuma sugestão pendente.")
        return
    transform(pending["dna"], source="context_engine")


def cmd_master(mode: str) -> None:
    on = read_state().get("master_control", False)
    on = {"on": True, "off": False}.get(mode, not on)
    update_state(master_control=on)
    signal_waybar_module()
    play(sound("hud_open" if on else "neutral"))
    notify("Master Control " + ("ATIVO" if on else "desligado"),
           "Context Engine troca de DNA sozinho. Super+Esc volta ao Neutral." if on else "Context Engine volta ao modo assistido.",
           "normal" if on else "low")
    log(f"Master Control: {'on' if on else 'off'}")


def roster_entries() -> list[dict]:
    roster = load_roster()
    current = read_state().get("current")
    entries = [{"key": None, "id": roster["neutral"], "name": "Neutral", "color": None}] + roster["slots"]
    out = []
    for e in entries:
        item = {"key": e["key"], "id": e["id"], "name": e["name"], "available": available(e["id"]),
                "color": e["color"], "secondary": None, "description": "DNA ainda não sequenciado",
                "current": e["id"] == current}
        if item["available"]:
            dna = yaml.safe_load(resolve(e["id"]).read_text())
            item.update(name=dna["dna"]["name"], color=dna["palette"]["primary"],
                        secondary=dna["palette"]["secondary"], description=dna["dna"]["description"])
        out.append(item)
    return out


def cmd_hud(action: str) -> None:
    if hud_running():
        hud_ipc(action)
        return
    if action != "toggle":
        return
    # fallback sem Quickshell: seletor em rofi
    entries = roster_entries()
    lines = []
    for e in entries:
        key = f"[{e['key']}]" if e["key"] is not None else "[Esc]"
        mark = "●" if e["current"] else ("" if e["available"] else "")
        lines.append(f"{key:5} {e['name']}  {mark}")
    r = run(["rofi", "-dmenu", "-i", "-p", "OMNITRIX", "-format", "i", "-theme", str(ROFI_THEME)],
            input="\n".join(lines))
    if r.returncode != 0 or not r.stdout.strip():
        return
    e = entries[int(r.stdout.strip())]
    if not e["available"]:
        return locked(e["name"])
    transform(e["id"], source="hud")


def cmd_lock() -> None:
    if shutil.which("hyprlock"):
        if run(["pidof", "hyprlock"]).returncode != 0:
            spawn(["hyprlock"])
    else:
        notify("hyprlock não instalado", "sudo pacman -S hyprlock", "normal")


POWER = [
    ("\uf023   Bloquear", lambda: cmd_lock()),
    ("\uf186   Suspender", lambda: run(["systemctl", "suspend"])),
    ("\uf2f5   Sair da sessão", lambda: hypr_eval("hl.dispatch(hl.dsp.exit())")),
    ("\uf2f9   Reiniciar", lambda: run(["systemctl", "reboot"])),
    ("\uf011   Desligar", lambda: run(["systemctl", "poweroff"])),
]


def cmd_power() -> None:
    r = run(["rofi", "-dmenu", "-i", "-p", "ENERGIA", "-format", "i", "-theme", str(ROFI_THEME),
             "-theme-str", "listview { lines: 5; } window { width: 360px; }"],
            input="\n".join(label for label, _ in POWER))
    if r.returncode == 0 and r.stdout.strip():
        POWER[int(r.stdout.strip())][1]()


def cmd_current(as_json: bool) -> None:
    state = read_state()
    if as_json:
        print(json.dumps(state))
    else:
        print(state.get("current", "nenhum"))


def cmd_waybar() -> None:
    """Saída do módulo custom/omnitrix da waybar."""
    state = read_state()
    cur = state.get("current") or "neutral"
    name = cur
    try:
        name = yaml.safe_load(resolve(cur).read_text())["dna"]["name"]
    except (FileNotFoundError, KeyError, TypeError):
        pass
    master = state.get("master_control", False)
    text = f"  {name.upper()}" + ("  " if master else "")
    tooltip = (f"DNA ativo: {name}\nMaster Control: {'ATIVO' if master else 'off'}\n\n"
               "Clique: Omnitrix HUD · Direito: Randomizer · Meio: Master Control")
    print(json.dumps({"text": text, "tooltip": tooltip, "class": ["dna-" + cur] + (["master"] if master else []),
                      "alt": cur}))


def cmd_restore() -> None:
    ref = read_state().get("current") or load_roster()["neutral"]
    if not available(ref):
        ref = load_roster()["neutral"]
    transform(ref, source="restore", quiet=True, apps=False)


def cmd_wallpaper() -> None:
    ref = read_state().get("current") or load_roster()["neutral"]
    apply_wallpaper(load_dna(resolve(ref)), retries=6)


def link(target: Path, src: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_symlink() or target.exists():
        if target.is_symlink() and target.resolve() == src.resolve():
            return
        backup = target.with_name(target.name + ".pre-azmuth")
        target.rename(backup)
        log(f"[backup] {target} → {backup.name}")
    target.symlink_to(src)
    log(f"[link] {target} → {src}")


def cmd_install() -> None:
    link(HOME / ".local/bin/azmuth", ROOT / "bin/azmuth")
    link(HOME / ".config/waybar/config.jsonc", ROOT / "waybar/config.jsonc")
    link(HOME / ".config/hypr/azmuth.lua", ROOT / "hypr/azmuth.lua")
    link(HOME / ".config/hypr/hypridle.conf", ROOT / "hypr/hypridle.conf")


COMMANDS = {
    "apply": lambda a: transform(a[0]),
    "slot": lambda a: cmd_slot(a[0]),
    "neutral": lambda a: cmd_neutral(),
    "rollback": lambda a: cmd_neutral(),
    "random": lambda a: cmd_random(),
    "accept": lambda a: cmd_accept(),
    "master": lambda a: cmd_master(a[0] if a else "toggle"),
    "hud": lambda a: cmd_hud(a[0] if a else "toggle"),
    "current": lambda a: cmd_current("--json" in a),
    "roster": lambda a: print(json.dumps(roster_entries())),
    "waybar": lambda a: cmd_waybar(),
    "restore": lambda a: cmd_restore(),
    "wallpaper": lambda a: cmd_wallpaper(),
    "install": lambda a: cmd_install(),
    "lock": lambda a: cmd_lock(),
    "power": lambda a: cmd_power(),
}
NEEDS_ARG = {"apply", "slot"}


def main() -> None:
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        sys.exit(0 if args else 1)
    if args[0].endswith(".yaml"):  # uso original: core.py dna/<nome>.yaml
        args = ["apply", args[0]]
    cmd, rest = args[0], args[1:]
    if cmd not in COMMANDS or (cmd in NEEDS_ARG and not rest):
        print(__doc__)
        sys.exit(1)
    try:
        COMMANDS[cmd](rest)
    except FileNotFoundError as e:
        log(f"[ERRO] {e}")
        sys.exit(1)
    except ValueError as e:
        log(f"[ERRO DE VALIDAÇÃO] {e}")
        play(sound("error"))
        sys.exit(1)


if __name__ == "__main__":
    main()
