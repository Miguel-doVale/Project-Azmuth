.pragma library
// Project Azmuth — efeitos das cenas ASCII vivo (porte da prévia tools/ascii_gallery.html).
// Nada aqui desenha animação num Canvas 2D (custava de 22 a 50 pontos de CPU por efeito): a CPU só decide
// o que acontece e a placa de vídeo desenha (shell/shaders/cellfx.frag):
//   · efeitos de célula, planetas, partículas: parâmetros por quadro (glitchBands, vultoStep, cometHeads…);
//   · raios, rastro e órbita: mapa de células (cellMapFrame), um pixel por célula, só fillRect;
//   · base e brilhos (pulso/aura): pintados uma vez.
// Estado por cena (st): { S, L, C, W, H, cw, ch, mono, dna:[r,g,b], tick, parts:{}, cache:{} }

const RAMP = " .'`^,:;Il!i><~+_-?][}{1)(|tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B@$";
const B36 = "0123456789abcdefghijklmnopqrstuvwxyz";
const BG = "#050607";
const GLOW = ["pulso", "aura"];
// feitos na placa de vídeo (shell/shaders/cellfx.frag) e o letreiro (texto do QML): o Canvas pula
const GPU = ["redemoinho", "vento", "glitch", "scan", "flutuar", "vulto", "planeta", "estrelas", "chuva", "neve", "cometas",
             "faiscas", "bolhas", "matrix", "buraconegro", "galaxia"];
// raios, rastro e órbita: a CPU decide QUAIS células têm qual glifo (mapa de células) e a placa de vídeo desenha
const MAP = ["raios", "rastro", "orbita"];
var MODE = { redemoinho: 0, vento: 1, glitch: 2, scan: 3, flutuar: 4, vulto: 5, planeta: 6, estrelas: 7, chuva: 8, neve: 9, cometas: 10,
             faiscas: 11, bolhas: 12, matrix: 13, buraconegro: 14, galaxia: 15, mapa: 16 };
// glifos no atlas (paintAtlas): índice na rampa; "=" e "/" vêm depois dela
const EXTRA = "=/H°\\";
var GLYPH = { dot: 1, apos: 2, comma: 5, plus: 15, dash: 17, bigO: 45, smallO: 56, star: 57, eq: 67, slash: 68, deg: 70 };

// ── estado corrente (ligado a cada chamada)
let st = null, S = null, L = null, C = null, W = 0, H = 0, cw = 1, ch = 1, mono = false, dna = [56, 189, 248], g = null;
function bind(s, ctx) { st = s; S = s.S; L = s.L; C = s.C; W = s.W; H = s.H; cw = s.cw; ch = s.ch; mono = s.mono; dna = s.dna; g = ctx; }

// ── utilidades
function hex(h) { h = String(h || "#ffffff"); return [parseInt(h.substr(1, 2), 16), parseInt(h.substr(3, 2), 16), parseInt(h.substr(5, 2), 16)]; }
function rgba(c, a) { return "rgba(" + (c[0] | 0) + "," + (c[1] | 0) + "," + (c[2] | 0) + "," + a + ")"; }
function put(c, x, y) { g.fillText(c, x * cw, y * ch); }
function rnd(a, b) { return a + Math.random() * (b - a); }
function charFor(l) { return RAMP[Math.min(RAMP.length - 1, Math.floor(l * (RAMP.length - 1)))]; }
function font(px) { return "bold " + Math.max(4, px).toFixed(1) + "px \"JetBrainsMono Nerd Font Mono\""; }
function cellColor(i, l) {
    if (mono) return "rgba(230,236,245," + (.25 + l * .75) + ")";
    const r = C[i * 3], gg = C[i * 3 + 1], b = C[i * 3 + 2], k = Math.max(1.15, 110 / Math.max(r, gg, b, 1));
    return "rgb(" + (Math.min(255, r * k) | 0) + "," + (Math.min(255, gg * k) | 0) + "," + (Math.min(255, b * k) | 0) + ")";
}
function effColor(e) { return mono || !e.color || e.color === "foto" || e.color === "dna" ? dna : hex(e.color); }
function boxCells(e) { if (e.box) return [e.box[0] * S.cols, e.box[1] * S.rows, (e.box[2] - e.box[0]) * S.cols, (e.box[3] - e.box[1]) * S.rows]; return S.box; }
function hsv(i) {
    const r = C[i * 3] / 255, gg = C[i * 3 + 1] / 255, b = C[i * 3 + 2] / 255, mx = Math.max(r, gg, b), mn = Math.min(r, gg, b), d = mx - mn;
    let h = 0; if (d) h = mx === r ? ((gg - b) / d) % 6 : mx === gg ? (b - r) / d + 2 : (r - gg) / d + 4;
    return [(h * 60 + 360) % 360, mx ? d / mx : 0, mx];
}
function parts(k, init) { if (!(k in st.parts)) st.parts[k] = init(); return st.parts[k]; }

