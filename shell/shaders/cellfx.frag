// Project Azmuth — efeitos de célula das cenas ASCII vivo, na placa de vídeo.
// Cada efeito "remapeia" células: o pixel descobre a célula da grade onde está, calcula de qual célula
// a imagem deve vir e copia o caractere dela da camada base (baseTex). Assim o redemoinho gira os
// caracteres sem entortá-los e nada disso pesa na CPU. Planetas são gerados aqui, com um atlas de glifos.
// Compilar: /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o cellfx.frag.qsb cellfx.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 grid;      // colunas, linhas
    vec4 region;    // área deste item, em células: x, y, largura, altura
    int mode;       // 0 redemoinho · 1 vento · 2 glitch · 3 varredura · 4 flutuar · 5 vulto · 6 planeta
                    // 7 estrelas · 8 chuva · 9 neve · 10 cometas · 11 faíscas · 12 bolhas · 13 chuva de letras
                    // 14 buraco negro · 15 galáxia ao fundo · 16 mapa de células (raios, rastro, órbita)
    float t;        // segundos
    float tick;     // quadro (para o ruído do vulto)
    vec4 p0;
    vec4 p1;
    vec4 p2;
    vec4 b0;
    vec4 b1;
    vec4 b2;
    vec4 b3;
    vec4 b4;
    vec4 b5;
    vec4 col1;
    vec4 col2;
};

layout(binding = 1) uniform sampler2D baseTex;
layout(binding = 2) uniform sampler2D maskTex;
layout(binding = 3) uniform sampler2D atlasTex;
layout(binding = 4) uniform sampler2D mapTex;     // mapa de células: R = glifo, G = intensidade, B = cor (+8 = brilho)

const vec3 BG = vec3(5.0 / 255.0, 6.0 / 255.0, 7.0 / 255.0);
const float GLYPHS = 72.0;   // a rampa (67) + "=/H°\\"

