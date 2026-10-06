#!/usr/bin/env python3
"""Gera terminal/omnitrix.txt: o símbolo do Omnitrix em half-blocks para o fastfetch.
$1 = ampulheta (cor primária do DNA), $2 = aro. Uso: .venv/bin/python tools/gen_logo.py"""
from pathlib import Path
from PIL import Image, ImageDraw

W, H = 24, 24          # pixels → 24 colunas x 12 linhas (cada célula = 2 pixels na vertical)
S = 8                  # supersampling
img = Image.new("L", (W * S, H * S), 0)
d = ImageDraw.Draw(img)
c, R = W * S / 2, W * S / 2 - 1
d.ellipse((c - R, c - R, c + R, c + R), fill=2)            # aro
r = R * 0.78
d.ellipse((c - r, c - r, c + r, c + r), fill=0)            # face
m, t = r * 0.72, r * 0.86
d.polygon([(c - m, c - t), (c + m, c - t), (c, c - S)], fill=1)  # ampulheta
d.polygon([(c - m, c + t), (c + m, c + t), (c, c + S)], fill=1)
# reduz cada classe por média de área (BOX) e limiar 50% — mantém a simetria
ring = img.point(lambda v: 255 if v == 2 else 0).resize((W, H), Image.BOX).load()
glass = img.point(lambda v: 255 if v == 1 else 0).resize((W, H), Image.BOX).load()
px = {(x, y): (1 if glass[x, y] >= 110 else (2 if ring[x, y] >= 128 else 0)) for x in range(W) for y in range(H)}

lines = []
for y in range(0, H, 2):
    out, cur = "", None
    for x in range(W):
        top, bot = px[x, y], px[x, y + 1]
        cls = top or bot
        ch = " " if not cls else ("█" if top and bot else ("▀" if top else "▄"))
        if cls and top and bot and top != bot:
            cls = 1  # célula mista: a ampulheta tem prioridade
        if cls and cls != cur:
            out += f"${cls}"
            cur = cls
        out += ch
    lines.append(out.rstrip())
Path(__file__).resolve().parent.parent.joinpath("terminal/omnitrix.txt").write_text("\n".join(lines) + "\n")
print("\n".join(l.replace("$1", "").replace("$2", "") for l in lines))
