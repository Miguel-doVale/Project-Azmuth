#!/usr/bin/env python3
"""Dolphin do Project Azmuth: tema por DNA, configuração e ações locais."""
import json
import os
import re
import shutil
import subprocess
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from string import Template

ROOT = Path(__file__).resolve().parent.parent
HOME = Path.home()
CONFIG = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config"))
DATA = Path(os.environ.get("XDG_DATA_HOME", HOME / ".local/share"))
STATE = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "azmuth"
MANIFEST = STATE / "file-manager.json"
SCHEME = DATA / "color-schemes/AzmuthActive.colors"
STYLE = STATE / "dolphin.qss"
DOLPHIN_RC = CONFIG / "dolphinrc"


def atomic_write(path, content):
    path = Path(path)
    if path.exists() and path.read_text() == content:
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".azmuth.tmp")
    if path.exists():
        mode = path.stat().st_mode & 0o777
    else:
        mode = 0o644
    tmp.write_text(content, encoding="utf-8")
    tmp.chmod(mode)
    tmp.replace(path)


def merged_config(text, changes):
    """Altera apenas as chaves pedidas; mantém grupos e entradas do KDE intactos."""
    sections = {}
    lines = []
    name = None
    for line in text.splitlines():
        if re.fullmatch(r"\[[^\n]+\]", line):
            if name is not None:
                sections[name] = lines
            else:
                sections[None] = lines
            name, lines = line, []
        else:
            lines.append(line)
    sections[name] = lines
    for group, values in changes.items():
        key = "[" + group + "]"
        old = sections.get(key, [])
        remaining = dict(values)
        out = []
        for line in old:
            entry = line.partition("=")[0]
            if "=" in line and entry in values:
                if entry in remaining:
                    out.append(entry + "=" + str(remaining.pop(entry)))
            else:
                out.append(line)
        while out and not out[-1]:
            out.pop()
        out.extend(k + "=" + str(v) for k, v in remaining.items())
        sections[key] = out
    out = []
    for group, body in sections.items():
        if group is not None:
            out.append(group)
        out.extend(body)
        if out and out[-1]:
            out.append("")
    return "\n".join(out).rstrip() + "\n"


def merge_config(path, changes):
    path = Path(path)
    atomic_write(path, merged_config(path.read_text() if path.exists() else "", changes))


def rgb(value):
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
        raise ValueError("Cor inválida: " + value)
    return tuple(int(value[i:i+2], 16) for i in (1, 3, 5))


def blend(a, b, weight):
    return "#" + "".join(f"{round(x * (1-weight) + y * weight):02x}" for x, y in zip(rgb(a), rgb(b)))


def theme_values(data):
    p = data["palette"]
    return {
        **p,
        "surface": blend(p["background"], p["foreground"], 0.045),
        "raised": blend(p["background"], p["foreground"], 0.075),
        "alternate": blend(p["background"], p["foreground"], 0.025),
        "hover": blend(p["background"], p["primary"], 0.12),
        "selection": blend(p["background"], p["primary"], 0.24),
        "muted": blend(p["background"], p["foreground"], 0.60),
    }


def render_scheme(data):
    v = theme_values(data)
    text = "[General]\nName=Azmuth · DNA ativo\nColorScheme=AzmuthActive\n\n"
    for group in ("View", "Window", "Button", "Selection", "Tooltip", "Complementary", "Header"):
        bg = v["selection"] if group == "Selection" else (v["background"] if group == "View" else v["surface"])
        props = {
            "BackgroundNormal": bg, "BackgroundAlternate": v["alternate"],
            "ForegroundNormal": v["foreground"], "ForegroundInactive": v["muted"],
            "ForegroundActive": v["primary"], "ForegroundLink": v["primary"],
            "ForegroundVisited": v["secondary"], "ForegroundNegative": "#ff7b7b",
            "ForegroundNeutral": "#ffd76a", "ForegroundPositive": "#86efac",
            "DecorationFocus": v["primary"], "DecorationHover": v["secondary"],
        }
        text += "[Colors:" + group + "]\n"
        text += "".join(k + "=" + ",".join(map(str, rgb(val))) + "\n" for k, val in props.items()) + "\n"
    text += "[ColorEffects:Disabled]\nColor=56,56,56\nColorAmount=0\nColorEffect=0\nContrastAmount=0.45\nContrastEffect=1\nIntensityAmount=0.1\nIntensityEffect=2\n\n"
    text += "[ColorEffects:Inactive]\nChangeSelectionColor=true\nEnable=false\n\n"
    text += "[WM]\nactiveBackground=" + ",".join(map(str, rgb(v["surface"]))) + "\n"
    text += "activeForeground=" + ",".join(map(str, rgb(v["foreground"]))) + "\n"
    return text


