#!/usr/bin/env python3
"""Project Azmuth — conversor de imagem em cena ASCII vivo (galeria de fundos).

As imagens de terceiros e as cenas geradas ficam SÓ no PC, em ~/.local/share/azmuth/scenes/
(fontes em _src/, configuração de produção em _build/scenes.json). Aqui fica só a ferramenta.

  ascii_scene.py build   [config.json] [ids…]   gera scene.json + preview.png por cena
  ascii_scene.py gallery [config.json]          gera galeria.html (prévia animada de curadoria)

REGRA: efeitos novos entram SEMPRE no fim da lista "effects" de uma cena. Os liga/desliga que o Miguel
salva (settings.json → desktop.effects.<cena>) são posicionais: inserir no meio desloca as escolhas dele.

Formato da cena: grade 100 linhas × 307 colunas; "lum" = brilho em base36 por célula, "col" = cor rrggbb.
Composição (ver docs/superpowers/specs/2026-11-14-galeria-ascii-design.md, 2.4.1): tela inteira,
personagem fora do Omnitrix central, fundo desfocado / espelhado / em camadas.
"""
import colorsys
import json
import os
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

ROWS = 100
COLS = round(ROWS * 16 / 9 / 0.58)            # 307
CA = 0.58                                     # largura da célula / altura
RAMP = " .'`^,:;Il!i><~+_-?][}{1)(|tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$"
B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
SCENES = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "azmuth/scenes"
CONFIG = SCENES / "_build" / "scenes.json"
FONT_PATH = Path("/usr/share/fonts/TTF/JetBrainsMonoNerdFontMono-Bold.ttf")


def font():
    return ImageFont.truetype(str(FONT_PATH), 10) if FONT_PATH.exists() else ImageFont.load_default()


def load(c, src_dir):
    img = Image.open(Path(src_dir) / c["src"]).convert("RGB")
    if "crop" in c:
        x0, y0, x1, y1 = c["crop"]
        img = img.crop((round(x0 * img.width), round(y0 * img.height), round(x1 * img.width), round(y1 * img.height)))
    if c.get("rotate"):
        img = img.rotate(c["rotate"], expand=True)
    img = ImageOps.autocontrast(img, cutoff=1)
    return ImageEnhance.Contrast(img).enhance(c.get("contrast", 1.3))


def value(r, g, b, c):
    l = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
    if c.get("light"):                       # fundo claro: o que tem cor ou é escuro ganha, o branco some
        _, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        l = max((1 - l) * 0.75, s * v)
    if "key" in c:                           # cor de fundo a apagar (ex.: bege dos pôsteres)
        kr, kg, kb, tol, keep = c["key"]
        if abs(r - kr) + abs(g - kg) + abs(b - kb) < tol:
            l *= keep
    return l


def cover(img, fx, fy):
    want = COLS * CA / ROWS
    ar = img.width / img.height
    if ar > want:
        w = round(img.height * want); x = round(min(max(fx * img.width - w / 2, 0), img.width - w))
        return img.crop((x, 0, x + w, img.height))
    h = round(img.width / want); y = round(min(max(fy * img.height - h / 2, 0), img.height - h))
    return img.crop((0, y, img.width, y + h))


def place_layer(c, lay, src_dir):
    """Uma camada: imagem (com recorte próprio) escalada e posicionada na tela."""
    img = load({**c, **lay}, src_dir)
    zoom = lay.get("zoom", 1.0)
    fx, fy = lay.get("focus", (0.5, 0.5))
    px, py = lay.get("place", (0.5, 0.5))
    h_cells = max(1, round(ROWS * zoom))
    w_cells = max(1, round(img.width / img.height * h_cells / CA))
    small = img.resize((w_cells, h_cells), Image.LANCZOS)
    return small, round(px * COLS - fx * w_cells), round(py * ROWS - fy * h_cells), w_cells, h_cells


def mirror(v, n):
    m = v % (2 * n)
    return m if m < n else 2 * n - 1 - m