bool inGrid(vec2 c) { return c.x >= 0.0 && c.y >= 0.0 && c.x < grid.x && c.y < grid.y; }
vec4 cellPix(vec2 c, vec2 f) { return inGrid(c) ? texture(baseTex, (c + f) / grid) : vec4(BG, 1.0); }
bool masked(vec2 c) { return inGrid(c) && texture(maskTex, (c + 0.5) / grid).r > 0.5; }
float glyph(float idx, vec2 f) { return texture(atlasTex, vec2((idx + f.x) / GLYPHS, f.y)).a; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash1(float x) { return fract(sin(x * 91.345) * 47453.5453); }
float lumAt(vec2 c) {                    // a célula da base está apagada? (as estrelas só nascem no escuro)
    vec3 a = cellPix(c, vec2(0.3, 0.35)).rgb, b = cellPix(c, vec2(0.5, 0.55)).rgb, d = cellPix(c, vec2(0.4, 0.7)).rgb;
    return max(max(dot(a, vec3(0.3, 0.59, 0.11)), dot(b, vec3(0.3, 0.59, 0.11))), dot(d, vec3(0.3, 0.59, 0.11)));
}
// um glifo de cor `col` e transparência `a` (pré-multiplicado), somado ao que já está em o
void put(inout vec4 o, float idx, vec2 f, vec3 col, float a) {
    float g = glyph(idx, f) * a;
    o = vec4(col * g + o.rgb * (1.0 - g), g + o.a * (1.0 - g));
}
float rampIdx(float l) { return min(66.0, floor(clamp(l, 0.0, 1.0) * 66.0)); }

void band(vec4 b, vec2 c, vec2 f, inout vec4 o) {
    if (b.w > 0.5 && c.y >= b.x && c.y < b.x + b.y) {
        vec4 s = cellPix(c - vec2(b.z, 0.0), f);
        o = vec4(mix(s.rgb, col1.rgb, 0.1), 1.0);
    }
}

void main() {
    vec2 cf = region.xy + qt_TexCoord0 * region.zw;
    vec2 c = floor(cf);
    vec2 f = cf - c;
    vec4 o = vec4(0.0);

    if (mode == 0) {                         // redemoinho: p0 = cx, cy, rx, ry (fração da tela); p1 = vel, torção, usa máscara
        vec2 n = ((c + 0.5) / grid - p0.xy) / p0.zw;
        float r = length(n);
        if (r < 1.0 && !(p1.z > 0.5 && masked(c))) {
            float edge = r > 0.9 ? (1.0 - r) / 0.1 : 1.0;
            float a = (-t * p1.x - p1.y * (1.0 - r) * sin(t * 0.6) * 0.5) * edge;
            vec2 m = vec2(n.x * cos(a) - n.y * sin(a), n.x * sin(a) + n.y * cos(a));
            vec2 s = floor((p0.xy + m * p0.zw) * grid);
            o = (p1.z > 0.5 && masked(s)) ? vec4(BG, 1.0) : vec4(cellPix(s, f).rgb, 1.0);
        }
    } else if (mode == 1) {                  // vento: p1.x = amplitude
        float off = floor(p1.x * sin(t * 1.7 + c.y * 0.42) + p1.x * 0.5 * sin(t * 3.1 + c.y * 0.9) + 0.5);
        if (off != 0.0) o = vec4(cellPix(c - vec2(off, 0.0), f).rgb, 1.0);
    } else if (mode == 2) {                  // glitch: faixas b0..b5 = linha, altura, deslocamento, ativa
        band(b0, c, f, o); band(b1, c, f, o); band(b2, c, f, o);
        band(b3, c, f, o); band(b4, c, f, o); band(b5, c, f, o);
    } else if (mode == 3) {                  // varredura descendo
        float p = mod(t, 6.0) / 6.0;
        float y0 = floor((p * 1.3 - 0.15) * grid.y), hb = ceil(grid.y * 0.07);
        if (c.y >= y0 && c.y < y0 + hb) {
            vec3 b = cellPix(c, f).rgb;
            o = vec4(b * 0.55 + col1.rgb * 0.06, 0.06);           // somado (alfa ~0) = mais claro
            float ly = cf.y - (y0 + hb * 0.5);
            if (ly >= 0.0 && ly < 0.15) o = vec4(col1.rgb * 0.5, 0.5);
        }
    } else if (mode == 4) {                  // flutuar: p0.x = quantas linhas a silhueta sobe
        vec2 s = c + vec2(0.0, p0.x);
        if (s.y < grid.y && masked(s)) {
            o = vec4(cellPix(s, f).rgb, 1.0);
        } else if (masked(c)) {              // buraco onde a silhueta estava: o vizinho mais perto fora dela
            float l = 0.0, r = 0.0;
            for (int k = 1; k < 120; k++) { if (l == 0.0 && (c.x - float(k) <= 0.0 || !masked(c - vec2(float(k), 0.0)))) l = float(k);
                                             if (r == 0.0 && (c.x + float(k) >= grid.x - 1.0 || !masked(c + vec2(float(k), 0.0)))) r = float(k);
                                             if (l > 0.0 && r > 0.0) break; }
            vec2 s2 = l < r ? c - vec2(l, 0.0) : c + vec2(r, 0.0);
            o = vec4(cellPix(s2, f).rgb, 1.0);
        }
    } else if (mode == 5) {                  // vulto: p0.x = apagão; b0..b2.xy = tremidas; p2.x = glifo '.'
        if (p0.x > 0.5) {
            o = vec4(BG * 0.9, 0.9);
            if (hash(c + tick) < 0.12) o.rgb = mix(o.rgb, col1.rgb * 0.9, glyph(p2.x, f) * 0.35);
        } else {
            vec3 s = cellPix(c - b0.xy, f).rgb + cellPix(c - b1.xy, f).rgb + cellPix(c - b2.xy, f).rgb;
            o = vec4(s * 0.28, 0.0);
        }
    } else if (mode == 6) {                  // planeta: p0 = cx, cy, R (px), vel · p1 = cw, ch, faixas, terra · p2 = '.', '-', '=', anel
        vec2 px = (c + 0.5) * p1.xy;
        vec2 n = (px - p0.xy) / p0.z;
        float d = dot(n, n);
        bool ringOn = false, ringFront = false;
        if (p2.w > 0.5) {
            vec2 rv = vec2((px.x - p0.x) / (1.8 * p0.z), (px.y - p0.y) / (0.35 * p0.z));
            ringOn = abs(length(rv) - 1.0) < 0.09;
            ringFront = rv.y > 0.0;
        }
        if (d <= 1.0) {
            float z = sqrt(1.0 - d), lam = max(0.12, -0.35 * n.x - 0.3 * n.y + 0.88 * z);
            float lon = atan(n.x, z) + t * p0.w, lat = asin(clamp(n.y, -1.0, 1.0));
            float bnd = 0.5 + 0.5 * sin(lat * p1.z + sin(lon * 3.0 + lat * 2.0) * 0.8 + sin(lon * 7.0 - lat * 3.0) * 0.3);
            float l = 0.08 + 0.92 * lam * (0.55 + 0.45 * bnd);
            vec3 cc = (col1.rgb * bnd + col2.rgb * (1.0 - bnd)) * (0.35 + 0.9 * lam);
            if (p1.w > 0.5) {                // Terra: continentes, oceano, nuvens
                float nn = sin(lon * 2.1 + sin(lat * 3.3) * 1.4) * 0.55 + sin(lon * 5.3 - lat * 4.1 + 1.7) * 0.3 + sin(lat * 6.0 + lon) * 0.2;
                float cl = sin(lon * 4.0 + t * p0.w * 3.0 + lat * 9.0) * 0.5 + sin(lon * 9.0 - lat * 5.0) * 0.5;
                vec3 ground = nn > 0.18 ? (abs(lat) > 1.15 ? vec3(0.82, 0.86, 0.9) : nn > 0.55 ? vec3(0.59, 0.47, 0.27) : vec3(0.24, 0.59, 0.31)) : vec3(0.12, 0.35, 0.78);
                float veil = clamp((cl - 0.45) / 0.4, 0.0, 1.0) * 0.7;
                cc = (ground * (1.0 - veil) + 0.88 * veil) * (0.25 + 0.95 * lam);
                l = 0.1 + 0.9 * lam * ((nn > 0.18 ? 0.85 : 0.6) * (1.0 - veil) + veil * 0.9);
            }
            o = vec4(mix(BG, clamp(cc, 0.0, 1.0), glyph(rampIdx(l), f)), 1.0);
            if (ringOn && ringFront) o.rgb = mix(o.rgb, col1.rgb, glyph(p2.z, f) * 0.8);
        } else {
            float a = 0.0;
            vec3 cc = col1.rgb;
            if (d <= 1.18) a = glyph(p2.x, f) * 0.25 * (1.18 - d) / 0.18;               // atmosfera
            if (ringOn) a = max(a, glyph(ringFront ? p2.z : p2.y, f) * (ringFront ? 0.8 : 0.35));
            o = vec4(cc * a, a);
        }
    } else if (mode == 7) {                  // estrelas piscando no escuro · p1 = glifos '*', '+', '.'
        float h = hash(c * 1.37 + 3.1);
        if (h < 0.0055 && lumAt(c) < 0.18) {
            float ph = hash(c + 9.7) * 6.28, sp = 0.6 + 1.4 * hash(c + 4.2);
            float v = sin(t * sp + ph);
            if (v >= 0.2) put(o, v > 0.9 ? p1.x : v > 0.6 ? p1.y : p1.z, f, v > 0.85 ? vec3(1.0) : col1.rgb, (v - 0.2) * 1.2);
        }
    } else if (mode == 8) {                  // chuva inclinada · p1.x = glifo '/'
        float k = floor(c.x - 0.23 * c.y + 0.5);                  // "trilho" diagonal desta gota
        float s = 0.6 + 0.4 * hash1(k + 0.5);
        float along = c.y + t * 28.6 * s;                         // desce ~29 linhas/s
        float seg = floor(along / 18.0);
        if (hash(vec2(k, seg)) < 0.16 && mod(along, 18.0) < 1.0)
            put(o, p1.x, f, col1.rgb, 0.25 + s * 0.35);
    } else if (mode == 9) {                  // neve em três camadas · p1 = '*', '+', '.' · p0.x = vento
        for (int L = 0; L < 3; L++) {
            float s = 0.35 + 0.3 * float(L);
            float fall = (0.35 + 0.55 * s) * 11.0, drift = p0.x * s * 0.9 * 11.0;
            vec2 q = vec2(c.x - drift / fall * c.y, c.y);             // coluna que segue o vento
            float k = floor(q.x + 0.5 + sin(t + hash1(float(L) + 2.0) * 6.0) * 0.3);
            float along = c.y - t * fall;
            float seg = floor(along / 14.0);
            if (hash(vec2(k * 1.7 + float(L) * 31.0, seg)) < 0.13 && mod(along, 14.0) < 1.0)
                put(o, s > 0.75 ? p1.x : s > 0.45 ? p1.y : p1.z, f, col1.rgb, 0.3 + s * 0.6);
        }
    } else if (mode == 10) {                 // cometas: cabeças em b0..b5 (2 por vec4: x, y, x2, y2) · p1 = '*', '=', '-'
        vec4 bs[6] = vec4[6](b0, b1, b2, b3, b4, b5);
        for (int i = 0; i < 12; i++) {
            vec2 h = (i % 2 == 0) ? bs[i / 2].xy : bs[i / 2].zw;
            if (h.x < -500.0) continue;
            if (floor(h) == c) { put(o, p1.x, f, vec3(1.0), 1.0); continue; }
            for (int j = 1; j < 7; j++) {
                if (floor(h - float(j) * vec2(1.2, 0.45)) == c) { put(o, j < 3 ? p1.y : p1.z, f, col1.rgb, (1.0 - float(j) / 7.0) * 0.7); break; }
            }
        }
    } else if (mode == 11) {                 // faíscas · p0 = caixa (células) · p1 = glifos . , * + · p2 = jeito (0 sobe, 1 sai do centro, 2 pisca), vel, densidade, glifo '
        float sp = p2.y, dens = p2.z, T = 2.0;
        if (p2.x < 0.5) {
            for (int dk = -1; dk <= 1; dk++) for (int i = 0; i < 2; i++) {
                float k = c.x + float(dk);
                if (k < p0.x || k >= p0.x + p0.z) continue;
                float sh = hash(vec2(k, float(i) * 7.1)), cyc = floor(t / T + sh), age = fract(t / T + sh) * T;
                if (hash(vec2(k * 0.37 + cyc, float(i))) > 0.35 * dens) continue;
                float life = T * (0.4 + 0.6 * hash(vec2(k, cyc + float(i))));
                if (age >= life) continue;
                float v = (0.4 + 0.9 * hash(vec2(k + cyc, float(i) + 3.0))) * sp * 11.0;
                float y0 = p0.y + p0.w * (0.3 + 0.7 * hash(vec2(cyc, k + float(i))));
                vec2 q = vec2(k + sin(age * 3.0 + sh * 6.28) * 0.8, y0 - v * age);
                if (floor(q) == c) {
                    float hg = hash(vec2(k, cyc * 3.0)), a = min(1.0, (life - age) / 0.7);
                    float gi = hg < 0.2 ? p1.x : hg < 0.4 ? p1.y : hg < 0.6 ? p2.w : hg < 0.8 ? p1.z : p1.w;
                    put(o, gi, f, hash(vec2(k, cyc + 9.0)) < 0.15 ? vec3(1.0) : col1.rgb, a);
                }
            }
        } else if (p2.x < 1.5) {
            vec2 ctr = p0.xy + p0.zw * 0.5, dv = (c + 0.5 - ctr) * vec2(0.58, 1.0);
            float K = 90.0, ang = atan(dv.y, dv.x), b = floor((ang / 6.2832 + 0.5) * K);
            for (int db = -1; db <= 1; db++) for (int i = 0; i < 2; i++) {
                float bb = mod(b + float(db), K), sh = hash(vec2(bb, float(i) + 1.3));
                float cyc = floor(t / T + sh), age = fract(t / T + sh) * T;
                if (hash(vec2(bb * 0.71 + cyc, float(i))) > 0.3 * dens) continue;
                float life = T * (0.4 + 0.5 * hash(vec2(bb, cyc)));
                if (age >= life) continue;
                float a2 = ((bb + 0.5) / K - 0.5) * 6.2832, v = (0.8 + 1.4 * hash(vec2(cyc, bb))) * sp * 11.0;
                float rr = 0.2 * p0.w * 0.5 + v * age;
                vec2 q = ctr + vec2(cos(a2) * rr / 0.58, sin(a2) * rr);
                if (floor(q) == c) put(o, hash(vec2(bb, cyc)) < 0.5 ? p1.z : p1.w, f, col1.rgb, min(1.0, (life - age) / 0.7));
            }
        } else if (c.x >= p0.x && c.x < p0.x + p0.z && c.y >= p0.y && c.y < p0.y + p0.w) {
            float cyc = floor(t * 1.5 + hash(c + 2.0) * 3.0);
            if (hash(c + cyc * 1.31) < 0.02 * dens) { float ph = fract(t * 1.5 + hash(c));
                put(o, ph < 0.33 ? p1.w : ph < 0.66 ? p1.z : p1.x, f, col1.rgb, 1.0 - ph * 0.6); }
        }
    } else if (mode == 12) {                 // bolhas presas na caixa · p0 = caixa · p1 = glifos O, o, °
        if (c.x >= p0.x && c.x < p0.x + p0.z && c.y >= p0.y && c.y < p0.y + p0.w) {
            for (int dk = -2; dk <= 2; dk++) {
                float k = c.x + float(dk), sz = hash(vec2(k, 5.0));
                if (hash(vec2(k, 1.0)) > 0.22) continue;
                float v = (0.35 + 0.5 * sz) * 11.0, P = p0.w + 4.0;
                float y = p0.y + p0.w - mod(t * v + hash(vec2(k, 2.0)) * P, P);
                vec2 q = vec2(k + sin(t * 2.0 + hash(vec2(k, 3.0)) * 6.0) * 1.2, y);
                if (floor(q) == c) put(o, sz > 0.7 ? p1.x : sz > 0.35 ? p1.y : p1.z, f, col1.rgb, 0.35 + sz * 0.5);
            }
        }
    } else if (mode == 13) {                 // chuva de letras · p0 = caixa · p1 = passo, vel, transparência, nº de letras · b0,b1 = letras
        if (c.x >= p0.x && c.x < p0.x + p0.z && c.y >= p0.y && c.y < p0.y + p0.w && mod(c.x - p0.x, p1.x) < 0.5) {
            float k = c.x, sp = (0.5 + 0.9 * hash(vec2(k, 4.0))) * p1.y * 11.0, len = 6.0 + floor(hash(vec2(k, 6.0)) * 12.0);
            float P = p0.w + 30.0, head = p0.y - 18.0 + mod(t * sp + hash(vec2(k, 8.0)) * P, P);
            float j = floor(head) - c.y;
            if (j >= 0.0 && j < len) {
                float n = max(1.0, p1.w), ci = mod(c.y * 7.0 + k * 3.0 + (j < 0.5 ? tick : 0.0), n);
                vec4 cs = ci < 4.0 ? b0 : b1; float cm = mod(ci, 4.0);
                float gi = cm < 0.5 ? cs.x : cm < 1.5 ? cs.y : cm < 2.5 ? cs.z : cs.w;
                if (j < 0.5) put(o, gi, f, vec3(1.0), 0.85); else put(o, gi, f, col1.rgb, (1.0 - j / len) * p1.z);
            }
        }
    } else if (mode == 14) {                 // buraco negro · p0 = cx, cy, R (px), vel · p1 = cw, ch
        vec2 px = (c + 0.5) * p1.xy, d = (px - p0.xy) / p0.z;
        float r = length(d);
        vec2 e = vec2(d.x, d.y / 0.28);                                  // disco de acreção inclinado
        float re = length(e), ang = atan(e.y, e.x) - t * p0.w;
        float disk = (re > 1.35 && re < 2.7) ? (1.0 - abs(re - 1.9) / 0.8) * (0.55 + 0.45 * sin(ang * 5.0 + re * 6.0)) : 0.0;
        float lens = (d.y < 0.0 && r > 1.15 && r < 1.75) ? (1.0 - abs(r - 1.42) / 0.33) * 0.55 * (0.6 + 0.4 * sin(atan(d.y, d.x) * 7.0 - t * p0.w * 2.0)) : 0.0;
        vec3 hot = mix(col1.rgb, vec3(1.0, 0.95, 0.85), clamp(1.0 - (re - 1.35) / 0.6, 0.0, 1.0));
        if (r < 1.0) {
            o = vec4(BG * 0.4, 1.0);                                      // o horizonte: preto
            if (d.y > 0.0 && disk > 0.05) o = vec4(mix(o.rgb, hot, glyph(rampIdx(disk), f)), 1.0);   // a frente do disco passa por cima
        } else {
            float ring = r < 1.12 ? 0.9 : 0.0;                            // anel de fótons
            float l = max(max(disk, lens), ring);
            if (l > 0.05) put(o, rampIdx(l), f, ring > 0.0 ? vec3(1.0, 0.9, 0.75) : hot, min(1.0, 0.35 + l));
        }
    } else if (mode == 15) {                 // galáxia espiral ao fundo · p0 = cx, cy, R (px), vel · p1 = cw, ch, inclinação
        vec2 px = (c + 0.5) * p1.xy, d = (px - p0.xy) / p0.z;
        d.y /= max(0.2, p1.z);
        float r = length(d);
        if (r < 1.2) {
            float th = atan(d.y, d.x) - t * p0.w;
            float arms = pow(0.5 + 0.5 * cos(2.0 * th - 5.0 * log(r + 0.08)), 3.0) * exp(-r * 2.4);
            float core = exp(-r * r * 22.0), grain = 0.55 + 0.45 * hash(c + floor(t * 0.5));
            float l = (arms * 1.4 + core) * grain;
            if (l > 0.07) put(o, rampIdx(min(1.0, l)), f, mix(col1.rgb, vec3(1.0, 0.97, 0.9), clamp(core * 1.5, 0.0, 1.0)), min(0.85, 0.25 + l));
        }
    } else if (mode == 16) {                 // mapa de células · paleta: b0..b5 e p2 (7 cores rgb), 7 = branco
        vec4 pal[7] = vec4[7](b0, b1, b2, b3, b4, b5, p2);
        // halo: cada célula com brilho (raio) ilumina as vizinhas, caindo com a distância ao centro dela
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                vec2 nc = c + vec2(float(dx), float(dy));
                if (!inGrid(nc)) continue;
                vec4 N = texture(mapTex, (nc + 0.5) / grid);
                float nb = floor(N.b * 255.0 + 0.5);
                if (N.a > 0.5 && nb > 7.5) {
                    float sl = nb - 8.0;
                    vec3 hc = sl > 6.5 ? vec3(1.0) : pal[int(sl)].rgb;
                    vec2 dd = (cf - (nc + 0.5)) * vec2(0.58, 1.0);
                    float h = exp(-dot(dd, dd) * 5.5) * 0.30 * N.g;          // morre antes da borda da vizinhança 3×3 (sem quadrado)
                    o += vec4(hc * h, h);
                }
            }
        }
        vec4 T = texture(mapTex, (c + 0.5) / grid);
        if (T.a > 0.5) {
            float bi = floor(T.b * 255.0 + 0.5), gl = step(7.5, bi), sl = bi - gl * 8.0;
            vec3 col = sl > 6.5 ? vec3(1.0) : pal[int(sl)].rgb;
            if (gl > 0.5) col = mix(col, vec3(1.0), 0.45);                 // raio: núcleo mais claro que o halo
            put(o, floor(T.r * 255.0 + 0.5), f, col, T.g);
        }
    }
    fragColor = o * qt_Opacity;
}
