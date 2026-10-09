// Project Azmuth — modo edição da área de trabalho ("desktop canvas").
// Arrastar move · scroll muda o tamanho · × remove · guias inteligentes (alinham com
// bordas/centros dos outros widgets e da tela) e réguas com os espaços entre widgets ·
// barra do topo adiciona widgets do catálogo · Esc ou CONCLUIR sai. Tudo salva na hora.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: ed

    required property var theme
    visible: DeskLayout.editing
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-desktop-editor"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // guias inteligentes (estilo Canva): linhas de alinhamento e medidas dos espaços
    property var vGuides: []    // x das linhas verticais
    property var hGuides: []    // y das linhas horizontais
    property var gaps: []       // [{x1, y1, x2, y2, label}]
    readonly property real snap: 8

    function rectOf(it) { return { l: it.x, r: it.x + it.width, t: it.y, b: it.y + it.height, cx: it.x + it.width / 2, cy: it.y + it.height / 2 } }
    function align(box) {
        const others = []
        for (let i = 0; i < rep.count; i++) { const it = rep.itemAt(i); if (it && it !== box) others.push(rectOf(it)) }
        // x: bordas/centro do widget contra bordas/centros dos outros e o centro da tela
        const xc = [ed.width / 2].concat(...others.map(o => [o.l, o.cx, o.r]))
        const yc = [ed.height / 2].concat(...others.map(o => [o.t, o.cy, o.b]))
        const fit = (pos, size, cands) => {
            let best = null
            for (const off of [0, size / 2, size]) for (const c of cands) {
                const d = c - (pos + off)
                if (Math.abs(d) <= ed.snap && (!best || Math.abs(d) < Math.abs(best.d))) best = { d: d, line: c }
            }
            return best
        }
        const bx = fit(box.x, box.width, xc), by = fit(box.y, box.height, yc)
        if (bx) box.x += bx.d
        if (by) box.y += by.d
        vGuides = bx ? [bx.line] : []
        hGuides = by ? [by.line] : []
        // espaços até o vizinho mais próximo em cada direção
        const me = rectOf(box), g = []
        let L = null, R = null, T = null, B = null
        for (const o of others) {
            if (o.t < me.b && o.b > me.t) {
                if (o.l >= me.r && (!R || o.l < R.l)) R = o
                if (o.r <= me.l && (!L || o.r > L.r)) L = o
            }
            if (o.l < me.r && o.r > me.l) {
                if (o.t >= me.b && (!B || o.t < B.t)) B = o
                if (o.b <= me.t && (!T || o.b > T.b)) T = o
            }
        }
        const midY = o => (Math.max(o.t, me.t) + Math.min(o.b, me.b)) / 2
        const midX = o => (Math.max(o.l, me.l) + Math.min(o.r, me.r)) / 2
        if (R) g.push({ x1: me.r, y1: midY(R), x2: R.l, y2: midY(R), label: Math.round(R.l - me.r) })
        if (L) g.push({ x1: L.r, y1: midY(L), x2: me.l, y2: midY(L), label: Math.round(me.l - L.r) })
        if (B) g.push({ x1: midX(B), y1: me.b, x2: midX(B), y2: B.t, label: Math.round(B.t - me.b) })
        if (T) g.push({ x1: midX(T), y1: T.b, x2: midX(T), y2: me.t, label: Math.round(me.t - T.b) })
        gaps = g
    }
    function clearGuides() { vGuides = []; hGuides = []; gaps = [] }

    // fundo: escurece e mostra uma grade fina
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.62 }
    Canvas {
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            ctx.strokeStyle = Qt.alpha(Colors.primary, 0.07); ctx.lineWidth = 1
            for (let x = 0; x < width; x += 40) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke() }
            for (let y = 0; y < height; y += 40) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke() }
        }
    }
    // guias + réguas dos espaços
    Canvas {
        id: guides
        anchors.fill: parent
        z: 50
        onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            ctx.strokeStyle = "#ff4fd8"; ctx.lineWidth = 1.5; ctx.setLineDash([6, 4])
            for (const x of ed.vGuides) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke() }
            for (const y of ed.hGuides) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke() }
            ctx.setLineDash([]); ctx.strokeStyle = "#ffd76a"; ctx.fillStyle = "#ffd76a"; ctx.lineWidth = 1.5
            ctx.font = "bold 12px 'Orbitron'"
            for (const g of ed.gaps) {
                ctx.beginPath(); ctx.moveTo(g.x1, g.y1); ctx.lineTo(g.x2, g.y2); ctx.stroke()
                const horiz = g.y1 === g.y2
                for (const [x, y] of [[g.x1, g.y1], [g.x2, g.y2]]) {   // marcas nas pontas
                    ctx.beginPath()
                    if (horiz) { ctx.moveTo(x, y - 6); ctx.lineTo(x, y + 6) } else { ctx.moveTo(x - 6, y); ctx.lineTo(x + 6, y) }
                    ctx.stroke()
                }
                const t = g.label + " px", mx = (g.x1 + g.x2) / 2, my = (g.y1 + g.y2) / 2
                const w = ctx.measureText(t).width + 12
                ctx.fillStyle = "#14110a"; ctx.fillRect(mx - w / 2, my - 10, w, 20)
                ctx.fillStyle = "#ffd76a"; ctx.fillText(t, mx - w / 2 + 6, my + 4)
            }
        }
        Connections {
            target: ed
            function onVGuidesChanged() { guides.requestPaint() }
            function onHGuidesChanged() { guides.requestPaint() }
            function onGapsChanged() { guides.requestPaint() }
        }
    }

    Item {
        anchors.fill: parent
        focus: ed.visible
        Keys.onEscapePressed: DeskLayout.editing = false
    }

    Repeater {
        id: rep
        model: DeskLayout.widgets
        Item {
            id: box
            required property var modelData
            readonly property real s: modelData.s || 1
            width: w.implicitWidth * s + 24
            height: w.implicitHeight * s + 24
            x: ed.width * modelData.x - width / 2
            y: ed.height * modelData.y - height / 2

            DeskWidget {
                id: w
                type: box.modelData.type
                src: box.modelData.src || ""
                theme: ed.theme
                width: implicitWidth; height: implicitHeight
                scale: box.s
                anchors.centerIn: parent
            }
            Shape {   // moldura tracejada
                anchors.fill: parent
                ShapePath {
                    strokeColor: drag.pressed || drag.containsMouse ? Colors.primary : Qt.alpha(Colors.primary, 0.5)
                    strokeWidth: 1.5; fillColor: Qt.alpha(Colors.primary, drag.containsMouse ? 0.06 : 0.02)
                    strokeStyle: ShapePath.DashLine; dashPattern: [4, 3]
                    startX: 0; startY: 0
                    PathLine { x: box.width; y: 0 } PathLine { x: box.width; y: box.height } PathLine { x: 0; y: box.height } PathLine { x: 0; y: 0 }
                }
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: box
                drag.threshold: 2
                onPositionChanged: { if (pressed) ed.align(box) }
                onReleased: {
                    ed.clearGuides()
                    DeskLayout.update(box.modelData.uid, {
                        x: Math.max(0.02, Math.min(0.98, (box.x + box.width / 2) / ed.width)),
                        y: Math.max(0.03, Math.min(0.97, (box.y + box.height / 2) / ed.height))
                    })
                }
                onWheel: wheel => DeskLayout.update(box.modelData.uid, { s: Math.max(0.5, Math.min(2, Math.round((box.s + (wheel.angleDelta.y > 0 ? 0.1 : -0.1)) * 10) / 10)) })
            }
            // etiqueta
            Rectangle {
                x: 0; y: -30
                height: 24; width: tag.implicitWidth + 20; radius: 12
                color: Colors.bg; border.width: 1; border.color: Colors.primary
                Row {
                    id: tag
                    anchors.centerIn: parent; spacing: 6
                    Glyph { anchors.verticalCenter: parent.verticalCenter; width: 13; height: 13; name: DeskLayout.info(box.modelData.type).glyph; color: Colors.primary; stroke: 1.5 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: DeskLayout.info(box.modelData.type).name.toUpperCase() + " · " + Math.round(box.s * 100) + "%"; font.family: "Orbitron"; font.pixelSize: 9; font.weight: Font.Bold; color: Colors.primary }
                }
            }
            // remover
            Rectangle {
                x: box.width - 12; y: -12
                width: 26; height: 26; radius: 13
                color: xm.containsMouse ? Colors.danger : Colors.bg
                border.width: 1.5; border.color: Colors.danger
                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 13; font.bold: true; color: xm.containsMouse ? Colors.bg : Colors.danger }
                MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: DeskLayout.remove(box.modelData.uid) }
            }
        }
    }

    // barra de ferramentas
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 60
        width: bar.implicitWidth + 36; height: 56; radius: 28
        color: Qt.alpha(Colors.bg, 0.96)
        border.width: 1.5; border.color: Qt.alpha(Colors.primary, 0.6)
        Row {
            id: bar
            anchors.centerIn: parent
            spacing: 8
            Column {
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: 10
                Text { text: "MODO EDIÇÃO"; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 12; font.letterSpacing: 2; color: Colors.primary }
                Text { text: "arraste · scroll = tamanho · ✕ remove"; font.family: "Rajdhani"; font.pixelSize: 12; color: Qt.alpha(Colors.fg, 0.55) }
            }
            Repeater {
                model: DeskLayout.catalog.filter(c => c.type !== "imagem")   // imagem: escolha na Central
                UiButton {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: modelData.glyph
                    text: modelData.name.split(" ")[0].toUpperCase()
                    onClicked: DeskLayout.add(modelData.type)
                }
            }
            Rectangle { width: 1; height: 30; color: Qt.alpha(Colors.primary, 0.3); anchors.verticalCenter: parent.verticalCenter }
            UiButton { anchors.verticalCenter: parent.verticalCenter; text: "RESTAURAR"; tint: Colors.warn; onClicked: DeskLayout.reset() }
            UiButton { anchors.verticalCenter: parent.verticalCenter; text: "CONCLUIR"; filled: true; onClicked: DeskLayout.editing = false }
        }
    }
}
