#!/usr/bin/env python3
"""
Project Azmuth - gerador procedural de wallpapers de DNA.

Desenha um fundo escuro com trilhas de circuito galvânico e o símbolo do
Omnitrix (ampulheta) no centro, na cor primária do DNA. É um placeholder
até existir arte própria — o DNA aponta para o arquivo, então trocar por
uma arte definitiva é só substituir o PNG.

Uso (dependências só de dev: pillow, numpy, pyyaml):
  .venv/bin/python tools/gen_wallpapers.py dna/massa_cinzenta.yaml [...]
  .venv/bin/python tools/gen_wallpapers.py --all     # todo DNA cujo wallpaper não existe
"""

import math
import random
import sys
from pathlib import Path

import yaml
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
W, H = 2560, 1440
SS = 2  # supersampling para bordas suaves


def rgb(hex_color: str) -> tuple[int, int, int]:
    h = hex_color.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def scale(c: tuple[int, int, int], k: float) -> tuple[int, int, int]:
    return tuple(max(0, min(255, int(v * k))) for v in c)


def circuits(draw: ImageDraw.ImageDraw, color, seed: int) -> None:
    """Trilhas em 'Manhattan' com cotovelos de 45° e nós nas pontas."""
    rnd = random.Random(seed)
    w, h = W * SS, H * SS
    cx, cy = w / 2, h / 2
    step = 40 * SS
    for _ in range(95):
        x = rnd.randrange(0, w, step)
        y = rnd.randrange(0, h, step)
        # deixa o centro limpo para o símbolo
        if abs(x - cx) < 520 * SS and abs(y - cy) < 520 * SS:
            continue
        pts = [(x, y)]
        for _ in range(rnd.randint(2, 5)):
            d = rnd.choice([(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)])
            n = rnd.randint(1, 5) * step
            x, y = x + d[0] * n, y + d[1] * n
            pts.append((x, y))
        width = rnd.choice([2, 2, 3]) * SS
        draw.line(pts, fill=color, width=width, joint="curve")
        r = 6 * SS
        ex, ey = pts[-1]
        draw.ellipse((ex - r, ey - r, ex + r, ey + r), outline=color, width=2 * SS)
        sx, sy = pts[0]
        draw.ellipse((sx - r / 2, sy - r / 2, sx + r / 2, sy + r / 2), fill=color)


def omnitrix(img: Image.Image, primary, secondary, background) -> None:
    draw = ImageDraw.Draw(img)
    cx, cy = W * SS / 2, H * SS / 2
    R = 330 * SS

    def circle(r, **kw):
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), **kw)

    # aro externo (bezel) com ranhuras
    circle(R + 60 * SS, fill=(22, 24, 26), outline=scale(primary, 0.35), width=4 * SS)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        x, y = cx + math.cos(a) * (R + 30 * SS), cy + math.sin(a) * (R + 30 * SS)
        g = 22 * SS
        draw.rounded_rectangle((x - g, y - g / 2.5, x + g, y + g / 2.5), radius=6 * SS, fill=(40, 44, 48))
    circle(R + 6 * SS, fill=None, outline=primary, width=8 * SS)
    # face do relógio
    circle(R, fill=scale(background, 0.9))
    # ampulheta: dois triângulos com as pontas no centro
    m = 0.62 * R
    top = [(cx - m, cy - R * 0.94 + 40 * SS), (cx + m, cy - R * 0.94 + 40 * SS), (cx, cy - 14 * SS)]
    bot = [(cx - m, cy + R * 0.94 - 40 * SS), (cx + m, cy + R * 0.94 - 40 * SS), (cx, cy + 14 * SS)]
    # recorta pela face para os cantos seguirem o círculo
    mask = Image.new("L", (W * SS, H * SS), 0)
    md = ImageDraw.Draw(mask)
    md.polygon(top, fill=255)
    md.polygon(bot, fill=255)
    face = Image.new("L", (W * SS, H * SS), 0)
    ImageDraw.Draw(face).ellipse((cx - R + 18 * SS, cy - R + 18 * SS, cx + R - 18 * SS, cy + R - 18 * SS), fill=255)
    img.paste(primary, mask=ImageChops.multiply(mask, face))
    # detalhe interno (reflexo) no triângulo de cima
    draw.line([(cx - m * 0.55, cy - R * 0.62), (cx + m * 0.55, cy - R * 0.62)], fill=secondary, width=6 * SS)


def render(dna_path: Path) -> Path:
    data = yaml.safe_load(dna_path.read_text())
    pal = data["palette"]
    primary, secondary, bg = rgb(pal["primary"]), rgb(pal["secondary"]), rgb(pal["background"])
    out = ROOT / data["wallpaper"]["path"]

    img = Image.new("RGB", (W * SS, H * SS), bg)
    # vinheta radial sutil na cor primária
    glow = Image.new("RGB", img.size, (0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = W * SS / 2, H * SS / 2
    for i in range(30, 0, -1):
        r = i * 34 * SS
        gd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=scale(primary, 0.18 * (1 - i / 30)))
    img = ImageChops.add(img, glow.filter(ImageFilter.GaussianBlur(60 * SS)))

    # circuitos com brilho (camada borrada + camada nítida)
    layer = Image.new("RGB", img.size, (0, 0, 0))
    circuits(ImageDraw.Draw(layer), scale(primary, 0.42), seed=sum(map(ord, data["dna"]["id"])))
    img = ImageChops.add(img, layer.filter(ImageFilter.GaussianBlur(8 * SS)))
    img = ImageChops.add(img, ImageChops.multiply(layer, Image.new("RGB", img.size, (150, 150, 150))))

    # símbolo com halo
    sym = Image.new("RGB", img.size, (0, 0, 0))
    omnitrix(sym, primary, secondary, bg)
    halo = Image.new("RGB", img.size, (0, 0, 0))
    hd = ImageDraw.Draw(halo)
    r = 420 * SS
    hd.ellipse((cx - r, cy - r, cx + r, cy + r), fill=scale(primary, 0.45))
    img = ImageChops.add(img, halo.filter(ImageFilter.GaussianBlur(90 * SS)))
    mask = sym.convert("L").point(lambda v: 255 if v else 0)
    img.paste(sym, mask=mask)

    img = img.resize((W, H), Image.LANCZOS)
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, optimize=True)
    print(f"[OK] {out.relative_to(ROOT)}")
    return out


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)
    if args == ["--all"]:
        paths = [p for p in sorted((ROOT / "dna").glob("*.yaml")) if p.name != "omnitrix.yaml"]
        paths = [p for p in paths if not (ROOT / yaml.safe_load(p.read_text())["wallpaper"]["path"]).exists()]
    else:
        paths = [Path(a) for a in args]
    for p in paths:
        render(p)
