"""Project Azmuth — cenas do fundo ASCII vivo (galeria da Central, `azmuth fundo`).

As cenas ficam só no PC, em ~/.local/share/azmuth/scenes/<id>/scene.json (+ preview.png),
geradas por tools/ascii_scene.py. "circuitos" é o fundo original da área de trabalho viva.
"""
import json
from pathlib import Path

CIRCUITOS = {"id": "circuitos", "title": "Circuitos (atual)", "effects": [], "mono": False,
             "carousel": None, "every": None, "preview": ""}


def _order(scenes_dir: Path) -> list[str]:
    try:
        return list(json.loads((scenes_dir / "_build" / "scenes.json").read_text()))
    except (OSError, ValueError):
        return []


def list_scenes(scenes_dir: Path) -> list[dict]:
    """Cenas válidas (scene.json legível), na ordem da configuração de produção; "circuitos" primeiro."""
    scenes_dir = Path(scenes_dir)
    found = []
    if scenes_dir.is_dir():
        for d in scenes_dir.iterdir():
            if not d.is_dir() or d.name.startswith("_"):
                continue
            try:
                s = json.loads((d / "scene.json").read_text())
            except (OSError, ValueError):
                continue
            if not isinstance(s, dict):
                continue
            car = s.get("carousel")
            found.append({
                "id": d.name,
                "title": s.get("title", d.name),
                "effects": [{"type": e.get("type", ""), "nome": e.get("nome", ""), "on": bool(e.get("on", True))}
                            for e in s.get("effects", []) if isinstance(e, dict)],
                "mono": bool(s.get("mono", False)),
                "carousel": car if isinstance(car, list) else None,
                "every": s.get("every") if car else None,
                "preview": str(d / "preview.png") if (d / "preview.png").exists() else "",
            })
    order = _order(scenes_dir)
    rank = {sid: n for n, sid in enumerate(order)}
    found.sort(key=lambda s: (rank.get(s["id"], len(order)), s["title"].lower()))
    return [dict(CIRCUITOS)] + found
