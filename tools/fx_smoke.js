// Teste rápido do shell/AsciiFx.js fora da shell: cada efeito das cenas faz sentido, sem exceção.
// Efeitos de mapa (raios, rastro, órbita): desenham > 0 células e TODAS dentro da grade.
// Efeitos da placa de vídeo: a região é válida e o apoio da CPU (glitch, vulto, cometas, máscaras) funciona.
// node tools/fx_smoke.js [ids…]   (padrão: as cenas que cobrem todos os tipos de efeito)
const fs = require("fs"), path = require("path"), os = require("os");
const src = fs.readFileSync(path.join(__dirname, "../shell/AsciiFx.js"), "utf8").replace(/^\.pragma library\s*/, "");
const Fx = new Function(src + "\nreturn { decode, makeState, paintBase, glowCells, paintGlow, types, isGpu, isMap, glitchBands, vultoStep, gpuRegion, mapRegion, mapPalette, cellMapFrame, maskCells, cometHeads };")();
const dir = process.env.AZMUTH_SCENES || path.join(os.homedir(), ".local/share/azmuth/scenes");
const ids = process.argv.slice(2).length ? process.argv.slice(2) :
  ["portal-verde", "alienx-galaxia", "be-invincible", "flash-zoom", "him", "mark-costas", "xlr8-tanque", "heatblast-chuva",
   "bigchill-neve", "alien-cromado", "alienx-anel", "alienx-faces", "invencivel-multidao", "lanterna-martelo", "poster-i"];
function fakeCtx(cols, rows) {   // grava as células pintadas (fillRect 1×1) e acusa as que caem fora da grade
  const c = { n: 0, out: 0, cells: [], fillStyle: "", fillText() { c.n++; }, clearRect() { c.cells = []; },
    fillRect(x, y, w, h) { c.n++; c.cells.push([x, y, c.fillStyle]); if (x < 0 || y < 0 || x >= cols || y >= rows || w !== 1 || h !== 1) c.out++; } };
  return c;
}
let fail = 0; const seen = new Set();
for (const id of ids) {
  const scene = JSON.parse(fs.readFileSync(path.join(dir, id, "scene.json"), "utf8"));
  const st = Fx.makeState(scene, Fx.decode(scene), 1920, 1080, scene.mono, "#4ade80");
  const base = { n: 0, fillStyle: "", fillRect() {}, fillText() { base.n++; } }; Fx.paintBase(st, base);
  if (!base.n) { console.log(`FAIL ${id}: base vazia`); fail++; }
  scene.effects.forEach((e, k) => {
    seen.add(e.type);
    const on = scene.effects.map((_, j) => j === k);
    try {
      let n = 0, note = "";
      if (e.type === "pulso" || e.type === "aura") { const cells = Fx.glowCells(st, e); const c = { n: 0, fillStyle: "", clearRect() {}, fillText() { c.n++; } }; Fx.paintGlow(st, c, e, cells); n = c.n; }
      else if (e.type === "letreiro") n = e.lines.length;
      else if (Fx.isMap(e.type)) {
        const reg = Fx.mapRegion(st, on, false), pal = Fx.mapPalette(st, on);
        if (!reg || reg[2] <= 0 || reg[3] <= 0 || reg[0] < 0 || reg[1] < 0 || reg[0] + reg[2] > scene.cols || reg[1] + reg[3] > scene.rows) { console.log(`FAIL ${id} ${e.type}: região inválida ${reg}`); fail++; }
        if (pal.slots[k] === undefined || pal.colors.length !== 7) { console.log(`FAIL ${id} ${e.type}: paleta`); fail++; }
        let outside = 0;
        for (const front of (e.type === "orbita" ? [false, true] : [false])) {
          for (let f = 0; f < 12; f++) { const c = fakeCtx(scene.cols, scene.rows); n += Fx.cellMapFrame(st, on, f * .09 + 1, front, c); outside += c.out;
            for (const cell of c.cells) { const m = /^rgb\((\d+),(\d+),(\d+)\)$/.exec(cell[2]); if (!m || +m[1] > 71 || +m[2] > 255 || +m[3] > 15) { outside++; break; } } }
        }
        if (outside) { console.log(`FAIL ${id} ${e.type}: ${outside} célula(s) fora da grade ou com valor inválido`); fail++; }
        note = "células";
      }
      else if (Fx.isGpu(e.type)) {   // na placa de vídeo: confere a área e o apoio da CPU
        const r = Fx.gpuRegion(st, e); n = r[2] * r[3];
        if (e.type === "glitch") { let b = 0; for (let f = 0; f < 80; f++) b += Fx.glitchBands(st, k, e).filter(q => q[3]).length; n = n && b; }
        if (e.type === "vulto") Fx.vultoStep(st, k);
        if (e.type === "cometas") { let c = 0; for (let f = 0; f < 40; f++) c += Fx.cometHeads(st, k, e).filter(q => q[0] > -500).length; n = n && c; }
        if ((e.poly || e.flood) && !Fx.maskCells(st, e, k).some(v => v)) n = 0;
      }
      const ok = n > 0;
      console.log(`${ok ? "ok  " : "FAIL"} ${id.padEnd(22)} ${e.type.padEnd(11)} ${n} ${note}`);
      if (!ok) fail++;
    } catch (err) { console.log(`FAIL ${id} ${e.type}: ${err.stack.split("\n").slice(0, 2).join(" ")}`); fail++; }
  });
}
const missing = Fx.types().filter(t => !seen.has(t));
if (missing.length) console.log("tipos sem cena no teste:", missing.join(", "));
console.log(fail ? `${fail} FALHA(S)` : "TUDO OK");
process.exit(fail ? 1 : 0);