def current_dna():
    import core
    return core.load_dna(core.resolve(core.read_state().get("current") or core.load_roster()["neutral"]))


def apply(data):
    """As cores atualizam nos arquivos; instâncias novas recebem o tema atual."""
    if not MANIFEST.exists():
        return False
    atomic_write(SCHEME, render_scheme(data))
    atomic_write(STYLE, Template((ROOT / "filemanager/dolphin.qss.tmpl").read_text()).substitute(theme_values(data)))
    merge_config(DOLPHIN_RC, {"UiSettings": {"ColorScheme": "AzmuthActive"}})
    return True


def places_xml(text):
    namespaces = {
        "bookmark": "http://www.freedesktop.org/standards/desktop-bookmarks",
        "kdepriv": "http://www.kde.org/kdepriv",
        "mime": "http://www.freedesktop.org/standards/shared-mime-info",
    }
    for prefix, uri in namespaces.items():
        ET.register_namespace(prefix, uri)
    root = ET.fromstring(text) if text.strip() else ET.Element("xbel")
    items = [
        ("Project Azmuth", ROOT, str(ROOT / "filemanager/omnitrix.svg")),
        ("Projetos", HOME / "Documents/Coding", "folder-development"),
        ("Assets · Azmuth", ROOT / "assets", "folder-pictures"),
        ("Capturas", HOME / "Pictures/Screenshots", "camera-photo"),
        ("Downloads", HOME / "Downloads", "folder-downloads"),
    ]
    existing = {b.get("href") for b in root.findall("bookmark")}
    offset = next((i+1 for i,b in enumerate(root) if b.tag == "bookmark" and b.get("href") == HOME.as_uri()), len(root))
    for title, path, icon in items:
        if not path.exists() or path.as_uri() in existing:
            continue
        b = ET.Element("bookmark", {"href": path.as_uri()})
        ET.SubElement(b, "title").text = title
        info = ET.SubElement(b, "info")
        meta = ET.SubElement(info, "metadata", {"owner": "http://freedesktop.org"})
        ET.SubElement(meta, "{" + namespaces["bookmark"] + "}icon", {"name": icon})
        kde = ET.SubElement(info, "metadata", {"owner": "http://www.kde.org"})
        ET.SubElement(kde, "ID").text = "azmuth-" + re.sub(r"[^a-z0-9]", "-", title.lower())
        ET.SubElement(kde, "isSystemItem").text = "false"
        root.insert(offset, b)
        offset += 1
        existing.add(path.as_uri())
    ET.indent(root, space=" ")
    return '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE xbel>\n' + ET.tostring(root, encoding="unicode") + "\n"