// ── cena
function decode(scene) {
    const n = scene.cols * scene.rows, Lr = new Float32Array(n), Cr = new Uint8Array(n * 3);
    for (let y = 0; y < scene.rows; y++) {
        const ls = scene.lum[y], cs = scene.col[y];
        for (let x = 0; x < scene.cols; x++) {
            const i = y * scene.cols + x;
            Lr[i] = B36.indexOf(ls[x]) / 35;
            Cr[i * 3] = parseInt(cs.substr(x * 6, 2), 16); Cr[i * 3 + 1] = parseInt(cs.substr(x * 6 + 2, 2), 16); Cr[i * 3 + 2] = parseInt(cs.substr(x * 6 + 4, 2), 16);
        }
    }
    return { L: Lr, C: Cr };
}
function makeState(scene, decoded, W_, H_, mono_, dnaHex) {
    return { S: scene, L: decoded.L, C: decoded.C, W: W_, H: H_, cw: W_ / scene.cols, ch: H_ / scene.rows,
             mono: !!mono_, dna: hex(dnaHex), tick: 0, parts: {}, cache: {}, burst: 0 };
}

// camada base: desenhada uma vez
function paintBase(s, ctx) {
    bind(s, ctx);
    ctx.fillStyle = BG; ctx.fillRect(0, 0, W, H);
    ctx.font = font(ch * .95); ctx.textBaseline = "top";
    for (let y = 0; y < S.rows; y++) for (let x = 0; x < S.cols; x++) {
        const i = y * S.cols + x, l = L[i]; if (l < .04) continue;
        ctx.fillStyle = cellColor(i, l); ctx.fillText(charFor(l), x * cw, y * ch);
    }
}

// brilho (pulso/aura): as células escolhidas, desenhadas uma vez num Canvas próprio (a shell desfoca e pisca)
function glowCells(s, e) {
    bind(s, null);
    const out = [];
    for (let y = 0; y < S.rows; y++) for (let x = 0; x < S.cols; x++) {
        const i = y * S.cols + x; let ok = false;
        if (e.type === "pulso") {
            if (L[i] >= .1) { const q = hsv(i);
                if (e.white) ok = q[1] < .25 && q[2] > .78;
                else { let dh = Math.abs(q[0] - e.hue); dh = Math.min(dh, 360 - dh);
                       ok = q[1] > (e.minS !== undefined ? e.minS : .3) && q[2] > (e.minV !== undefined ? e.minV : .3) && dh < e.range; } }
        } else if (e.type === "aura") {
            ok = L[i] >= .3 && x > 0 && y > 0 && x < S.cols - 1 && y < S.rows - 1 &&
                 (L[i - 1] < .1 || L[i + 1] < .1 || L[i - S.cols] < .1 || L[i + S.cols] < .1);
        }
        if (ok) out.push(i);
    }
    return out;
}
function paintGlow(s, ctx, e, cells) {
    bind(s, ctx);
    ctx.clearRect(0, 0, W, H); ctx.font = font(ch * .95); ctx.textBaseline = "top";
    const own = e.color === "foto" && !mono, col = rgba(effColor(e), 1);
    for (const i of cells) { ctx.fillStyle = own ? cellColor(i, 1) : col; put(charFor(Math.max(L[i], .45)), i % S.cols, (i / S.cols) | 0); }
}

