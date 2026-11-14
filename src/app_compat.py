"""Project Azmuth — apps nítidos na escala fracionada (chamado pelo `azmuth install`).

Apps que rodam pelo XWayland são desenhados em 1x e esticados pelo Hyprland (escala 1.2 → borrado).
Aqui cada app conhecido passa a abrir nativo no Wayland:
  Spotify  ~/.config/spotify-flags.conf (lido pelo /usr/bin/spotify do Arch)
  Godot    atalho próprio em ~/.local/share/applications com --display-driver wayland; em notebook
           com Intel + NVIDIA no NVK (Vulkan experimental em placas antigas: letras corrompidas),
           a Godot só enxerga a Intel.
Arquivos que o usuário já tinha e que não foram gerados aqui não são sobrescritos.
"""
import shutil
from pathlib import Path

HOME = Path.home()
MARK = "Project Azmuth"
APPS = HOME / ".local/share/applications"
ICD = Path("/usr/share/vulkan/icd.d")


def _write(path: Path, text: str) -> str:
    if path.exists() and MARK not in path.read_text(errors="ignore"):
        return f"[apps] {path} já existe (não é do Azmuth); mantido"
    if path.exists() and path.read_text(errors="ignore") == text:
        return ""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return f"[apps] {path}"


def spotify() -> str:
    if not shutil.which("spotify"):
        return ""
    return _write(HOME / ".config/spotify-flags.conf",
                  f"# {MARK}: nativo no Wayland (nítido com escala fracionada)\n"
                  "--enable-features=UseOzonePlatform,WaylandWindowDecorations\n--ozone-platform=wayland\n")


def godot_env() -> str:
    """Força a Intel só quando a alternativa é o NVK (nouveau) — com driver NVIDIA proprietário, não mexe."""
    intel, nvk = ICD / "intel_icd.json", ICD / "nouveau_icd.json"
    return f"env VK_DRIVER_FILES={intel} " if intel.exists() and nvk.exists() else ""


def godot() -> str:
    src = Path("/usr/share/applications/org.godotengine.Godot.desktop")
    if not src.exists():
        return ""
    lines = []
    for line in src.read_text().splitlines():
        if line.startswith("Exec=godot"):
            line = "Exec=" + godot_env() + "godot --display-driver wayland" + line[len("Exec=godot"):]
        lines.append(line)
        if line == "[Desktop Entry]":
            lines.append(f"# {MARK}: Wayland nativo (nítido); gerado pelo azmuth install")
    return _write(APPS / "org.godotengine.Godot.desktop", "\n".join(lines) + "\n")


def install() -> list[str]:
    return [m for m in (spotify(), godot()) if m]
