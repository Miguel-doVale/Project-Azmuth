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

Formato do gatilho:  match: "class:<regex>"  ou  "title:<regex>"
  suggest: true  → sugere no modo assistido e troca sob Master Control
  suggest: false → só age sob Master Control
"""

import fcntl
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
