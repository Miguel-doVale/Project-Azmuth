"""Project Azmuth — tema GTK 3/4 gerado da paleta do DNA.

Cobre o seletor de arquivos do sistema (xdg-desktop-portal-gtk: "anexar arquivo" no navegador,
"abrir/salvar" de apps GTK) e qualquer janela GTK. A cada transformação:
  ~/.config/gtk-3.0/gtk.css e ~/.config/gtk-4.0/gtk.css   ← gtk/gtk.css.tmpl
  ~/.config/gtk-{3,4}.0/settings.ini                        ← modo escuro
  gsettings org.gnome.desktop.interface color-scheme        ← prefer-dark
Um gtk.css que não foi gerado pelo Azmuth é preservado como gtk.css.pre-azmuth.
"""
import configparser
import shutil
import subprocess
from pathlib import Path
from string import Template

import file_manager as fm

HOME = Path.home()
ROOT = Path(__file__).resolve().parent.parent
MARK = "GERADO pelo Project Azmuth"
DIRS = [HOME / ".config/gtk-3.0", HOME / ".config/gtk-4.0"]


def values(data: dict) -> dict:
    p = data["palette"]
    v = fm.theme_values(data)
    v.update(
        dna=data["dna"]["id"],
        frame=fm.blend(p["background"], p["primary"], 0.28),
        input=fm.blend(p["background"], "#000000", 0.25),
        primary_light=fm.blend(p["primary"], "#ffffff", 0.18),
    )
    return v


def render(data: dict) -> str:
    return Template((ROOT / "gtk/gtk.css.tmpl").read_text()).substitute(values(data))


def _settings_ini(path: Path) -> None:
    cp = configparser.ConfigParser(interpolation=None)
    cp.optionxform = str
    if path.exists():
        cp.read(path, encoding="utf-8")
    if not cp.has_section("Settings"):
        cp.add_section("Settings")
    want = {"gtk-application-prefer-dark-theme": "1", "gtk-icon-theme-name": "Azmuth"}
    if all(cp["Settings"].get(k) == v for k, v in want.items()):
        return
    cp["Settings"].update(want)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        cp.write(f, space_around_delimiters=False)


def _gsettings_dark() -> None:
    if not shutil.which("gsettings"):
        return
    want = {"color-scheme": "'prefer-dark'", "gtk-theme": "'Adwaita-dark'", "icon-theme": "'Azmuth'"}
    for key, value in want.items():
        cur = subprocess.run(["gsettings", "get", "org.gnome.desktop.interface", key],
                             capture_output=True, text=True).stdout.strip()
        if cur != value:
            subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", key, value.strip("'")],
                           capture_output=True)


def apply(data: dict) -> bool:
    """Grava o tema; devolve True se algo mudou (o portal é reiniciado para o próximo diálogo)."""
    css = render(data)
    changed = False
    for d in DIRS:
        target = d / "gtk.css"
        if target.exists() and MARK not in target.read_text(errors="ignore"):
            backup = d / "gtk.css.pre-azmuth"
            if not backup.exists():
                shutil.copy2(target, backup)
        if not target.exists() or target.read_text(errors="ignore") != css:
            fm.atomic_write(target, css)
            changed = True
        _settings_ini(d / "settings.ini")
    _gsettings_dark()
    if changed and shutil.which("systemctl"):
        # o portal GTK lê o CSS ao iniciar; reiniciar só afeta diálogos abertos agora
        subprocess.run(["systemctl", "--user", "try-restart", "xdg-desktop-portal-gtk.service"],
                       capture_output=True, timeout=10)
    return changed