def convert(c, src_dir=None):
    src_dir = Path(src_dir or SCENES / "_src")
    gamma, bdim, vig, fe = c.get("gamma", 1.4), c.get("bd", 0.3), c.get("vig", 0.35), c.get("feather", 0.12)
    main = {k: c[k] for k in ("zoom", "focus", "place") if k in c}
    layers = c.get("layers") or [main]
    # fundo: a própria imagem (ou um pedaço dela, bdcrop) cobrindo a tela, desfocada e apagada
    bimg = load(c, src_dir)
    if "bdcrop" in c:
        x0, y0, x1, y1 = c["bdcrop"]
        bimg = bimg.crop((round(x0 * bimg.width), round(y0 * bimg.height), round(x1 * bimg.width), round(y1 * bimg.height)))
    fx, fy = c.get("focus", (0.5, 0.5))
    bd = cover(bimg, fx, fy).resize((COLS, ROWS), Image.LANCZOS).filter(ImageFilter.GaussianBlur(c.get("bdblur", 2.5)))
    placed = [place_layer(c, lay, src_dir) for lay in layers]
    fr, fc = fe * ROWS, fe * ROWS / CA          # esfumado: em linhas e em colunas
    lum = [[0.0] * COLS for _ in range(ROWS)]
    col = [["000000"] * COLS for _ in range(ROWS)]
    for y in range(ROWS):
        for x in range(COLS):
            br, bg_, bb = bd.getpixel((x, y))
            l = (value(br, bg_, bb, c) ** gamma) * bdim
            rgb = (br, bg_, bb)
            for n, (small, X0, Y0, w, h) in enumerate(placed):
                sx, sy = x - X0, y - Y0
                inside = 0 <= sx < w and 0 <= sy < h
                if not inside and c.get("tile") and n == 0:
                    # continuação espelhada da própria arte (ex.: a multidão do Invencível)
                    r, g, b = small.getpixel((mirror(sx, w), mirror(sy, h)))
                    if c.get("tilefix") == "red":           # nas cópias, a capa vermelha vira mais um viltrumita de branco
                        hh, ss, vv = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
                        if ss > 0.35 and (hh < 0.08 or hh > 0.92):
                            r, g, b = 236, 240, 246
                    l, rgb = value(r, g, b, c) ** gamma, (r, g, b)
                    continue
                if not inside:
                    continue
                r, g, b = small.getpixel((sx, sy))
                ls = value(r, g, b, c) ** gamma
                # bordas da imagem que caem dentro da tela são esfumadas; as que saem da tela, não
                d = 1e9
                if not c.get("tile"):
                    if X0 > 0: d = min(d, sx / fc)
                    if X0 + w < COLS: d = min(d, (w - 1 - sx) / fc)
                    if Y0 > 0: d = min(d, sy / fr)
                    if Y0 + h < ROWS: d = min(d, (h - 1 - sy) / fr)
                e = max(0.0, min(1.0, d)); e = e * e * (3 - 2 * e)
                l = ls * e + l * (1 - e)
                rgb = tuple(round(a * e + b_ * (1 - e)) for a, b_ in zip((r, g, b), rgb))
            cx, cy = (x / COLS - 0.5) * 2, (y / ROWS - 0.5) * 2
            l *= (1 - vig) + vig * max(0.0, 1 - (cx * cx * 0.5 + cy * cy * 0.5))
            lum[y][x] = min(1.0, l * c.get("dim", 1.0))
            col[y][x] = "%02x%02x%02x" % rgb
    small, X0, Y0, w, h = placed[0]
    bx0, by0 = max(0, X0), max(0, Y0)
    box = [bx0, by0, min(COLS, X0 + w) - bx0, min(ROWS, Y0 + h) - by0]
    return {"cols": COLS, "rows": ROWS, "box": box,
            "lum": ["".join(B36[min(35, round(v * 35))] for v in row) for row in lum],
            "col": ["".join(row) for row in col]}


def render(grid, omni=True):
    W, H = 1920, 1080
    cw, ch = W / COLS, H / ROWS
    im = Image.new("RGB", (W, H), (5, 6, 7))
    d = ImageDraw.Draw(im)
    FNT = font()
    for y in range(ROWS):
        lrow, crow = grid["lum"][y], grid["col"][y]
        for x in range(COLS):
            v = B36.index(lrow[x]) / 35
            if v < 0.04:
                continue
            h = crow[x * 6:x * 6 + 6]
            r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
            k = max(1.15, 110 / max(r, g, b, 1))
            d.text((x * cw, y * ch), RAMP[min(len(RAMP) - 1, int(v * (len(RAMP) - 1)))], font=FNT,
                   fill=(min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k))))
    if omni:                                 # o Omnitrix da área de trabalho, no tamanho real (raio = 27% da altura)
        cx, cy, R = W / 2, H / 2, H * 0.27
        d.ellipse((cx - R * 1.04, cy - R * 1.04, cx + R * 1.04, cy + R * 1.04), fill=(12, 15, 20))
        d.ellipse((cx - R, cy - R, cx + R, cy + R), outline=(56, 189, 248), width=5)
        d.ellipse((cx - R * .7, cy - R * .7, cx + R * .7, cy + R * .7), fill=(5, 7, 10), outline=(56, 189, 248), width=4)
    return im