def install(data=None):
    """Instala uma vez, com backup de cada arquivo alterado e registro do que criou."""
    if MANIFEST.exists():
        apply(data or current_dna())
        return json.loads(MANIFEST.read_text())["backup"]
    targets = [
        DOLPHIN_RC, SCHEME, STYLE, DATA / "user-places.xbel",
        DATA / "dolphin/view_properties/global/.directory",
        DATA / "kxmlgui5/dolphin/dolphinui.rc",
        DATA / "kio/servicemenus/azmuth-tools.desktop",
        DATA / "applications/org.kde.dolphin.desktop",
    ]
    backup = CONFIG / ("azmuth-backup-dolphin-" + time.strftime("%Y%m%d-%H%M%S"))
    backup.mkdir(parents=True)
    manifest = {"backup": str(backup), "files": []}
    for i, target in enumerate(targets):
        saved = backup / (str(i) + "-" + target.name)
        existed = target.exists()
        if existed:
            shutil.copy2(target, saved)
        manifest["files"].append({"path": str(target), "existed": existed, "saved": str(saved)})
    atomic_write(MANIFEST, json.dumps(manifest, indent=2))
    merge_config(DOLPHIN_RC, {
        "General": {
            "AlwaysShowTabBar": "true", "ShowFullPath": "true", "ShowFullPathInTitlebar": "true",
            "ShowZoomSlider": "true", "ShowStatusBar": "1", "ShowToolTips": "false",
            "OpenExternallyCalledFolderInNewTab": "true", "BrowseThroughArchives": "true",
            "GlobalViewProps": "false", "SplitView": "false",
        },
        "IconsMode": {"IconSize": "48", "PreviewSize": "112", "MaximumTextLines": "2", "TextWidthIndex": "2", "UseSystemFont": "false", "ViewFont": "Sans Serif,11,-1,5,50,0,0,0,0,0"},
        "CompactMode": {"IconSize": "24", "PreviewSize": "48"},
        "DetailsMode": {"IconSize": "24", "PreviewSize": "32", "ExpandableFolders": "true", "HighlightEntireRow": "true", "UseSystemFont": "false", "ViewFont": "Sans Serif,11,-1,5,50,0,0,0,0,0"},
        "MainWindow": {"MenuBar": "Disabled", "ToolBarsMovable": "Disabled"},
        "MainWindow][Toolbar mainToolBar": {"IconSize": "22", "ToolButtonStyle": "IconOnly"},
        "PreviewSettings": {"Plugins": "directorythumbnail,imagethumbnail,jpegthumbnail,svgthumbnail,textthumbnail,comicbookthumbnail,opendocumentthumbnail,kraorathumbnail"},
    })
    merge_config(DATA / "dolphin/view_properties/global/.directory", {
        "Dolphin": {"Version": "4", "ViewMode": "1", "PreviewsShown": "true",
                    "SortRole": "text", "SortFoldersFirst": "true",
                    "VisibleRoles": "Details_text,Details_size,Details_modificationtime,Details_type,CustomizedDetails"},
    })
    places = DATA / "user-places.xbel"
    atomic_write(places, places_xml(places.read_text() if places.exists() else ""))
    atomic_write(DATA / "kxmlgui5/dolphin/dolphinui.rc", (ROOT / "filemanager/dolphinui.rc").read_text())
    az = HOME / ".local/bin/azmuth"
    menu = Template((ROOT / "filemanager/azmuth-tools.desktop.tmpl").read_text()).substitute(az=az)
    service = DATA / "kio/servicemenus/azmuth-tools.desktop"
    atomic_write(service, menu)
    service.chmod(0o755)
    desktop = Path("/usr/share/applications/org.kde.dolphin.desktop").read_text()
    desktop = re.sub(r"^Exec=.*$", "Exec=" + str(az) + " files %U", desktop, flags=re.M)
    desktop = re.sub(r"^DBusActivatable=.*$", "DBusActivatable=false", desktop, flags=re.M)
    if "DBusActivatable=" not in desktop:
        desktop = desktop.replace("[Desktop Entry]", "[Desktop Entry]\nDBusActivatable=false", 1)
    atomic_write(DATA / "applications/org.kde.dolphin.desktop", desktop)
    apply(data or current_dna())
    return str(backup)


def restore():
    if not MANIFEST.exists():
        return
    manifest = json.loads(MANIFEST.read_text())
    for entry in manifest["files"]:
        target = Path(entry["path"])
        if entry["existed"]:
            shutil.copy2(entry["saved"], target)
        else:
            target.unlink(missing_ok=True)
    MANIFEST.unlink()
    print("Configuração do Dolphin restaurada. O backup foi preservado.")


def main(args):
    if "--setup" in args:
        print("Backup: " + install())
        return
    if "--restore" in args:
        restore()
        return
    aliases = {"home": HOME, "projetos": HOME / "Documents/Coding", "azmuth": ROOT,
               "assets": ROOT / "assets", "imagens": HOME / "Pictures",
               "downloads": HOME / "Downloads", "capturas": HOME / "Pictures/Screenshots"}
    terminal = "--terminal" in args
    editor = "--code" in args
    split = "--split" in args
    paths = [a for a in args if a not in ("--terminal", "--code", "--split")]
    paths = [str(aliases.get(a, a)) for a in paths] or [str(HOME)]
    if terminal or editor:
        path = Path(paths[0]).expanduser().resolve()
        if terminal:
            path = path if path.is_dir() else path.parent
            command = ["kitty", "--directory", str(path)]
        else:
            command = ["code", "--", str(path)]
    else:
        themed = apply(current_dna())
        command = ["dolphin", "--new-window"]
        if themed:
            command += ["-stylesheet", str(STYLE)]
        if split:
            command += ["--split"]
        command += paths
    env = os.environ.copy()
    if not terminal and not editor:
        env["LANGUAGE"] = "pt_BR:pt"
        env["LC_ALL"] = "pt_BR.UTF-8"
        env["LANG"] = "pt_BR.UTF-8"
    subprocess.Popen(command, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
