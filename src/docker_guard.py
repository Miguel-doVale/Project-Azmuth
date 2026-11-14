"""Project Azmuth — failsafe dos containers (roda no Context Engine, em qualquer DNA).

Desligar o notebook de uma vez com um banco rodando num container pode corromper os dados.
Descarregando:
  ≤ WARN %  avisa uma vez: "em STOP % eu paro os containers"
  ≤ STOP %  `docker stop -t 30` em todos os containers rodando (cada banco recebe o sinal de
            desligar e tem até 30 s para fechar os arquivos) — uma vez por descarga
Ligar o carregador (ou a bateria subir acima do aviso) rearma tudo.
"""
import shutil
import subprocess
import threading
from pathlib import Path

WARN, STOP = 10, 7
POWER = Path("/sys/class/power_supply")


def battery() -> tuple[int, bool] | None:
    """(menor carga entre as baterias, alguma descarregando) ou None sem bateria."""
    caps, discharging = [], False
    for bat in POWER.glob("BAT*"):
        try:
            caps.append(int((bat / "capacity").read_text()))
            discharging |= (bat / "status").read_text().strip() == "Discharging"
        except (OSError, ValueError):
            pass
    return (min(caps), discharging) if caps else None


def decide(cap: int, discharging: bool, warned: bool, stopped: bool) -> str:
    """'' | 'reset' | 'warn' | 'stop' — puro, para teste."""
    if not discharging or cap > WARN:
        return "reset" if warned or stopped else ""
    if cap <= STOP and not stopped:
        return "stop"
    if not warned and not stopped:
        return "warn"
    return ""


def running() -> list[str]:
    if not shutil.which("docker"):
        return []
    try:
        r = subprocess.run(["docker", "ps", "--format", "{{.Names}}"], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return []
    return [n for n in r.stdout.split() if n] if r.returncode == 0 else []


class DockerGuard:
    def __init__(self, notify, log) -> None:
        self.notify, self.log = notify, log
        self.warned = self.stopped = False
        self.busy = False

    def tick(self) -> None:
        bat = battery()
        if not bat or self.busy:
            return
        action = decide(bat[0], bat[1], self.warned, self.stopped)
        if action == "reset":
            self.warned = self.stopped = False
        elif action == "warn":
            self.warned = True
            names = running()
            if names:
                self.notify("Bateria baixa", f"{len(names)} container(s) rodando. Em {STOP}% eu paro todos com segurança.",
                            "critical")
        elif action == "stop":
            self.stopped = self.warned = True
            self.busy = True
            threading.Thread(target=self._stop, daemon=True).start()

    def _stop(self) -> None:
        try:
            names = running()
            if not names:
                return
            self.log(f"[failsafe] parando containers: {', '.join(names)}")
            r = subprocess.run(["docker", "stop", "-t", "30", *names], capture_output=True, text=True, timeout=120)
            if r.returncode == 0:
                self.notify("FAILSAFE · containers parados", f"{', '.join(names)} desligados com segurança. "
                            "Os dados estão salvos; suba de novo quando ligar o carregador.", "critical")
            else:
                self.notify("FAILSAFE · falha ao parar containers", (r.stderr or "docker stop falhou").strip()[:200], "critical")
        except (OSError, subprocess.SubprocessError) as exc:
            self.notify("FAILSAFE · falha ao parar containers", str(exc)[:200], "critical")
        finally:
            self.busy = False
