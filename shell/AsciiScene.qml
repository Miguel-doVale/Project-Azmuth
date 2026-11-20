// Project Azmuth — cena ASCII vivo no fundo da área de trabalho (galeria da Central, `azmuth fundo`).
// A grade da cena (~/.local/share/azmuth/scenes/<id>/scene.json, gerada por tools/ascii_scene.py) é
// desenhada uma vez no Canvas base. Por cima, em camadas:
//   · efeitos de célula (redemoinho, vento, glitch, varredura, flutuar, vulto) na placa de vídeo
//     (shaders/cellfx.frag): copiam caracteres da base, sem custo de CPU;
//   · raios, rastro e órbita: um mapa de células (Canvas de 1 pixel por célula) que o shader desenha, com halo;
//   · planetas gerados (shader, com atlas de glifos) — estrelas e cometas passam por trás deles;
//   · letreiro (texto) e brilhos (pulso/aura: halo calculado uma vez, piscando por transparência).
// A metade da frente das órbitas passa na frente do Omnitrix: essa camada é reparentada para `frontHost`
// (um Item da LiveDesktop acima do símbolo).
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "AsciiFx.js" as Fx

Item {
    id: sc
    property string sceneId: ""
    property string scenesDir: ""
    property color dna: "#38bdf8"
    property bool animate: true
    property var effectsOn: null          // lista de liga/desliga salva (null = padrão da cena)
    property var monoPref: null           // true = branco + cor do DNA, false = cores da foto, null = padrão da cena
    property int every: 0                 // carrossel: segundos entre trocas (0 = padrão da cena)
    property Item frontHost: null         // onde a metade da frente das órbitas é pendurada (acima do Omnitrix)

    readonly property bool ready: st !== null
    signal failed()
    signal stepped()                      // todo quadro (efeitos da placa de vídeo atualizam)

    // ── carregamento
    property var carousel: null           // ids do carrossel (null = cena simples)
    property int carIndex: 0
    property int carEvery: 6
    property var carBad: ({})
    property string fileId: ""
    property var scene: null
    property var decoded: null
    property var st: null
    property real t0: Date.now()
    property real switchedAt: 0
    property bool gaveUp: false

    onSceneIdChanged: restart()
    onScenesDirChanged: restart()
    Component.onCompleted: restart()

    function restart() {
        carousel = null; carIndex = 0; carBad = ({}); scene = null; decoded = null; st = null; gaveUp = false
        fileId = sceneId && sceneId !== "circuitos" ? sceneId : ""
    }
    function fail() { if (!gaveUp) { gaveUp = true; st = null; sc.failed() } }

    FileView {
        id: file
        path: sc.fileId && sc.scenesDir ? sc.scenesDir + "/" + sc.fileId + "/scene.json" : ""
        onLoaded: sc.loaded(text())
        onLoadFailed: sc.loadError()
    }
    function loadError() {
        if (carousel) { carBad[fileId] = true; nextInCarousel(); return }
        fail()
    }
    function validGrid(o) {
        if (!o || typeof o !== "object" || !o.cols || !o.rows) return false
        if (!Array.isArray(o.lum) || !Array.isArray(o.col) || o.lum.length !== o.rows || o.col.length !== o.rows) return false
        for (let y = 0; y < o.rows; y++)
            if (typeof o.lum[y] !== "string" || o.lum[y].length !== o.cols || typeof o.col[y] !== "string" || o.col[y].length !== o.cols * 6) return false
        return true
    }
    function loaded(txt) {
        try { loadedUnsafe(txt) } catch (e) { console.warn("cena ASCII com defeito:", fileId, e); loadError() }
    }
    function loadedUnsafe(txt) {
        let obj
        try { obj = JSON.parse(txt) } catch (e) { console.warn("cena ASCII ilegível:", fileId); return loadError() }
        if (!obj || typeof obj !== "object") return loadError()
        if (Array.isArray(obj.carousel)) {                         // cena carrossel: passa a carregar a 1ª
            if (!obj.carousel.length) return fail()
            carousel = obj.carousel; carEvery = obj.every || 6; carIndex = 0
            fileId = carousel[0]
            return
        }
        if (!validGrid(obj)) { console.warn("cena ASCII com grade inválida:", fileId); return loadError() }
        const burst = !!carousel && st !== null
        scene = obj; decoded = Fx.decode(obj)
        rebuild(burst)
        switchedAt = Date.now()
    }
    function nextInCarousel() {
        if (!carousel) return
        for (let n = 1; n <= carousel.length; n++) {
            const i = (carIndex + n) % carousel.length
            // só um pôster válido: nada a trocar (antes relia e redesenhava o mesmo a cada período)
            if (!carBad[carousel[i]]) { carIndex = i; if (fileId !== carousel[i]) fileId = carousel[i]; return }
        }
        fail()                                                     // nenhuma cena do carrossel existe
    }

    // ── estado de desenho (refeito quando muda cena, tamanho, cor do DNA ou modo de cor)
    readonly property bool mono: scene ? (monoPref === null || monoPref === undefined ? !!scene.mono : !!monoPref) : false
    readonly property var effects: scene ? (scene.effects || []) : []
    readonly property var on: effects.map((e, k) => !carousel && effectsOn && effectsOn[k] !== undefined ? !!effectsOn[k] : e.on !== false)
    function idxWhere(test) { const out = []; for (let k = 0; k < effects.length; k++) if (on[k] && test(effects[k].type)) out.push(k); return out }
    readonly property var glowIdx: idxWhere(t => t === "pulso" || t === "aura")
    readonly property var remapIdx: idxWhere(t => Fx.isGpu(t) && t !== "planeta" && t !== "buraconegro" && t !== "galaxia")
    readonly property var planetIdx: idxWhere(t => t === "planeta" || t === "buraconegro" || t === "galaxia")
    readonly property var textIdx: idxWhere(t => t === "letreiro")
    readonly property bool hasMap: idxWhere(t => Fx.isMap(t)).length > 0
    readonly property bool hasFront: idxWhere(t => t === "orbita").length > 0
    readonly property bool hasMotion: hasMap || remapIdx.length > 0 || planetIdx.length > 0 || glowIdx.length > 0 || carousel !== null
    readonly property var mapArea: st && hasMap ? Fx.mapRegion(st, on, false) : null           // em células
    readonly property var frontArea: st && hasFront ? Fx.mapRegion(st, on, true) : null
    readonly property var mapPal: st ? (recolorTick, Fx.mapPalette(st, on)) : null
    function palVec(i) { const c = mapPal ? mapPal.colors[i] : [1, 1, 1]; return Qt.vector4d(c[0], c[1], c[2], 1) }

    property real clock: 0               // segundos desde o início, avança a cada quadro (~11/s)
    property int tick: 0

    onWidthChanged: rebuildSoon.restart()
    onHeightChanged: rebuildSoon.restart()
    onMonoChanged: rebuild(false)
    // Troca de DNA: a base de caracteres NÃO depende da cor do DNA (modo branco é branco), e redesenhá-la
    // travava a shell ~430 ms bem na animação da transformação. Só os brilhos e a paleta do mapa usam a cor:
    // atualizados em lugar, depois que a onda da transformação termina (shaders já seguem sc.dna sozinhos).
    property int recolorTick: 0
    onDnaChanged: recolorSoon.restart()
    Timer { id: recolorSoon; interval: 1300; onTriggered: sc.recolor() }
    function recolor() {
        if (!st) return
        st.dna = Fx.hex(String(dna))
        recolorTick++
    }
    onOnChanged: if (st) { st.parts = {}; mapBack.requestPaint(); mapFront.requestPaint() }
    Timer { id: rebuildSoon; interval: 120; onTriggered: sc.rebuild(false) }

    function rebuild(burst) {
        if (!scene || !decoded || width < 10 || height < 10) return
        const s = Fx.makeState(scene, decoded, width, height, mono, String(dna))
        if (burst) s.burst = 5
        st = s
        base.requestPaint(); atlas.requestPaint(); mapBack.requestPaint(); mapFront.requestPaint()
    }
    readonly property real cw: st ? st.cw : 1
    readonly property real ch: st ? st.ch : 1
    readonly property vector2d grid: st ? Qt.vector2d(st.S.cols, st.S.rows) : Qt.vector2d(1, 1)
    function vec(c) { const q = Qt.color(c); return Qt.vector4d(q.r, q.g, q.b, 1) }

    // ── camadas
    Canvas {
        id: base
        anchors.fill: parent
        onPaint: { const ctx = getContext("2d"); if (sc.st) Fx.paintBase(sc.st, ctx); else ctx.clearRect(0, 0, width, height) }
    }

    // atlas de glifos (a rampa + "=") para os shaders
    Canvas {
        id: atlas
        width: Math.max(1, Math.ceil(sc.cw * Fx.glyphCount())); height: Math.max(1, Math.ceil(sc.ch))
        onPaint: Fx.paintAtlas(getContext("2d"), sc.cw, sc.ch)
    }
    ShaderEffectSource { id: atlasSrc; sourceItem: atlas; hideSource: true; smooth: true; visible: false }

    component CellFx: AsciiCellFx {
        id: cfx
        required property int modelData
        readonly property var eff: sc.effects[modelData]
        readonly property var reg: sc.st ? Fx.gpuRegion(sc.st, eff) : [0, 0, 1, 1]
        readonly property bool hasMask: !!(eff.poly || eff.flood)
        x: reg[0] * sc.cw; y: reg[1] * sc.ch; width: reg[2] * sc.cw; height: reg[3] * sc.ch
        baseTex: base
        maskTex: hasMask ? maskSrc : atlasSrc
        atlasTex: atlasSrc
        mapTex: atlasSrc
        grid: sc.grid
        region: Qt.vector4d(reg[0], reg[1], reg[2], reg[3])
        mode: Fx.MODE[eff.type]
        t: sc.animate ? sc.clock : 0
        tick: sc.tick
        p2: eff.type === "planeta" ? Qt.vector4d(Fx.GLYPH.dot, Fx.GLYPH.dash, Fx.GLYPH.eq, eff.ring ? 1 : 0) : Qt.vector4d(0, 0, 0, 0)   // glifos do planeta; anel
        col1: sc.vec(sc.mono || !eff.color || eff.color === "dna" || eff.color === "foto" ? sc.dna : eff.color)
        col2: sc.vec(sc.mono ? sc.dna : (eff.color2 || eff.color || sc.dna))

        // máscara (silhueta que não gira / que flutua): uma célula por pixel
        Canvas {
            id: maskCanvas
            width: sc.st ? sc.st.S.cols : 1; height: sc.st ? sc.st.S.rows : 1
            visible: cfx.hasMask
            property var state: sc.st
            onStateChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d"); ctx.clearRect(0, 0, width, height)
                if (!sc.st || !cfx.hasMask) return
                const M = Fx.maskCells(sc.st, cfx.eff, cfx.modelData); ctx.fillStyle = "#ffffff"
                for (let i = 0; i < M.length; i++) if (M[i]) ctx.fillRect(i % width, Math.floor(i / width), 1, 1)
            }
        }
        ShaderEffectSource { id: maskSrc; sourceItem: maskCanvas; hideSource: true; smooth: false; visible: false }

        function setup() {
            const e = eff
            if (e.type === "redemoinho") { p0 = Qt.vector4d(e.cx, e.cy, e.rx, e.ry); p1 = Qt.vector4d(e.speed || .5, e.swirl !== undefined ? e.swirl : .6, hasMask ? 1 : 0, 0) }
            else if (e.type === "vento") p1 = Qt.vector4d(e.amp || 1, 0, 0, 0)
            else if (e.type === "estrelas") p1 = Qt.vector4d(Fx.GLYPH.star, Fx.GLYPH.plus, Fx.GLYPH.dot, 0)
            else if (e.type === "chuva") p1 = Qt.vector4d(Fx.GLYPH.slash, 0, 0, 0)
            else if (e.type === "neve") { p0 = Qt.vector4d(e.wind || .6, 0, 0, 0); p1 = Qt.vector4d(Fx.GLYPH.star, Fx.GLYPH.plus, Fx.GLYPH.dot, 0) }
            else if (e.type === "cometas") p1 = Qt.vector4d(Fx.GLYPH.star, Fx.GLYPH.eq, Fx.GLYPH.dash, 0)
            else if (e.type === "faiscas" || e.type === "bolhas" || e.type === "matrix") {
                const b = Fx.boxOf(sc.st, e); p0 = Qt.vector4d(Math.floor(b[0]), Math.floor(b[1]), Math.ceil(b[2]), Math.ceil(b[3]))
                const G = Fx.GLYPH
                if (e.type === "faiscas") { p1 = Qt.vector4d(G.dot, G.comma, G.star, G.plus)
                    p2 = Qt.vector4d(({ up: 0, out: 1, twinkle: 2 })[e.dir || "up"] || 0, e.speed || 1, e.dens || 1, G.apos) }
                else if (e.type === "bolhas") p1 = Qt.vector4d(G.bigO, G.smallO, G.deg, 0)
                else { const m = Fx.matrixGlyphs(e); p1 = Qt.vector4d(e.step || 2, e.speed || 1, e.alpha || .55, m.n)
                    b0 = Qt.vector4d(m.idx[0], m.idx[1], m.idx[2], m.idx[3]); b1 = Qt.vector4d(m.idx[4], m.idx[5], m.idx[6], m.idx[7]) }
            }
            else if ((e.type === "buraconegro" || e.type === "galaxia") && sc.st) {
                p0 = Qt.vector4d(e.cx * sc.st.W, e.cy * sc.st.H, e.r * sc.st.H, e.speed || .2)
                p1 = Qt.vector4d(sc.st.cw, sc.st.ch, e.tilt || .45, 0)
            }
            else if (e.type === "planeta" && sc.st) {
                // do estado da cena (sc.cw/sc.ch podem ainda não ter atualizado quando o efeito nasce)
                p0 = Qt.vector4d(e.cx * sc.st.W, e.cy * sc.st.H, e.r * sc.st.H, e.speed || .15)
                p1 = Qt.vector4d(sc.st.cw, sc.st.ch, e.bands || 7, e.terra && !sc.mono ? 1 : 0)
            }
            step()
        }
        function step() {
            const e = eff
            if (!sc.st) return
            if (e.type === "flutuar") p0 = Qt.vector4d(Math.round((e.lift !== undefined ? e.lift : 1.5) + (e.amp !== undefined ? e.amp : 1.5) * Math.sin(sc.clock * (e.speed || 1.1))), 0, 0, 0)
            else if (e.type === "glitch") { const b = Fx.glitchBands(sc.st, modelData, e)
                b0 = Qt.vector4d(b[0][0], b[0][1], b[0][2], b[0][3]); b1 = Qt.vector4d(b[1][0], b[1][1], b[1][2], b[1][3]); b2 = Qt.vector4d(b[2][0], b[2][1], b[2][2], b[2][3])
                b3 = Qt.vector4d(b[3][0], b[3][1], b[3][2], b[3][3]); b4 = Qt.vector4d(b[4][0], b[4][1], b[4][2], b[4][3]); b5 = Qt.vector4d(b[5][0], b[5][1], b[5][2], b[5][3]) }
            else if (e.type === "cometas") { const h = Fx.cometHeads(sc.st, modelData, e)
                b0 = Qt.vector4d(h[0][0], h[0][1], h[1][0], h[1][1]); b1 = Qt.vector4d(h[2][0], h[2][1], h[3][0], h[3][1]); b2 = Qt.vector4d(h[4][0], h[4][1], h[5][0], h[5][1])
                b3 = Qt.vector4d(h[6][0], h[6][1], h[7][0], h[7][1]); b4 = Qt.vector4d(h[8][0], h[8][1], h[9][0], h[9][1]); b5 = Qt.vector4d(h[10][0], h[10][1], h[11][0], h[11][1]) }
            else if (e.type === "vulto") { const v = Fx.vultoStep(sc.st, modelData)
                p0 = Qt.vector4d(v.blackout ? 1 : 0, 0, 0, 0)
                b0 = Qt.vector4d(v.off[0][0], v.off[0][1], 0, 0); b1 = Qt.vector4d(v.off[1][0], v.off[1][1], 0, 0); b2 = Qt.vector4d(v.off[2][0], v.off[2][1], 0, 0) }
        }
        Component.onCompleted: setup()
        Connections { target: sc; function onStChanged() { cfx.setup() } function onStepped() { cfx.step() } }
    }

    Repeater { model: sc.st ? sc.remapIdx : []; delegate: CellFx {} }

    // mapa de células (raios, rastro, órbita): um pixel por célula; o shader desenha os glifos e o halo
    Canvas {
        id: mapBack
        property bool dirty: true            // precisa limpar um último quadro quando os efeitos param
        width: sc.grid.x; height: sc.grid.y
        visible: false
        onPaint: {
            const ctx = getContext("2d")
            if (!sc.st || !sc.animate || !sc.hasMap) { ctx.clearRect(0, 0, width, height); return }
            Fx.cellMapFrame(sc.st, sc.on, sc.clock, false, ctx)
        }
    }
    ShaderEffectSource { id: mapBackSrc; sourceItem: mapBack; hideSource: true; smooth: false; visible: false }
    Canvas {   // só a metade da frente das órbitas
        id: mapFront
        property bool dirty: true
        width: sc.grid.x; height: sc.grid.y
        visible: false
        onPaint: {
            const ctx = getContext("2d")
            if (!sc.st || !sc.animate || !sc.hasFront) { ctx.clearRect(0, 0, width, height); return }
            Fx.cellMapFrame(sc.st, sc.on, sc.clock, true, ctx)
        }
    }
    ShaderEffectSource { id: mapFrontSrc; sourceItem: mapFront; hideSource: true; smooth: false; visible: false }

    component MapFx: AsciiCellFx {
        required property var area
        required property Item tex
        x: area ? area[0] * sc.cw : 0; y: area ? area[1] * sc.ch : 0
        width: area ? area[2] * sc.cw : 1; height: area ? area[3] * sc.ch : 1
        visible: area !== null
        baseTex: base; maskTex: atlasSrc; atlasTex: atlasSrc; mapTex: tex
        grid: sc.grid
        region: area ? Qt.vector4d(area[0], area[1], area[2], area[3]) : Qt.vector4d(0, 0, 1, 1)
        mode: 16
        b0: sc.palVec(0); b1: sc.palVec(1); b2: sc.palVec(2); b3: sc.palVec(3); b4: sc.palVec(4); b5: sc.palVec(5); p2: sc.palVec(6)
    }
    MapFx { area: sc.mapArea; tex: mapBackSrc }
    // a metade da frente das órbitas vai para cima do Omnitrix (frontHost, da LiveDesktop)
    MapFx { parent: sc.frontHost ? sc.frontHost : sc; area: sc.frontArea; tex: mapFrontSrc }

    // carrossel: a troca de cena ganha faixas de glitch (mesmo shader)
    Repeater {
        model: sc.st && sc.carousel ? [0] : []
        delegate: AsciiCellFx {
            id: burstFx
            anchors.fill: parent
            baseTex: base; maskTex: atlasSrc; atlasTex: atlasSrc; mapTex: atlasSrc
            grid: sc.grid
            region: Qt.vector4d(0, 0, sc.grid.x, sc.grid.y)
            mode: 2
            col1: sc.vec(sc.dna)
            Connections { target: sc; function onStepped() {
                if (!sc.st) return; const b = Fx.glitchBands(sc.st, "burst", null)
                burstFx.b0 = Qt.vector4d(b[0][0], b[0][1], b[0][2], b[0][3]); burstFx.b1 = Qt.vector4d(b[1][0], b[1][1], b[1][2], b[1][3])
                burstFx.b2 = Qt.vector4d(b[2][0], b[2][1], b[2][2], b[2][3]); burstFx.b3 = Qt.vector4d(b[3][0], b[3][1], b[3][2], b[3][3]) } }
        }
    }

    Repeater { model: sc.st ? sc.planetIdx : []; delegate: CellFx {} }

    // letreiro: frases nítidas por cima da arte
    Repeater {
        model: sc.st ? sc.textIdx : []
        Column {
            id: sign
            required property int modelData
            readonly property var eff: sc.effects[modelData]
            x: eff.x * sc.width; y: eff.y * sc.height
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 0.8; shadowOpacity: 0.9; shadowHorizontalOffset: 0; shadowVerticalOffset: 2 }
            Repeater {
                model: sign.eff.lines
                Text {
                    required property string modelData
                    required property int index
                    text: modelData
                    height: sign.eff.size * sc.height * 1.05          // mesmo espaçamento da prévia
                    verticalAlignment: Text.AlignTop
                    font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: sign.eff.size * sc.height * 1.08
                    color: index === sign.eff.lines.length - 1 && sign.eff.accent ? sign.eff.accent : Qt.rgba(0.94, 0.96, 0.98, 0.95)
                }
            }
        }
    }

    // brilhos (pulso/aura)
    Repeater {
        model: sc.st ? sc.glowIdx : []
        Item {
            id: glow
            required property int modelData
            readonly property var eff: sc.effects[modelData]
            anchors.fill: parent
            // pisca no ritmo do relógio da cena (11/s), não a 60/s: a tela não é recomposta à toa
            readonly property real pulse: sc.animate ? 0.2 + 0.8 * (0.5 + 0.5 * Math.sin(sc.clock * (eff.type === "aura" ? 1.4 : 2.2) + modelData)) : 0.6
            Canvas {   // as células que brilham (escondido: só alimenta as duas cópias abaixo)
                id: glowCanvas
                anchors.fill: parent
                visible: false
                property var state: sc.st
                onStateChanged: requestPaint()
                property int recolored: sc.recolorTick
                onRecoloredChanged: requestPaint()
                onPaint: { const ctx = getContext("2d"); if (sc.st) Fx.paintGlow(sc.st, ctx, glow.eff, Fx.glowCells(sc.st, glow.eff)) }
            }
            Item {   // halo desfocado: calculado uma vez e guardado (layer); piscar só muda a transparência
                anchors.fill: parent
                opacity: glow.pulse * 0.9
                layer.enabled: true
                MultiEffect {
                    anchors.fill: parent
                    source: glowCanvas
                    blurEnabled: true; blur: 0.6; blurMax: 32
                    brightness: 0.15
                }
            }
            ShaderEffectSource {   // caracteres nítidos por cima
                anchors.fill: parent
                sourceItem: glowCanvas
                opacity: glow.pulse * 0.55
            }
        }
    }

    // ── relógio dos efeitos e do carrossel
    Timer {
        interval: 90
        repeat: true
        running: sc.animate && sc.st !== null && sc.visible && sc.hasMotion
        onTriggered: {
            if (sc.carousel && Date.now() - sc.switchedAt > (sc.every || sc.carEvery) * 1000) { sc.switchedAt = Date.now(); sc.nextInCarousel() }
            sc.clock = (Date.now() - sc.t0) / 1000; sc.tick++
            sc.stepped()
            if (sc.hasMap || mapBack.dirty) { mapBack.dirty = sc.hasMap; mapBack.requestPaint() }
            if (sc.hasFront || mapFront.dirty) { mapFront.dirty = sc.hasFront; mapFront.requestPaint() }
        }
    }
    onAnimateChanged: { mapBack.dirty = true; mapFront.dirty = true; mapBack.requestPaint(); mapFront.requestPaint() }
    onHasMapChanged: { mapBack.dirty = true; mapBack.requestPaint() }
    onHasFrontChanged: { mapFront.dirty = true; mapFront.requestPaint() }
}
