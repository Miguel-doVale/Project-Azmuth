#!/usr/bin/env python3
"""
Project Azmuth - Context Engine

Daemon que observa o contexto pelo socket de eventos do Hyprland (socket2):

- Janela em foco casa com um `context_engine.triggers[].match` de algum DNA
  e fica em foco por DWELL segundos →
    * modo assistido (padrão): notificação de 5s
      "Padrão de desenvolvimento detectado. Ativar Massa Cinzenta?"
      [Super+Y ou clique aceita · ignorar/fechar dispensa]
    * Master Control ligado: troca imediata (Super+Esc volta ao Neutral)
- Monitor conectado/desconectado → reaplica o wallpaper do DNA ativo.
- Timer do Omnitrix: bipes no último minuto, destransforma para o Neutral ao
  estourar e avisa quando a recarga termina (preferências em settings.json).

Formato do gatilho:  match: "class:<regex>"  ou  "title:<regex>"
  suggest: true  → sugere no modo assistido e troca sob Master Control
  suggest: false → só age sob Master Control
"""

import fcntl
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
import core  # noqa: E402

DWELL = 1.5            # segundos com o app em foco antes de reagir
SUGGEST_TIMEOUT = 5    # duração da notificação (s)
COOLDOWN = 10 * 60     # após dispensar uma sugestão, não repetir o mesmo DNA por 10 min
MANUAL_GRACE = 5 * 60  # após troca manual, respeitar a escolha do usuário por 5 min
BEEP_MARKS = (60, 30, 10, 5, 4, 3, 2, 1)  # segundos restantes em que o relógio apita


class Engine:
    def __init__(self) -> None:
        self.triggers: list[tuple[str, str, re.Pattern, bool, str]] = []
        self.cooldown: dict[str, float] = {}
        self.focus = ("", "")
        self.focus_seq = 0
        self.suggesting = False
        self.lock = threading.Lock()
        self.load_triggers()

    def load_triggers(self) -> None:
        self.triggers.clear()
        for path in sorted(core.DNA_DIR.glob("*.yaml")):
            if path.name == "omnitrix.yaml":
                continue
            try:
                data = yaml.safe_load(path.read_text())
                name = data["dna"]["name"]
                for t in (data.get("context_engine") or {}).get("triggers") or []:
                    kind, _, pattern = t["match"].partition(":")
                    if kind not in ("class", "title"):
                        continue
                    self.triggers.append((data["dna"]["id"], kind, re.compile(pattern), bool(t.get("suggest", True)),
                                          t.get("message") or f"Contexto de {name} detectado"))
            except Exception as e:  # um DNA quebrado não derruba o daemon
                core.log(f"[context] ignorando {path.name}: {e}")
        core.log(f"[context] {len(self.triggers)} gatilho(s) carregado(s)")

    # ── eventos ──
    def on_event(self, name: str, data: str) -> None:
        if name == "activewindow":
            cls, _, title = data.partition(",")
            with self.lock:
                self.focus = (cls, title)
                self.focus_seq += 1
                seq = self.focus_seq
            threading.Timer(DWELL, self.evaluate, args=(seq,)).start()
        elif name in ("monitoradded", "monitorremoved"):
            threading.Timer(1.0, lambda: subprocess.run([str(core.ROOT / "bin/azmuth"), "wallpaper"],
                                                          capture_output=True)).start()
        elif name == "configreloaded":
            self.load_triggers()

    def evaluate(self, seq: int) -> None:
        with self.lock:
            if seq != self.focus_seq or self.suggesting:
                return  # o foco mudou durante o dwell, ou já há sugestão na tela
            cls, title = self.focus
        if not core.read_settings()["context_engine"]:
            return
        state = core.read_state()
        current = state.get("current")
        master = state.get("master_control", False)
        now = time.time()

        for dna_id, kind, pattern, suggest, message in self.triggers:
            value = cls if kind == "class" else title
            if not pattern.search(value) or dna_id == current:
                continue
            if master:
                core.log(f"[context] Master Control: {value} → {dna_id}")
                subprocess.run([str(core.ROOT / "bin/azmuth"), "apply", dna_id], capture_output=True)
                return
            if not suggest:
                continue
            if now - self.cooldown.get(dna_id, 0) < COOLDOWN:
                continue
            if state.get("source") not in ("context_engine", "restore") and now - state.get("changed_at", 0) < MANUAL_GRACE:
                continue
            threading.Thread(target=self.suggest, args=(dna_id, message), daemon=True).start()
            return

    def suggest(self, dna_id: str, message: str) -> None:
        with self.lock:
            self.suggesting = True
        try:
            name = yaml.safe_load(core.resolve(dna_id).read_text())["dna"]["name"]
            core.update_state(pending={"dna": dna_id, "ts": time.time()})
            core.play(core.sound("hud_open"))
            core.log(f"[context] sugerindo {dna_id}")
            r = subprocess.run(
                ["notify-send", "-a", "Azmuth", "-u", "normal", "-t", str(SUGGEST_TIMEOUT * 1000),
                 "-A", "accept=Ativar", "--wait", message, f"Ativar {name}?  [Super+Y aceita]"],
                capture_output=True, text=True, timeout=SUGGEST_TIMEOUT + 2,
            )
            if r.stdout.strip() == "accept":
                subprocess.run([str(core.ROOT / "bin/azmuth"), "accept"], capture_output=True)
        except subprocess.TimeoutExpired:
            pass
        finally:
            state = core.read_state()
            if state.get("current") != dna_id:  # dispensada (não aceita) → cooldown
                self.cooldown[dna_id] = time.time()
                core.update_state(pending=None)
            with self.lock:
                self.suggesting = False


