"""Cores e marcadores Galvan por pasta; ícone composto e portátil."""
import base64
import hashlib
import html
import json
import math
import re
import shutil
import subprocess
import time
from pathlib import Path
from string import Template
from urllib.parse import unquote, urlparse

import file_manager as fm

EDITOR = fm.ROOT / "filemanager/editor"
REQUEST = fm.STATE / "folder-editor-request.json"
META = ".azmuth-folder"
OWNER = "project-azmuth"
COLOR = re.compile(r"^#[0-9a-fA-F]{6}$")


def glyphs():
    source = (fm.ROOT / "shell/Galvan.js").read_text()
    pattern = r'id: "([^"]+)", meaning: "([^"]+)", path: "([^"]+)", nodes: "([^"]*)"'
    return {i: {"id": i, "meaning": m, "path": p, "nodes": n} for i, m, p, n in re.findall(pattern, source)}


def folder(ref):
    if ref.startswith("file://"):
        u = urlparse(ref)
        if u.netloc not in ("", "localhost"):
            raise ValueError("Selecione uma pasta local.")
        ref = unquote(u.path)
    p = Path(ref).expanduser().resolve()
    if not p.is_dir():
        raise ValueError("Selecione uma pasta existente.")
    if (p / META).is_symlink() or (p / ".directory").is_symlink():
        raise ValueError("A configuração da pasta é um link; personalize o destino diretamente.")
    return p


def validate(value):
    if not isinstance(value, dict) or not COLOR.fullmatch(str(value.get("color", ""))):
        raise ValueError("Use uma cor no formato #RRGGBB.")
    markers = value.get("markers", [])
    if not isinstance(markers, list):
        raise ValueError("A lista de marcadores é inválida.")
    known = glyphs()
    result = []
    for i, marker in enumerate(markers):
        if not isinstance(marker, dict):
            raise ValueError("Marcador inválido.")
        kind = marker.get("kind", "glyph")
        text = str(marker.get("value", ""))
        if kind not in ("glyph", "text") or (kind == "glyph" and text not in known) or not text:
            raise ValueError("Escolha uma runa ou escreva um marcador.")
        tint = str(marker.get("color", "#d6ffe0"))
        if not COLOR.fullmatch(tint):
            raise ValueError("Cor de marcador inválida.")
        size = float(marker.get("size", .18))
        x, y = float(marker.get("x", .75)), float(marker.get("y", .75))
        if not all(math.isfinite(n) for n in (size, x, y)):
            raise ValueError("Posição de marcador inválida.")
        size = max(.06, min(.45, size))
        result.append({
            "uid": str(marker.get("uid", "m" + str(i))), "kind": kind, "value": text,
            "color": tint.lower(), "x": max(size/2, min(1-size/2, x)),
            "y": max(size/2, min(1-size/2, y)), "size": size,
            "badge": bool(marker.get("badge", True)),
        })
    return {"color": value["color"].lower(), "markers": result}


def render(value):
    style = validate(value)
    known = glyphs()
    parts = []
    for marker in style["markers"]:
        size = marker["size"] * 256
        x, y = marker["x"] * 256 - size/2, marker["y"] * 256 - size/2
        color = marker["color"]
        part = f'<g transform="translate({x:.3f} {y:.3f})">'
        if marker["badge"]:
            part += f'<rect width="{size:.3f}" height="{size:.3f}" rx="{size*.16:.3f}" fill="#091017" stroke="{color}" stroke-width="1.5"/>'
        if marker["kind"] == "glyph":
            rune = known[marker["value"]]
            scale = size * .66 / 24
            part += f'<g transform="translate({size*.17:.3f} {size*.17:.3f}) scale({scale:.4f})">'
            part += f'<path d="{rune["path"]}" fill="none" stroke="{color}" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"/>'
            part += f'<path d="{rune["nodes"]}" fill="{color}"/></g>'
        else:
            label = html.escape(marker["value"])
            font = size * min(.60, 1.10/max(1, len(marker["value"])))
            part += f'<text x="{size/2:.3f}" y="{size/2:.3f}" dy=".35em" text-anchor="middle" font-family="JetBrainsMono Nerd Font, sans-serif" font-weight="bold" font-size="{font:.3f}" fill="{color}">{label}</text>'
        parts.append(part + "</g>")
    p = style["color"]
    return Template((fm.ROOT / "filemanager/folder.svg.tmpl").read_text()).substitute(
        color=p, back=fm.blend(p, "#071016", .35), edge=fm.blend(p, "#ffffff", .28),
        light=fm.blend(p, "#ffffff", .40), markers="".join(parts))