// ── máscara (silhueta que não gira / que flutua)
function maskOf(e, k) {
    const key = "mask" + k + ":" + S.cols; if (st.cache[key]) return st.cache[key];
    const M = new Uint8Array(S.cols * S.rows);
    if (e.poly) {
        const P = e.poly.map(function (q) { return [q[0] * S.cols, q[1] * S.rows]; });
        for (let y = 0; y < S.rows; y++) for (let x = 0; x < S.cols; x++) {
            let ins = false;
            for (let a = 0, b = P.length - 1; a < P.length; b = a++) {
                const xa = P[a][0], ya = P[a][1], xb = P[b][0], yb = P[b][1];
                if ((ya > y) !== (yb > y) && x < (xb - xa) * (y - ya) / (yb - ya) + xa) ins = !ins;
            }
            if (ins) M[y * S.cols + x] = 1;
        }
    }
    if (e.flood) {
        const f = e.flood, bx = f.box.map(function (v, j) { return v * (j % 2 ? S.rows : S.cols); });
        const ok = function (i) { const x = i % S.cols, y = (i / S.cols) | 0; if (x < bx[0] || x > bx[2] || y < bx[1] || y > bx[3]) return false;
            if (L[i] < (f.dark !== undefined ? f.dark : .16)) return true; const q = hsv(i); return f.white && q[1] < .22 && q[2] > .55; };
        const stack = [Math.round(f.seed[1] * S.rows) * S.cols + Math.round(f.seed[0] * S.cols)];
        while (stack.length) { const i = stack.pop(); if (i < 0 || i >= M.length || M[i] || !ok(i)) continue; M[i] = 1; stack.push(i - 1, i + 1, i - S.cols, i + S.cols); }
    }
    return (st.cache[key] = M);
}
// ── apoio aos efeitos da placa de vídeo (a shell lê isto a cada quadro)
function isMap(type) { return MAP.indexOf(type) >= 0; }
function isGpu(type) { return GPU.indexOf(type) >= 0; }
// faixas do glitch: [linha, altura, deslocamento, ativa] (até 6); a troca do carrossel soma faixas largas
function glitchBands(s, k, e) {
    bind(s, null);
    const list = parts(k, function () { return []; }), out = [];
    if (e && Math.random() < .1) list.push({ y: rnd(0, S.rows) | 0, h: 1 + (rnd(0, 4) | 0), dx: Math.round(rnd(-.5, .5) * S.cols * .03), life: 2 + (rnd(0, 2) | 0) });
    for (let i = list.length - 1; i >= 0; i--) { const q = list[i]; if (q.life-- <= 0) { list.splice(i, 1); continue; } out.push([q.y, q.h, q.dx, 1]); }
    if (s.burst > 0) { s.burst--; for (let q = 0; q < 4; q++) out.unshift([rnd(0, S.rows) | 0, 1 + (rnd(0, 5) | 0), Math.round(rnd(-.5, .5) * S.cols * .12), 1]); }
    while (out.length < 6) out.push([0, 0, 0, 0]);
    return out.slice(0, 6);
}
// cometas: até 12 cabeças [x, y] em células (o shader desenha cabeça e rastro)
function cometHeads(s, k, e) {
    bind(s, null);
    const list = parts(k, function () { return []; }), sp = e.speed || 1, rate = .5 * (e.dens || 2.5) / 2.5;
    if (list.length < 12 && Math.random() < rate) list.push({ x: rnd(-20, S.cols * .6), y: rnd(-10, S.rows * .3), life: 26 });
    for (let i = list.length - 1; i >= 0; i--) { const q = list[i]; q.x += 3.2 * sp; q.y += 1.2 * sp; if (--q.life <= 0) list.splice(i, 1); }
    const out = list.map(function (q) { return [q.x, q.y]; });
    while (out.length < 12) out.push([-1000, -1000]);
    return out;
}
// vulto: apagão por alguns quadros ou três cópias tremidas
function vultoStep(s, k) {
    bind(s, null);
    const v = parts(k, function () { return { face: 0 }; });
    if (v.face > 0 || Math.random() < .07) { if (v.face <= 0) v.face = 2 + (Math.random() * 4 | 0); v.face--; return { blackout: true, off: [[0, 0], [0, 0], [0, 0]] }; }
    const off = []; for (let j = 0; j < 3; j++) off.push([Math.round((Math.random() - .5) * 6), Math.round((Math.random() - .5) * 1.2)]);
    return { blackout: false, off: off };
}
// área (em células) que um efeito de placa de vídeo ocupa
function gpuRegion(s, e) {
    const S_ = s.S, cols = S_.cols, rows = S_.rows;
    const clampR = function (x0, y0, x1, y1) { x0 = Math.max(0, Math.floor(x0)); y0 = Math.max(0, Math.floor(y0));
        x1 = Math.min(cols, Math.ceil(x1)); y1 = Math.min(rows, Math.ceil(y1)); return [x0, y0, Math.max(1, x1 - x0), Math.max(1, y1 - y0)]; };
    if (e.type === "redemoinho") return clampR((e.cx - e.rx) * cols, (e.cy - e.ry) * rows, (e.cx + e.rx) * cols, (e.cy + e.ry) * rows);
    if (e.type === "planeta") { const R = e.r * s.H, ex = (e.ring ? 1.85 : 1.1) * R, ey = 1.1 * R;
        return clampR((e.cx * s.W - ex) / s.cw, (e.cy * s.H - ey) / s.ch, (e.cx * s.W + ex) / s.cw, (e.cy * s.H + ey) / s.ch); }
    if (e.type === "flutuar") { let f; if (e.flood) f = e.flood.box;
        else { const xs = e.poly.map(function (q) { return q[0]; }), ys = e.poly.map(function (q) { return q[1]; });
               f = [Math.min.apply(null, xs), Math.min.apply(null, ys), Math.max.apply(null, xs), Math.max.apply(null, ys)]; }
        return clampR(f[0] * cols, f[1] * rows - 4, f[2] * cols, f[3] * rows + 1); }
    if (e.type === "vento" || e.type === "vulto" || e.type === "bolhas" || e.type === "matrix" || (e.type === "faiscas" && e.dir === "twinkle")) {
        bind(s, null); const b = boxCells(e); return clampR(b[0] - (e.type === "bolhas" ? 2 : 0), b[1], b[0] + b[2] + (e.type === "bolhas" ? 2 : 0), b[1] + b[3]); }
    if (e.type === "faiscas" && (e.dir || "up") === "up") { bind(s, null); const b = boxCells(e); return clampR(b[0] - 2, b[1] - 32, b[0] + b[2] + 2, b[1] + b[3]); }
    if (e.type === "buraconegro" || e.type === "galaxia") { const R = e.r * s.H, ex = (e.type === "buraconegro" ? 2.8 : 1.25) * R,
        ey = (e.type === "buraconegro" ? 1.8 : 1.25 * (e.tilt || .45)) * R;
        return clampR((e.cx * s.W - ex) / s.cw, (e.cy * s.H - ey) / s.ch, (e.cx * s.W + ex) / s.cw, (e.cy * s.H + ey) / s.ch); }
    return [0, 0, cols, rows];                               // glitch, varredura
}
function maskCells(s, e, k) { bind(s, null); return maskOf(e, "g" + k); }
// atlas de glifos para o shader: a rampa + "=" + "/" (brancos, uma célula cada)
function paintAtlas(ctx, cwPx, chPx) {
    ctx.clearRect(0, 0, cwPx * (RAMP.length + EXTRA.length), chPx);
    ctx.font = font(chPx * .95); ctx.textBaseline = "top"; ctx.fillStyle = "#ffffff";
    const all = RAMP + EXTRA;
    for (let i = 0; i < all.length; i++) ctx.fillText(all[i], i * cwPx, 0);
}
function glyphCount() { return RAMP.length + EXTRA.length; }
function glyphIndex(c) { const i = (RAMP + EXTRA).indexOf(c); return i < 0 ? GLYPH.star : i; }
function boxOf(s, e) { bind(s, null); return boxCells(e); }
// letras da chuva de letras: até 8 diferentes, como índices do atlas
function matrixGlyphs(e) { const seen = []; for (const c of (e.chars || "01<>{}[]/=+*")) if (seen.indexOf(c) < 0 && seen.length < 8) seen.push(c);
    const idx = seen.map(glyphIndex); while (idx.length < 8) idx.push(idx[0]); return { idx: idx, n: seen.length }; }
