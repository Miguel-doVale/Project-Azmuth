#!/usr/bin/env python3
"""
Project Azmuth - Core Engine
Lê um arquivo dna/<nome>.yaml e aplica o estado no Hyprland via hyprctl eval.
"""

import sys
import subprocess
import yaml
from pathlib import Path

REQUIRED_TOP_LEVEL = ["dna", "palette", "hyprland", "wallpaper", "waybar", "rofi"]
REQUIRED_DNA = ["id", "name", "core", "description"]
REQUIRED_PALETTE = ["primary", "secondary", "background", "foreground", "border_active", "border_inactive"]
REQUIRED_HYPRLAND = ["gaps_in", "gaps_out", "border_size", "rounding", "animations_enabled", "layout"]


def load_dna(path: Path) -> dict:
    with open(path, "r") as f:
        data = yaml.safe_load(f)
    validate(data)
    return data


def validate(data: dict) -> None:
    for key in REQUIRED_TOP_LEVEL:
        if key not in data:
            raise ValueError(f"Campo obrigatório ausente: '{key}'")
    for key in REQUIRED_DNA:
        if key not in data["dna"]:
            raise ValueError(f"Campo obrigatório ausente em 'dna': '{key}'")
    for key in REQUIRED_PALETTE:
        if key not in data["palette"]:
            raise ValueError(f"Campo obrigatório ausente em 'palette': '{key}'")
    for key in REQUIRED_HYPRLAND:
        if key not in data["hyprland"]:
            raise ValueError(f"Campo obrigatório ausente em 'hyprland': '{key}'")
    if data["dna"]["core"] not in ("arch", "kali"):
        raise ValueError(f"'dna.core' deve ser 'arch' ou 'kali', recebido: {data['dna']['core']}")


def hex_to_rgba(hex_color: str, alpha: str = "ee") -> str:
    return f"rgba({hex_color.lstrip('#')}{alpha})"


def apply_hyprland(data: dict) -> None:
    hl = data["hyprland"]
    palette = data["palette"]

    lua = (
        "hl.config({"
        "general = {"
        f"gaps_in = {hl['gaps_in']}, "
        f"gaps_out = {hl['gaps_out']}, "
        f"border_size = {hl['border_size']}, "
        f'layout = "{hl["layout"]}", '
        f'col = {{ active_border = "{hex_to_rgba(palette["border_active"])}", '
        f'inactive_border = "{hex_to_rgba(palette["border_inactive"])}" }}'
        "}, "
        f"decoration = {{ rounding = {hl['rounding']} }}, "
        f"animations = {{ enabled = {str(hl['animations_enabled']).lower()} }}"
        "})"
    )

    result = subprocess.run(["hyprctl", "eval", lua], capture_output=True, text=True)
    output = (result.stdout + result.stderr).strip()
    if result.returncode != 0 or "error" in output.lower():
        print(f"[ERRO] hyprctl eval falhou: {output}")
    else:
        print("[OK] Configuração do Hyprland aplicada")


def apply_wallpaper(data: dict, project_root: Path) -> None:
    wallpaper_path = project_root / data["wallpaper"]["path"]
    if not wallpaper_path.exists():
        print(f"[AVISO] Wallpaper não encontrado: {wallpaper_path} — pulando")
        return

    subprocess.run(["hyprctl", "hyprpaper", "preload", str(wallpaper_path)])
    subprocess.run(["hyprctl", "hyprpaper", "wallpaper", f",{wallpaper_path}"])
    print(f"[OK] Wallpaper aplicado: {wallpaper_path.name}")


def main():
    if len(sys.argv) != 2:
        print("Uso: python src/core.py dna/<nome>.yaml")
        sys.exit(1)

    dna_path = Path(sys.argv[1])
    project_root = Path(__file__).resolve().parent.parent

    if not dna_path.exists():
        print(f"[ERRO] Arquivo não encontrado: {dna_path}")
        sys.exit(1)

    try:
        data = load_dna(dna_path)
    except ValueError as e:
        print(f"[ERRO DE VALIDAÇÃO] {e}")
        sys.exit(1)

    print(f"Aplicando DNA: {data['dna']['name']} ({data['dna']['id']})")
    apply_hyprland(data)
    apply_wallpaper(data, project_root)
    print("Transformação concluída.")


if __name__ == "__main__":
    main()