def entry(text, name="Icon"):
    group = ""
    for line in text.splitlines():
        if line.startswith("["):
            group = line
        elif group == "[Desktop Entry]" and line.startswith(name + "="):
            return line.partition("=")[2]
    return None


def load(ref):
    p = folder(ref)
    meta = p / META / "style.json"
    if meta.exists():
        record = json.loads(meta.read_text())
        if record.get("owner") != OWNER:
            raise ValueError("Existe outra configuração com o mesmo nome nesta pasta.")
        style = validate(record["style"])
    else:
        primary = fm.current_dna()["palette"]["primary"]
        style = {"color": primary, "markers": []}
    return {"ok": True, "path": str(p), "name": p.name, "style": style}


def refresh(p):
    uri = p.as_uri()
    if shutil.which("dbus-send"):
        try:
            subprocess.run(["dbus-send", "--session", "--type=signal", "/KDirNotify",
                            "org.kde.KDirNotify.FilesChanged", "array:string:" + uri],
                           capture_output=True, timeout=5)
        except (OSError, subprocess.TimeoutExpired):
            pass


def save(ref, value):
    p = folder(ref)
    style = validate(value)
    meta = p / META
    config = p / ".directory"
    old = config.read_text() if config.exists() else ""
    saved = meta / "style.json"
    if saved.exists():
        record = json.loads(saved.read_text())
        if record.get("owner") != OWNER:
            raise ValueError("A configuração existente não pertence ao Azmuth.")
    else:
        record = {"owner": OWNER, "version": 1, "previous_icon": entry(old),
                  "had_directory": config.exists()}
    svg = render(style)
    digest = hashlib.sha256(svg.encode()).hexdigest()[:16]
    name = "icon-" + digest + ".svg"
    meta.mkdir(exist_ok=True)
    fm.atomic_write(meta / name, svg)
    record["style"] = style
    fm.atomic_write(saved, json.dumps(record, ensure_ascii=False, indent=2))
    fm.merge_config(config, {"Desktop Entry": {"Icon": "./" + META + "/" + name}})
    refresh(p)
    return {"ok": True, "path": str(p), "markers": len(style["markers"])}


def reset(ref):
    p = folder(ref)
    meta = p / META
    record_path = meta / "style.json"
    if not record_path.exists():
        return {"ok": True}
    record = json.loads(record_path.read_text())
    if record.get("owner") != OWNER:
        raise ValueError("Configuração de outra origem; nada foi alterado.")
    config = p / ".directory"
    text = config.read_text() if config.exists() else ""
    if (entry(text) or "").startswith("./" + META + "/"):
        group = ""
        lines = []
        for line in text.splitlines():
            if line.startswith("["):
                group = line
            if group == "[Desktop Entry]" and line.startswith("Icon="):
                if record["previous_icon"] is not None:
                    lines.append("Icon=" + record["previous_icon"])
            else:
                lines.append(line)
        restored = "\n".join(lines).strip() + "\n"
        if not record["had_directory"] and restored.strip() == "[Desktop Entry]":
            config.unlink(missing_ok=True)
        else:
            fm.atomic_write(config, restored)
    for icon in meta.glob("icon-*.svg"):
        if re.fullmatch(r"icon-[0-9a-f]{16}\.svg", icon.name):
            icon.unlink()
    record_path.unlink()
    try:
        meta.rmdir()
    except OSError:
        pass
    refresh(p)
    return {"ok": True}


def launch(ref):
    p = folder(ref)
    fm.atomic_write(REQUEST, json.dumps({"path": str(p), "nonce": time.time()}))
    if not shutil.which("qs"):
        raise ValueError("Quickshell não encontrado.")
    log_path = fm.STATE / "folder-editor.log"
    with open(log_path, "a") as log:
        subprocess.Popen(["qs", "-n", "-p", str(EDITOR)], stdout=log, stderr=log,
                         start_new_session=True)
    return {"ok": True}


def main(args):
    try:
        action = args[0]
        if action == "--decorate" and len(args) >= 2:
            result = launch(args[1])
        elif action == "--style-load" and len(args) >= 2:
            result = load(args[1])
        elif action == "--style-save" and len(args) >= 3:
            result = save(args[1], json.loads(args[2]))
        elif action == "--style-reset" and len(args) >= 2:
            result = reset(args[1])
        elif action == "--style-preview" and len(args) >= 2:
            svg = render(json.loads(args[1]))
            result = {"ok": True, "svg": base64.b64encode(svg.encode()).decode()}
        else:
            raise ValueError("Ação de pasta incompleta.")
    except (ValueError, OSError, KeyError, TypeError) as exc:
        result = {"ok": False, "error": str(exc)}
    print(json.dumps(result, ensure_ascii=False))