function types() { return GPU.concat(MAP, GLOW, ["letreiro"]); }

// ── mapa de células: raios, rastro e órbita ──
// Um Canvas minúsculo (1 pixel por célula da grade, só fillRect) guarda, por célula: R = glifo no atlas,
// G = intensidade, B = cor (0..6 = paleta do efeito, 7 = branco; +8 = com brilho). O shader (modo 16) lê isso,
// desenha o glifo e o halo dos vizinhos com brilho. Alfa sempre 255: nada de premultiplicação estragando dados.
function mapPalette(s, on) {
    bind(s, null);
    const eff = S.effects || [], slots = {}, colors = [];
    for (let k = 0; k < eff.length; k++) if (on[k] && isMap(eff[k].type)) {
        slots[k] = Math.min(6, colors.length); if (colors.length < 7) colors.push(effColor(eff[k]));
    }
    while (colors.length < 7) colors.push([1, 1, 1]);
    return { slots: slots, colors: colors.map(function (c) { return [c[0] / 255, c[1] / 255, c[2] / 255]; }) };
}
function mapPlot(ctx, x, y, glyph, a, slot, glow) {
    x = Math.round(x); y = Math.round(y);
    if (x < 0 || y < 0 || x >= S.cols || y >= S.rows) return false;     // fora da grade: some (sem dar a volta na linha)
    ctx.fillStyle = "rgb(" + glyph + "," + Math.max(0, Math.min(255, Math.round(a * 255))) + "," + (slot + (glow ? 8 : 0)) + ")";
    ctx.fillRect(x, y, 1, 1);
    return true;
}
// desenha um quadro do mapa. front = só a metade da frente das órbitas (camada acima do Omnitrix). Devolve quantas células.
function cellMapFrame(s, on, t, front, ctx) {
    bind(s, null);
    const eff = S.effects || [], pal = mapPalette(s, on), G = GLYPH, white = 7;
    let n = 0;
    ctx.clearRect(0, 0, S.cols, S.rows);
    if (!front) s.tick++;
    for (let k = 0; k < eff.length; k++) {
        const e = eff[k]; if (!on[k] || !isMap(e.type)) continue;
        const slot = pal.slots[k];
        if (e.type === "orbita") {
            const cnt = e.n || 60;
            for (let i = 0; i < cnt; i++) {
                const a = t * .5 + i * 6.283 / cnt + Math.sin(i * 7.3) * .2, z = Math.sin(a);
                if (front ? z < 0 : z >= 0) continue;
                const f = front ? 1 : .45;
                if (mapPlot(ctx, (e.cx * W + Math.cos(a) * e.rx * H) / cw - .5, (e.cy * H + z * e.ry * H) / ch - .5, front ? G.star : G.dot, f, i % 9 ? slot : white, false)) n++;
                for (let j = 1; j < 4; j++) { const b = a - j * .035;
                    if (mapPlot(ctx, (e.cx * W + Math.cos(b) * e.rx * H) / cw - .5, (e.cy * H + Math.sin(b) * e.ry * H) / ch - .5, G.dash, f * (1 - j / 4) * .6, slot, false)) n++; }
            }
        } else if (!front && e.type === "raios") {
            const list = parts(k, function () { return []; }), b = boxCells(e), rate = e.rate !== undefined ? e.rate : .85;
            const spawn = function () { const pts = []; let x = b[0] + b[2] * rnd(.1, .9), y = b[1] + b[3] * rnd(.1, .9); const dx = Math.random() < .5 ? -1 : 1, steps = rnd(10, 28);
                for (let i = 0; i < steps; i++) { pts.push([Math.round(x), Math.round(y)]); x += dx * rnd(1, 3); y += rnd(-1, 1.2);
                    if (Math.random() < .12) { let gx = x, gy = y; for (let j = 0; j < 5; j++) { gx += dx * 1.5; gy += rnd(-.6, 1.4); pts.push([Math.round(gx), Math.round(gy)]); } } }
                list.push({ pts: pts, life: rnd(2, 6) | 0 }); };
            if (Math.random() < rate) spawn(); if (Math.random() < rate * .45) spawn();
            for (let i = list.length - 1; i >= 0; i--) if (list[i].life-- <= 0) list.splice(i, 1);
            for (const bolt of list) for (let i = 0; i < bolt.pts.length; i++) { const p = bolt.pts[i], nx = bolt.pts[i + 1];
                const glyph = !nx ? G.star : nx[1] < p[1] ? G.slash : nx[1] > p[1] ? glyphIndex("\\") : G.dash;
                if (mapPlot(ctx, p[0], p[1], glyph, 1, Math.random() < .25 ? white : slot, true)) n++; }
        } else if (!front && e.type === "rastro") {
            const b = boxCells(e), left = (e.dir || "left") === "left";
            for (let y = Math.floor(b[1]); y < b[1] + b[3] && y < S.rows; y++) { if ((y + s.tick) % 3) continue; let edge = -1;
                if (left) { for (let x = Math.floor(b[0]); x < b[0] + b[2]; x++) if (L[y * S.cols + x] > .35) { edge = x; break; } }
                else { for (let x = Math.floor(b[0] + b[2]) - 1; x >= b[0]; x--) if (L[y * S.cols + x] > .35) { edge = x; break; } }
                if (edge < 0) continue;
                const len = 6 + ((y * 7 + s.tick * 3) % 20), dir = left ? -1 : 1;
                for (let j = 1; j <= len; j++) if (mapPlot(ctx, edge + dir * (j + (s.tick * 2) % 4), y, j % 4 ? G.dash : G.eq, (1 - j / len) * .6, slot, false)) n++; }
        }
    }
    return n;
}
// que parte da grade o mapa ocupa, em células [x, y, largura, altura]; null = nenhum efeito do mapa ligado
function mapRegion(s, on, front) {
    bind(s, null);
    const eff = S.effects || [];
    let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
    const add = function (a, b, c, d) { x0 = Math.min(x0, a); y0 = Math.min(y0, b); x1 = Math.max(x1, c); y1 = Math.max(y1, d); };
    for (let k = 0; k < eff.length; k++) {
        const e = eff[k]; if (!on[k] || !isMap(e.type) || (front && e.type !== "orbita")) continue;
        if (e.type === "orbita") { const rx = e.rx * H / cw, ry = e.ry * H / ch, cx = e.cx * W / cw, cy = e.cy * H / ch; add(cx - rx - 4, cy - ry - 3, cx + rx + 4, cy + ry + 3); continue; }
        const b = boxCells(e);
        if (e.type === "raios") add(b[0] - 90, b[1] - 30, b[0] + b[2] + 90, b[1] + b[3] + 30); else add(b[0] - 32, b[1], b[0] + b[2] + 32, b[1] + b[3]);
    }
    if (x1 < x0) return null;
    x0 = Math.max(0, Math.floor(x0)); y0 = Math.max(0, Math.floor(y0)); x1 = Math.min(S.cols, Math.ceil(x1)); y1 = Math.min(S.rows, Math.ceil(y1));
    return [x0, y0, Math.max(1, x1 - x0), Math.max(1, y1 - y0)];
}
