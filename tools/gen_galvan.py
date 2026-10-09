#!/usr/bin/env python3
"""Gera shell/Galvan.js: o alfabeto Galvan do Azmuth.

Cada símbolo é um conjunto de traços numa grade 5×5 de pontos (só retas e
diagonais); toda ponta solta ganha um nó — o visual de "runa de circuito".
Edite RUNES e rode: python3 tools/gen_galvan.py
"""
from collections import Counter
from pathlib import Path

RUNES = [  # id, significado, polilinhas na grade 0..4
    ("mente", "Mente · intelecto", [[(2,1),(2,4)], [(1,1),(2,0),(3,1),(1,1)]]),
    ("codigo", "Código · criação", [[(1,1),(0,2),(1,3)], [(3,1),(4,2),(3,3)], [(2,0),(2,4)]]),
    ("rede", "Rede · conexão", [[(2,0),(2,2)], [(0,4),(2,2),(4,4)], [(0,0),(2,0)]]),
    ("som", "Som · ressonância", [[(0,1),(0,3)], [(2,0),(2,4)], [(4,1),(4,3)], [(0,2),(4,2)]]),
    ("jogo", "Jogo · desafio", [[(2,0),(4,2),(2,4),(0,2),(2,0)], [(2,1),(2,3)]]),
    ("trabalho", "Trabalho · ofício", [[(0,4),(0,1),(4,1),(4,4)], [(2,1),(2,3)], [(1,0),(3,0)]]),
    ("sistema", "Sistema · engrenagem", [[(1,0),(3,0),(4,2),(3,4),(1,4),(0,2),(1,0)], [(2,2),(2,3)]]),
    ("estrela", "Estrela · favorito", [[(2,0),(2,4)], [(0,2),(4,2)], [(1,1),(3,3)]]),
    ("energia", "Energia · poder", [[(3,0),(1,2),(3,2),(1,4)]]),
    ("tempo", "Tempo · Omnitrix", [[(0,0),(4,0),(0,4),(4,4),(0,0)]]),
    ("visao", "Visão · observar", [[(0,2),(2,0),(4,2),(2,4),(0,2)], [(2,2),(2,2)]]),
    ("dados", "Dados · memória", [[(0,0),(0,4)], [(0,1),(3,1)], [(0,3),(4,3)], [(2,1),(2,3)]]),
    ("fogo", "Fogo · Chama", [[(2,0),(4,4),(0,4),(2,0)], [(2,2),(2,4)]]),
    ("agua", "Água · Aquático", [[(0,1),(1,2),(2,1),(3,2),(4,1)], [(0,3),(1,4),(2,3),(3,4),(4,3)]]),
    ("cristal", "Cristal · Diamante", [[(2,0),(4,2),(2,4),(0,2),(2,0)], [(0,2),(4,2)]]),
    ("velocidade", "Velocidade · XLR8", [[(0,0),(2,2),(0,4)], [(2,0),(4,2),(2,4)]]),
    ("forca", "Força · Quatro Braços", [[(0,1),(0,0),(4,4),(4,3)], [(4,0),(0,4)]]),
    ("fantasma", "Fantasma · furtividade", [[(0,4),(0,1),(2,0),(4,1),(4,4)], [(1,4),(2,3),(3,4)]]),
    ("chave", "Chave · segurança", [[(1,0),(3,0),(3,2),(1,2),(1,0)], [(2,2),(2,4)], [(2,3),(3,3)]]),
    ("nucleo", "Núcleo · origem", [[(1,1),(3,1),(3,3),(1,3),(1,1)], [(0,0),(1,1)], [(4,0),(3,1)], [(0,4),(1,3)], [(4,4),(3,3)]]),
    ("social", "Social · tribo", [[(0,0),(0,4)], [(4,0),(4,4)], [(0,2),(4,2)]]),
    ("midia", "Mídia · imagem", [[(0,0),(4,0),(4,4),(0,4),(0,0)], [(0,3),(2,1),(4,3)]]),
    ("portal", "Portal · abrir", [[(1,4),(1,1),(2,0),(3,1),(3,4)], [(2,2),(2,4)]]),
    ("besta", "Instinto · Besta", [[(0,0),(2,2),(4,0)], [(2,2),(2,4)], [(0,4),(1,3)], [(4,4),(3,3)]]),
]

def pt(p):
    return (2 + p[0] * 5, 2 + p[1] * 5)

def build(lines):
    d, deg = [], Counter()
    for line in lines:
        pts = [pt(p) for p in line]
        d.append("M%g %g " % pts[0] + " ".join("L%g %g" % q for q in pts[1:]))
        if len(line) == 2 and line[0] == line[1]:
            continue
        closed = line[0] == line[-1]
        for i, q in enumerate(pts):
            ends = 0 if closed else (1 if i in (0, len(pts) - 1) else 0)
            deg[q] += ends + (0 if ends else 2)
    nodes = []
    for q, k in deg.items():
        if k == 1:  # ponta solta → nó
            nodes.append("M%g %g A1.6 1.6 0 1 0 %g %g A1.6 1.6 0 1 0 %g %g" % (q[0] - 1.6, q[1], q[0] + 1.6, q[1], q[0] - 1.6, q[1]))
    for line in lines:  # ponto isolado (centro) também vira nó
        if len(line) == 2 and line[0] == line[1]:
            q = pt(line[0])
            nodes.append("M%g %g A1.8 1.8 0 1 0 %g %g A1.8 1.8 0 1 0 %g %g" % (q[0] - 1.8, q[1], q[0] + 1.8, q[1], q[0] - 1.8, q[1]))
    return " ".join(d), " ".join(nodes)

out = ["// GERADO por tools/gen_galvan.py — alfabeto Galvan do Azmuth (não edite à mão).",
       "// Runas numa grade 5×5 (quadro 24×24): traços retos/diagonais, nós nas pontas soltas.",
       ".pragma library", "", "var glyphs = ["]
for gid, meaning, lines in RUNES:
    path, nodes = build(lines)
    out.append('    { id: "%s", meaning: "%s", path: "%s", nodes: "%s" },' % (gid, meaning, path, nodes))
out += ["];", "", "function byId(id) {",
        "    for (var i = 0; i < glyphs.length; i++) if (glyphs[i].id === id) return glyphs[i];",
        "    return glyphs[0];", "}", ""]
Path(__file__).resolve().parent.parent.joinpath("shell/Galvan.js").write_text("\n".join(out))
print(f"[OK] {len(RUNES)} runas")
