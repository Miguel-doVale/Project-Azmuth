// Project Azmuth — área de trabalho viva: o Omnitrix do centro é O Omnitrix.
// Fundo com circuitos galvânicos e pulsos de energia correndo pelas trilhas
// (mais rápidos com a CPU alta), símbolo desenhado ao vivo (Arch no core no
// Neutral), anel de energia, clique abre o HUD (que nasce do símbolo).
// Desligável no painel de configuração ("Área de trabalho viva").

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: live

    required property var theme
    required property ShellScreen modelData
    property bool hudOpen: false
    screen: modelData

    readonly property color primary: Energy.locked ? "#ff5a5a" : theme.primary
    readonly property color dna: theme.primary
    readonly property color bg: theme.background
    readonly property bool neutral: theme.id === "neutral"
    readonly property real rad: height * 0.27

    // 0 = core Arch (Neutral) · 1 = ampulheta do DNA. Anima a "mutação" entre os dois.
    property real mutation: neutral ? 0 : 1
    Behavior on mutation { NumberAnimation { duration: 1100; easing.type: Easing.InOutCubic } }
    readonly property real archOut: Math.min(1, mutation / 0.55)                       // Arch some na 1ª metade
    readonly property real glassIn: Math.max(0, Math.min(1, (mutation - 0.35) / 0.65)) // ampulheta surge depois
    readonly property real glitch: Math.sin(mutation * 60) * 7 * archOut * (1 - archOut) * 4

    visible: theme.live !== false
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: bg
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "azmuth-live"
    mask: Region { item: symbolHit }                  // só o símbolo recebe clique

    // ───────────────────────── fundo ─────────────────────────
    Rectangle {   // brilho radial atrás do símbolo
        anchors.centerIn: parent
        width: live.rad * 3.4; height: width; radius: width / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(live.dna, 0.10) }
            GradientStop { position: 1.0; color: "transparent" }
        }
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64 }
    }

    // circuitos: geração determinística (mesma "placa" sempre), centro livre
    property var traces: []
    function genTraces() {
        let seed = 1337
        const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff }
        const step = 32, out = []
        const cx = width / 2, cy = height / 2, clear = rad * 1.25
        const dirs = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [-1, 1], [1, -1], [-1, -1]]
        for (let k = 0; k < 110; k++) {
            let x = Math.round(rnd() * width / step) * step, y = Math.round(rnd() * height / step) * step
            if (Math.hypot(x - cx, y - cy) < clear) continue
            const pts = [[x, y]]
            let len = 0
            for (let s = 0; s < 2 + Math.floor(rnd() * 4); s++) {
                const d = dirs[Math.floor(rnd() * dirs.length)], n = (1 + Math.floor(rnd() * 5)) * step
                x += d[0] * n; y += d[1] * n
                if (Math.hypot(x - cx, y - cy) < clear) break
                pts.push([x, y]); len += n * (d[0] && d[1] ? 1.414 : 1)
            }
            if (pts.length > 1) out.push({ pts: pts, len: len })
        }
        traces = out
        board.requestPaint()
    }
    onWidthChanged: if (width > 0 && height > 0) genTraces()
    onHeightChanged: if (width > 0 && height > 0) genTraces()

    Canvas {
        id: board
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.lineWidth = 1.6
            ctx.lineJoin = "round"
            ctx.strokeStyle = Qt.alpha(live.dna, 0.22)
            ctx.fillStyle = Qt.alpha(live.dna, 0.35)
            for (const t of live.traces) {
                ctx.beginPath()
                ctx.moveTo(t.pts[0][0], t.pts[0][1])
                for (let i = 1; i < t.pts.length; i++) ctx.lineTo(t.pts[i][0], t.pts[i][1])
                ctx.stroke()
                const e = t.pts[t.pts.length - 1]
                ctx.beginPath(); ctx.arc(e[0], e[1], 3.2, 0, Math.PI * 2); ctx.stroke()
                ctx.beginPath(); ctx.arc(t.pts[0][0], t.pts[0][1], 1.8, 0, Math.PI * 2); ctx.fill()
            }
        }
        Connections { target: live; function onDnaChanged() { board.requestPaint() } }
    }

    // pulsos de energia percorrendo as trilhas
    Repeater {
        id: pulses
        model: 16
        Item {
            id: pulse
            required property int index
            property var trace: null
            property real pos: 0                    // distância percorrida na trilha
            property real hx: -100
            property real hy: -100
            property real ang: 0
            function respawn() {
                if (!live.traces.length) return
                trace = live.traces[Math.floor(Math.random() * live.traces.length)]
                pos = -Math.random() * 400            // chegada escalonada
            }
            Component.onCompleted: respawn()
            Connections { target: live; function onTracesChanged() { pulse.respawn() } }

            function advance(dt) {
                if (!trace) { respawn(); return }
                pos += dt * (90 + 260 * Math.min(1, SysStats.cpu / 70))
                if (pos < 0) { hx = -100; return }
                let d = pos
                for (let i = 1; i < trace.pts.length; i++) {
                    const a = trace.pts[i - 1], b = trace.pts[i]
                    const seg = Math.hypot(b[0] - a[0], b[1] - a[1])
                    if (d <= seg) {
                        const k = d / seg
                        hx = a[0] + (b[0] - a[0]) * k; hy = a[1] + (b[1] - a[1]) * k
                        ang = Math.atan2(b[1] - a[1], b[0] - a[0]) * 180 / Math.PI
                        return
                    }
                    d -= seg
                }
                respawn()
            }

            Rectangle {   // rastro
                x: pulse.hx - width; y: pulse.hy - height / 2
                width: 34; height: 3; radius: 1.5
                transformOrigin: Item.Right
                rotation: pulse.ang
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: live.dna }
                }
            }
            Rectangle {   // cabeça
                x: pulse.hx - 4; y: pulse.hy - 4
                width: 8; height: 8; radius: 4
                color: Qt.lighter(live.dna, 1.4)
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: live.dna; shadowBlur: 1.0; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
            }
        }
    }
    Timer {
        id: frame
        interval: 33; repeat: true
        running: live.visible
        property real last: Date.now()
        onTriggered: {
            const now = Date.now(), dt = Math.min(0.1, (now - last) / 1000)
            last = now
            for (let i = 0; i < 16; i++) { const p = pulses.itemAt(i); if (p) p.advance(dt) }
        }
    }
    Component.onCompleted: { if (width > 0) genTraces() }

    // ───────────────────────── o Omnitrix ─────────────────────────
    Item {
        id: symbol
        width: live.rad * 2; height: width
        anchors.centerIn: parent
        opacity: live.hudOpen ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // pulso de transformação
        SequentialAnimation {
            id: morph
            ParallelAnimation {
                NumberAnimation { target: symbol; property: "scale"; to: 1.06; duration: 160; easing.type: Easing.OutCubic }
                RotationAnimation { target: face; property: "rotation"; from: 0; to: 360; duration: 700; easing.type: Easing.OutBack }
            }
            NumberAnimation { target: symbol; property: "scale"; to: 1.0; duration: 420; easing.type: Easing.OutBack }
        }
        Connections { target: live; function onDnaChanged() { morph.restart() } }

        // anel de energia (fora do aro)
        Shape {
            anchors.fill: parent
            anchors.margins: -18
            preferredRendererType: Shape.CurveRenderer
            visible: Energy.enabled
            ShapePath {
                strokeColor: Qt.alpha(live.primary, 0.14); strokeWidth: 5; fillColor: "transparent"
                PathAngleArc { centerX: symbol.width / 2 + 18; centerY: symbol.height / 2 + 18; radiusX: live.rad + 12; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: live.primary; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: symbol.width / 2 + 18; centerY: symbol.height / 2 + 18; radiusX: live.rad + 12; radiusY: radiusX; startAngle: -90; sweepAngle: 360 * Math.max(0.002, Energy.level) }
            }
        }

        Rectangle {   // aro
            id: bezel
            anchors.fill: parent
            radius: width / 2
            color: "#15181b"
            border.width: 4
            border.color: Qt.alpha(live.primary, 0.45)
            Repeater {   // garras
                model: 4
                Rectangle {
                    required property int index
                    readonly property real a: (45 + 90 * index) * Math.PI / 180
                    width: bezel.width * 0.1; height: bezel.width * 0.036; radius: height / 2
                    color: "#2a2f35"
                    x: bezel.width / 2 + Math.cos(a) * bezel.width * 0.455 - width / 2
                    y: bezel.height / 2 + Math.sin(a) * bezel.height * 0.455 - height / 2
                    rotation: 135 + 90 * index
                }
            }
        }

        Item {   // marcações girando devagar
            id: ticks
            anchors.fill: parent
            NumberAnimation on rotation { from: 0; to: 360; duration: 90000; loops: Animation.Infinite; running: live.visible }
            Repeater {
                model: 36
                Rectangle {
                    required property int index
                    readonly property real a: index * 10 * Math.PI / 180
                    width: index % 3 ? 2 : 3; height: live.rad * (index % 3 ? 0.035 : 0.06); radius: 1
                    color: Qt.alpha(live.primary, index % 3 ? 0.35 : 0.8)
                    x: symbol.width / 2 + Math.sin(a) * live.rad * 0.86 - width / 2
                    y: symbol.height / 2 - Math.cos(a) * live.rad * 0.86 - height / 2
                    rotation: index * 10
                }
            }
        }

        Rectangle {   // face
            id: face
            anchors.centerIn: parent
            width: live.rad * 1.5; height: width; radius: width / 2
            color: "#07090b"
            border.width: 6
            border.color: live.primary
            Behavior on border.color { ColorAnimation { duration: 400 } }

            Item {   // conteúdo com "respiração" de brilho
                id: core
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: live.primary
                    shadowBlur: 1.0; shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                    shadowOpacity: breath.v
                }
                QtObject { id: breath; property real v: 0.5 }
                SequentialAnimation {
                    running: live.visible; loops: Animation.Infinite
                    NumberAnimation { target: breath; property: "v"; to: 0.95; duration: 2200; easing.type: Easing.InOutSine }
                    NumberAnimation { target: breath; property: "v"; to: 0.35; duration: 2200; easing.type: Easing.InOutSine }
                }

                Shape {   // ampulheta (DNAs)
                    id: glass
                    visible: live.glassIn > 0
                    anchors.fill: parent
                    opacity: live.glassIn * (live.theme.art ? 0.35 : 1)
                    scale: 0.25 + 0.75 * live.glassIn
                    rotation: (1 - live.glassIn) * -120
                    readonly property real f: face.width
                    ShapePath {
                        strokeWidth: 0; fillColor: live.primary
                        startX: glass.f * 0.22; startY: glass.f * 0.12
                        PathLine { x: glass.f * 0.78; y: glass.f * 0.12 }
                        PathLine { x: glass.f * 0.84; y: glass.f * 0.17 }
                        PathLine { x: glass.f * 0.5; y: glass.f * 0.485 }
                        PathLine { x: glass.f * 0.16; y: glass.f * 0.17 }
                        PathLine { x: glass.f * 0.22; y: glass.f * 0.12 }
                    }
                    ShapePath {
                        strokeWidth: 0; fillColor: live.primary
                        startX: glass.f * 0.22; startY: glass.f * 0.88
                        PathLine { x: glass.f * 0.78; y: glass.f * 0.88 }
                        PathLine { x: glass.f * 0.84; y: glass.f * 0.83 }
                        PathLine { x: glass.f * 0.5; y: glass.f * 0.515 }
                        PathLine { x: glass.f * 0.16; y: glass.f * 0.83 }
                        PathLine { x: glass.f * 0.22; y: glass.f * 0.88 }
                    }
                }
                Shape {   // core Arch (Neutral) — "muta" ao transformar: tremula, gira e encolhe
                    id: arch
                    visible: live.archOut < 1
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: live.glitch
                    opacity: 1 - live.archOut
                    scale: 1 - 0.7 * live.archOut
                    rotation: 200 * live.archOut
                    width: face.width * 0.56; height: width
                    ShapePath {
                        strokeWidth: 0; fillColor: live.primary
                        scale: Qt.size(arch.width / 24, arch.height / 24)
                        PathSvg { path: "M11.39.605C10.376 3.092 9.764 4.72 8.635 7.132c.693.734 1.543 1.589 2.923 2.554-1.484-.61-2.496-1.224-3.252-1.86C6.86 10.842 4.596 15.138 0 23.395c3.612-2.085 6.412-3.37 9.021-3.862a6.61 6.61 0 01-.171-1.547l.003-.115c.058-2.315 1.261-4.095 2.687-3.973 1.426.12 2.534 2.096 2.478 4.409a6.52 6.52 0 01-.146 1.243c2.58.505 5.352 1.787 8.914 3.844-.702-1.293-1.33-2.459-1.929-3.57-.943-.73-1.926-1.682-3.933-2.713 1.38.359 2.367.772 3.137 1.234-6.09-11.334-6.582-12.84-8.67-17.74z" }
                    }
                }
            }

            Image {   // silhueta/sombra do alien na cor do DNA
                id: shade
                anchors.centerIn: parent
                width: face.width * 0.66; height: width
                source: live.theme.art ? "file://" + live.theme.art : ""
                sourceSize: Qt.size(width * 2, height * 2)
                visible: false
            }
            MultiEffect {
                anchors.fill: shade
                source: shade
                visible: shade.source != "" && live.glassIn > 0
                opacity: 0.8 * live.glassIn
                scale: 0.6 + 0.4 * live.glassIn
                brightness: 1.0
                colorization: 1.0
                colorizationColor: live.primary
                shadowEnabled: true
                shadowColor: live.primary
                shadowBlur: 1.0
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
            }
        }

        // clique no símbolo abre o HUD
        Item {
            id: symbolHit
            anchors.fill: parent
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: symbol.scale = 1.02
                onExited: symbol.scale = 1.0
                onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/azmuth", "hud", "toggle"])
            }
        }
    }
}