EVENTS_FILE = core.STATE_DIR / "events.json"


def check_events(now: float) -> None:
    """Lembretes do calendário (Central → Calendário). Dia inteiro = às 8h."""
    import datetime as dt
    try:
        events = json.loads(EVENTS_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return
    done = set(core.read_state().get("notified_events", []))
    fired = []
    for e in events:
        remind = e.get("remind", -1)
        if remind is None or remind < 0:
            continue
        try:
            when = dt.datetime.strptime(f"{e['date']} {e.get('time') or '08:00'}", "%Y-%m-%d %H:%M").timestamp()
        except (KeyError, ValueError):
            continue
        tag = f"{e.get('id')}@{e['date']}{e.get('time', '')}-{remind}"
        if tag in done or not (when - remind * 60 <= now <= when + 15 * 60):
            continue
        hora = e.get("time") or "hoje"
        quando = "agora" if now >= when else f"em {round((when - now) / 60)} min"
        core.play(core.sound("beep"))
        core.notify(f"Lembrete · {e.get('title', '')}", f"{hora} · {quando}", "normal", 10000)
        fired.append(tag)
    if fired:
        keep = [t for t in done if t.split("@")[1][:10] >= dt.date.today().isoformat()][-200:]
        core.update_state(notified_events=keep + fired)


# ── cores do core (cânone: amarelo = scan/coleta, azul = recalibração) e failsafe ──
DOWNLOADS = Path.home() / "Downloads"
APP_DIRS = [Path("/usr/share/applications"), Path.home() / ".local/share/applications"]
PARTIAL = (".part", ".crdownload", ".download", ".partial")


class CoreWatch:
    def __init__(self) -> None:
        self.apps = self.list_apps()
        self.scan_until = 0.0
        self.last_apps = 0.0
        self.hot_since = 0.0
        self.failsafe_done = False

    @staticmethod
    def list_apps() -> dict:
        out = {}
        for d in APP_DIRS:
            for f in d.glob("*.desktop") if d.exists() else []:
                out[f.stem] = f
        return out

    @staticmethod
    def app_name(f: Path) -> str:
        for line in f.read_text(errors="ignore").splitlines():
            if line.startswith("Name="):
                return line[5:]
        return f.stem

    def tick(self, now: float) -> None:
        state = core.read_state()
        # recalibração: pacman segurando o banco de dados
        recal = Path("/var/lib/pacman/db.lck").exists()
        # novos apps instalados (a cada 10 s): pulso amarelo de scan
        if now - self.last_apps >= 10:
            self.last_apps = now
            cur = self.list_apps()
            new = [cur[k] for k in cur.keys() - self.apps.keys()]
            self.apps = cur
            for f in new[:3]:
                name = self.app_name(f)
                if "NoDisplay=true" in f.read_text(errors="ignore"):
                    continue
                self.scan_until = now + 5
                core.play(core.sound("hud_open"))
                core.notify("Novo DNA coletado", f"{name} → SEM PLAYLIST (organize na Central → Apps)")
        downloading = DOWNLOADS.exists() and any(p.suffix in PARTIAL for p in DOWNLOADS.iterdir())
        mode = "recalibrate" if recal else ("scan" if downloading or now < self.scan_until else "")
        if mode != state.get("core_mode", ""):
            core.update_state(core_mode=mode)
            core.write_theme()
            if state.get("core_mode") == "recalibrate" and mode != "recalibrate":
                core.play(core.sound("recharge"))
                core.notify("Recalibração concluída", "Sistema atualizado. Omnitrix pronto.")
            elif mode == "recalibrate":
                core.play(core.sound("beep"))
                core.log("[core] recalibrando (pacman)")
        self.check_failsafe(state, now)

    def check_failsafe(self, state: dict, now: float) -> None:
        if state.get("current") in (None, core.load_roster()["neutral"]):
            self.failsafe_done = False
            return
        reason = ""
        for bat in Path("/sys/class/power_supply").glob("BAT*"):
            try:
                cap = int((bat / "capacity").read_text())
                if cap <= 7 and (bat / "status").read_text().strip() == "Discharging":
                    reason = f"Bateria em {cap}%"
            except (OSError, ValueError):
                pass
        try:
            temps = [int(z.joinpath("temp").read_text()) / 1000 for z in Path("/sys/class/thermal").glob("thermal_zone*")
                     if z.joinpath("type").read_text().strip() == "x86_pkg_temp"]
            if temps and max(temps) >= 95:
                self.hot_since = self.hot_since or now
                if now - self.hot_since >= 10:
                    reason = f"Superaquecimento ({round(max(temps))}°C)"
            else:
                self.hot_since = 0.0
        except (OSError, ValueError):
            pass
        if reason and not self.failsafe_done:
            self.failsafe_done = True
            core.log(f"[failsafe] {reason}")
            subprocess.run([str(core.ROOT / "bin/azmuth"), "failsafe", reason], capture_output=True)


def timer_loop() -> None:
    """Energia do Omnitrix: bipes no último minuto, destransforma em 0% e avisa
    quando a carga volta ao mínimo para transformar."""
    neutral = core.load_roster()["neutral"]
    warned: set[int] = set()
    prev_energy = None
    last_events = 0.0
    watch = CoreWatch()
    last_watch = 0.0
    while True:
        time.sleep(1)
        try:
            if time.time() - last_watch >= 2:
                last_watch = time.time()
                watch.tick(last_watch)
            if time.time() - last_events >= 20:
                last_events = time.time()
                check_events(last_events)
            state, settings = core.read_state(), core.read_settings()
            info = core.timer_info(state, settings, neutral)
            e, rate = info["energy"], info["rate"]

            # recarregou até o mínimo: pronto para transformar de novo
            if prev_energy is not None and rate > 0 and prev_energy < info["min"] <= e:
                core.play(core.sound("recharge"))
                core.notify("Omnitrix recarregado", f"{round(e * 100)}% · pronto para transformar.")
                core.write_theme()
            prev_energy = e

            if rate >= 0:            # Neutral, Master Control ou energia desligada
                warned.clear()
                continue
            remaining = e / -rate    # segundos até 0%
            due = [m for m in BEEP_MARKS if remaining <= m and m not in warned]
            if due and remaining > 0:
                warned.update(due)
                core.play(core.sound("beep"))
                if 60 in due:
                    core.notify("Omnitrix", "1 minuto de energia.", "normal")
            if e <= 0:
                core.log("[timer] energia esgotada → Neutral")
                subprocess.run([str(core.ROOT / "bin/azmuth"), "timeout"], capture_output=True)
                warned.clear()
        except Exception as e:  # o timer nunca derruba o daemon
            core.log(f"[timer] erro: {e}")


def socket_path() -> str:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        sys.exit("[context] HYPRLAND_INSTANCE_SIGNATURE ausente — rode dentro do Hyprland")
    return f"{os.environ.get('XDG_RUNTIME_DIR', f'/run/user/{os.getuid()}')}/hypr/{sig}/.socket2.sock"


def single_instance():
    core.STATE_DIR.mkdir(parents=True, exist_ok=True)
    fh = open(core.STATE_DIR / "context_engine.pid", "w")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit("[context] já está rodando")
    fh.write(str(os.getpid()))
    fh.flush()
    return fh


def main() -> None:
    _lock = single_instance()  # noqa: F841 — mantém o lock enquanto o processo vive
    engine = Engine()
    threading.Thread(target=timer_loop, daemon=True).start()
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(socket_path())
                core.log("[context] conectado ao Hyprland")
                buf = b""
                while chunk := s.recv(4096):
                    buf += chunk
                    *lines, buf = buf.split(b"\n")
                    for line in lines:
                        name, _, data = line.decode(errors="replace").partition(">>")
                        engine.on_event(name, data)
        except (ConnectionError, FileNotFoundError) as e:
            core.log(f"[context] socket perdido ({e}); reconectando em 2s")
        time.sleep(2)


if __name__ == "__main__":
    main()