def build(sid, cfg, scenes_dir=SCENES):
    """Converte uma cena da configuração e grava <scenes_dir>/<sid>/scene.json + preview.png."""
    scenes_dir = Path(scenes_dir)
    out = scenes_dir / sid
    out.mkdir(parents=True, exist_ok=True)
    grid = convert(cfg, scenes_dir / "_src")
    scene = {"id": sid, "title": cfg.get("title", sid), "source": cfg["src"], "effects": cfg.get("effects", []),
             "mono": cfg.get("mono", False), **grid}
    (out / "scene.json").write_text(json.dumps(scene, ensure_ascii=False))
    render(grid).resize((640, 360), Image.LANCZOS).save(out / "preview.png")
    return out


def build_carousel(sid, title, ids, every, scenes_dir=SCENES):
    """Cena carrossel: troca entre outras cenas a cada `every` segundos (com glitch)."""
    scenes_dir = Path(scenes_dir)
    out = scenes_dir / sid
    out.mkdir(parents=True, exist_ok=True)
    (out / "scene.json").write_text(json.dumps({"id": sid, "title": title, "carousel": list(ids), "every": every,
                                                "effects": []}, ensure_ascii=False))
    first = scenes_dir / ids[0] / "preview.png"
    if first.exists():
        shutil.copyfile(first, out / "preview.png")
    return out


def gallery(cfg_path=CONFIG, scenes_dir=SCENES):
    """Prévia animada (abre por file://): gera scene.js de cada cena e galeria.html."""
    scenes_dir = Path(scenes_dir)
    cfg = json.loads(Path(cfg_path).read_text())
    items = []
    for sid, c in cfg.items():
        if "carousel" in c:
            items.append({"id": sid, "title": c.get("title", sid), "fx": ["troca de cena com glitch (tempo ajustável)"],
                          "carousel": c["carousel"], "every": c.get("every", 6)})
    for sid, c in cfg.items():
        if "carousel" in c or not (scenes_dir / sid / "scene.json").exists():
            continue
        txt = (scenes_dir / sid / "scene.json").read_text()
        (scenes_dir / sid / "scene.js").write_text("__scene(" + txt + ");\n")
        items.append({"id": sid, "title": c.get("title", sid), "fx": [e["nome"] for e in c.get("effects", [])]})
    for c in [i for i in items if "carousel" in i]:          # o carrossel vem antes das cenas que ele mostra
        items.remove(c)
        pos = min([n for n, i in enumerate(items) if i["id"] in c["carousel"]] or [len(items)])
        items.insert(pos, c)
    tpl = (Path(__file__).with_name("ascii_gallery.html")).read_text()
    html = tpl.replace("__LIST__", json.dumps(items, ensure_ascii=False))
    out = scenes_dir / "galeria.html"
    out.write_text(html)
    return out


def main(argv):
    if not argv or argv[0] not in ("build", "gallery"):
        raise SystemExit(__doc__)
    rest = argv[1:]
    cfg_path = Path(rest.pop(0)) if rest and rest[0].endswith(".json") else CONFIG
    if argv[0] == "gallery":
        print(gallery(cfg_path))
        return
    cfg = json.loads(cfg_path.read_text())
    only = set(rest)
    for sid, c in cfg.items():
        if only and sid not in only or "carousel" in c:
            continue
        build(sid, c)
        print("ok", sid)
    for sid, c in cfg.items():
        if "carousel" in c and (not only or sid in only):
            build_carousel(sid, c.get("title", sid), c["carousel"], c.get("every", 6))
            print("ok", sid, "(carrossel)")


if __name__ == "__main__":
    main(sys.argv[1:])
