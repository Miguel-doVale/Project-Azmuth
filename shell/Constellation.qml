// Project Azmuth — Constelação: Alt+Tab / visão geral 3D dos workspaces.
//
// Cada workspace é um nó num anel 3D; as janelas orbitam o nó como miniaturas
// AO VIVO (screencopy). Projeção em perspectiva feita aqui mesmo (sem Qt3D).
//
//   Alt+Tab (segurando Alt)   próxima janela por uso recente; soltar Alt = ir
//   Alt+Tab rápido            alterna direto para a última janela (sem abrir)
//   Super+Tab                 modo exploração: arrastar gira, scroll = zoom,
//                             ←/→ janela, ↑/↓ workspace, Enter/clique entra

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: cst

    required property var theme
    readonly property color primary: theme.primary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground

    property bool open: false
    property bool altMode: false          // aberto pelo Alt+Tab (soltar Alt confirma)
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: cst.open ? 300 : 160; easing.type: Easing.OutCubic } }

    // ── câmera ──
    property real yaw: 0
    property real pitch: 0.3
    property real dist: 1050
    readonly property real focal: 950
    Behavior on yaw { enabled: !drag.pressed; NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
    Behavior on dist { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // ── cena ──
    property var nodes: []     // [{ws, id, x, y, z, theta}]
    property var wins: []      // [{top, ws, node, x, y, z, mru}]
    property var targets: []   // wins ordenadas por uso recente (MRU)
    property int sel: 0        // índice em targets (janela selecionada)
    property int selNode: -1   // >=0 quando um workspace (nó) está selecionado
    property real releaseTs: 0

    visible: open || reveal > 0.01
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function build() {
        Hyprland.refreshToplevels()
        const wsList = Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)
        const n = Math.max(1, wsList.length)
        const R = Math.max(430, 150 * n)
        const ns = [], ws = []
        wsList.forEach((w, i) => {
            const th = 2 * Math.PI * i / n
            const node = { ws: w, id: w.id, theta: th, x: R * Math.sin(th), y: (i % 2 ? -1 : 1) * 46, z: R * Math.cos(th) }
            ns.push(node)
            const tops = w.toplevels.values
            tops.forEach((t, j) => {
                const phi = th + 2 * Math.PI * j / Math.max(1, tops.length) + 0.6
                const r = tops.length > 1 ? 240 : 0
                ws.push({ top: t, ws: w, node: i,
                          x: node.x + r * Math.cos(phi), y: node.y - 250 + r * 0.25 * Math.sin(phi), z: node.z + r * Math.sin(phi),
                          mru: t.lastIpcObject && t.lastIpcObject.focusHistoryID !== undefined ? t.lastIpcObject.focusHistoryID : 99 })
            })
        })
        nodes = ns
        wins = ws
        targets = ws.slice().sort((a, b) => a.mru - b.mru)
    }
    function frontYaw(theta) {   // yaw que traz o nó para a frente, pelo caminho mais curto
        let t = theta + Math.PI
        while (t - yaw > Math.PI) t -= 2 * Math.PI
        while (t - yaw < -Math.PI) t += 2 * Math.PI
        return t
    }
    function focusSel() {
        const node = selNode >= 0 ? nodes[selNode] : (targets[sel] ? nodes[targets[sel].node] : null)
        if (node) yaw = frontYaw(node.theta)
        edges.requestPaint()
    }
    function show(mode, startAt) {
        build()
        altMode = mode === "alt"
        selNode = -1
        sel = Math.min(startAt, Math.max(0, targets.length - 1))
        if (!targets.length && nodes.length) selNode = 0
        dist = 1050
        focusSel()
        open = true
        keys.forceActiveFocus()
    }
    function step(d) {
        if (!targets.length) return
        selNode = -1
        sel = (sel + d + targets.length) % targets.length
        focusSel()
    }
    function stepNode(d) {
        if (!nodes.length) return
        const cur = selNode >= 0 ? selNode : (targets[sel] ? targets[sel].node : 0)
        selNode = (cur + d + nodes.length) % nodes.length
        focusSel()
    }
    // fecha primeiro e ativa depois: se ativar com a camada ainda aberta, o
    // Hyprland devolve o foco para a janela anterior quando a camada some
    property var pending: null
    function confirm() {
        pending = selNode >= 0 && nodes[selNode] ? { ws: nodes[selNode].ws }
                : (targets[sel] ? { top: targets[sel].top } : null)
        open = false
        activateLater.restart()
    }
    Timer {
        id: activateLater
        interval: 90
        onTriggered: {
            const p = cst.pending
            cst.pending = null
            if (!p) return
            if (p.ws) p.ws.activate()
            else if (p.top && p.top.wayland) p.top.wayland.activate()
        }
    }
    // chamados pelo IPC (atalhos no azmuth.lua)
    function altTab(d) {
        if (open) { step(d); return }
        if (Date.now() - releaseTs < 400) {   // toque rápido: Alt já foi solto
            build()
            const t = targets[d > 0 ? 1 : targets.length - 1]
            if (t && t.top.wayland) t.top.wayland.activate()
            return
        }
        show("alt", d > 0 ? 1 : targets.length - 1)
    }
    function altRelease() {
        if (open && altMode) confirm()
        else releaseTs = Date.now()
    }
    function overview() { open ? (open = false) : show("explore", 0) }

    function project(x, y, z) {
        const cy = Math.cos(yaw), sy = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch)
        const x1 = x * cy - z * sy, z1 = x * sy + z * cy
        const y2 = y * cp - z1 * sp, z2 = y * sp + z1 * cp
        const depth = Math.max(80, z2 + dist)
        const s = focal / depth
        return { x: width / 2 + x1 * s, y: height / 2 + 90 + y2 * s, s: s, depth: depth }
    }

    // ───────────────────────── fundo ─────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.92 * cst.reveal
    }
    Repeater {   // poeira estelar
        model: 90
        Rectangle {
            required property int index
            readonly property real rx: (Math.sin(index * 12.9898) * 43758.5453) % 1
            readonly property real ry: (Math.sin(index * 78.233) * 12345.678) % 1
            x: Math.abs(rx) * cst.width; y: Math.abs(ry) * cst.height
            width: index % 7 ? 2 : 3; height: width; radius: width / 2
            color: index % 5 ? "#ffffff" : cst.primary
            opacity: cst.reveal * (0.15 + 0.35 * Math.abs(Math.sin(index)))
            SequentialAnimation on opacity {
                running: cst.open && parent.index % 3 === 0; loops: Animation.Infinite
                NumberAnimation { to: 0.05; duration: 1200 + parent.index * 13 }
                NumberAnimation { to: 0.5; duration: 1200 + parent.index * 13 }
            }
        }
    }

    // arrastar gira, scroll aproxima, clique no vazio fecha
    MouseArea {
        id: drag
        anchors.fill: parent
        property real lx: 0
        property real ly: 0
        property bool moved: false
        onPressed: mouse => { lx = mouse.x; ly = mouse.y; moved = false }
        onPositionChanged: mouse => {
            if (!pressed) return
            cst.yaw += (mouse.x - lx) * 0.006
            cst.pitch = Math.max(-0.2, Math.min(1.1, cst.pitch + (mouse.y - ly) * 0.004))
            if (Math.abs(mouse.x - lx) + Math.abs(mouse.y - ly) > 2) moved = true
            lx = mouse.x; ly = mouse.y
            edges.requestPaint()
        }
        onReleased: if (!moved) cst.open = false
        onWheel: wheel => { cst.dist = Math.max(650, Math.min(2600, cst.dist - wheel.angleDelta.y * 1.2)); edges.requestPaint() }
    }

    // ligações (anel entre workspaces + nó → janelas)
    Canvas {
        id: edges
        anchors.fill: parent
        opacity: cst.reveal
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const ns = cst.nodes.map(n => cst.project(n.x, n.y, n.z))
            ctx.lineWidth = 1.6
            for (let i = 0; i < ns.length && ns.length > 1; i++) {
                const a = ns[i], b = ns[(i + 1) % ns.length]
                ctx.strokeStyle = Qt.alpha(cst.primary, 0.12 + 0.35 * Math.min(1, (a.s + b.s)))
                ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke()
            }
            ctx.setLineDash([4, 6])
            ctx.lineWidth = 1
            cst.wins.forEach(w => {
                const a = ns[w.node], b = cst.project(w.x, w.y, w.z)
                ctx.strokeStyle = Qt.alpha(cst.primary, 0.1 + 0.3 * b.s)
                ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke()
            })
        }
        Connections {
            target: cst
            function onYawChanged() { edges.requestPaint() }
            function onDistChanged() { edges.requestPaint() }
            function onNodesChanged() { edges.requestPaint() }
        }
    }

    // ───────────────────────── nós (workspaces) ─────────────────────────
    Repeater {
        model: cst.nodes
        Item {
            id: nd
            required property var modelData
            required property int index
            readonly property var p: cst.project(modelData.x, modelData.y, modelData.z)
            readonly property bool picked: cst.selNode === index
            readonly property bool current: modelData.ws.focused
            readonly property real size: 76 * p.s
            x: p.x - size / 2; y: p.y - size / 2
            width: size; height: size
            z: 10000 - p.depth
            opacity: cst.reveal * Math.min(1, 0.35 + p.s)

            Rectangle {   // halo
                anchors.centerIn: parent
                width: parent.width * 1.9; height: width; radius: width / 2
                color: Qt.alpha(cst.primary, nd.picked ? 0.28 : 0.1)
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: nd.picked ? cst.primary : "#0c0f11"
                border.width: Math.max(2, 3 * nd.p.s)
                border.color: cst.primary
                SequentialAnimation on scale {
                    running: nd.current && cst.open; loops: Animation.Infinite
                    NumberAnimation { to: 1.08; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
                Text {
                    anchors.centerIn: parent
                    text: nd.modelData.id
                    font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: Math.max(10, 24 * nd.p.s)
                    color: nd.picked ? cst.bg : cst.primary
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: { cst.selNode = nd.index; edges.requestPaint() }
                onClicked: { cst.selNode = nd.index; cst.confirm() }
            }
        }
    }

    // ───────────────────────── janelas (miniaturas ao vivo) ─────────────────────────
    Repeater {
        model: cst.wins
        Item {
            id: wn
            required property var modelData
            readonly property var p: cst.project(modelData.x, modelData.y, modelData.z)
            readonly property int ti: cst.targets.indexOf(modelData)
            readonly property bool picked: cst.selNode < 0 && cst.sel === ti
            property real w: 360 * Math.min(p.s, 0.95) * (picked ? 1.12 : 1)
            readonly property real aspect: cap.hasContent && cap.sourceSize.width > 0 ? cap.sourceSize.height / cap.sourceSize.width : 0.62
            Behavior on w { NumberAnimation { duration: 180 } }
            width: w
            height: w * aspect + 22
            x: p.x - width / 2; y: p.y - height / 2
            z: 10000 - p.depth + (picked ? 500 : 0)
            opacity: cst.reveal * Math.min(1, 0.3 + p.s * (picked ? 1.4 : 1))

            Rectangle {
                id: frame
                width: parent.width; height: parent.width * wn.aspect
                radius: 6
                color: "#0c0f11"
                border.width: wn.picked ? 3 : 1
                border.color: wn.picked ? cst.primary : Qt.alpha(cst.primary, 0.35)
                clip: true
                ScreencopyView {
                    id: cap
                    anchors.fill: parent
                    anchors.margins: frame.border.width
                    captureSource: cst.open && wn.modelData.top.wayland ? wn.modelData.top.wayland : null
                    live: true
                }
            }
            Text {
                anchors.top: frame.bottom; anchors.topMargin: 4
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: wn.modelData.top.title
                font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: Math.max(10, 15 * wn.p.s)
                color: wn.picked ? cst.primary : Qt.alpha(cst.fg, 0.75)
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: { if (wn.ti >= 0) { cst.selNode = -1; cst.sel = wn.ti } }
                onClicked: { cst.selNode = -1; cst.sel = wn.ti; cst.confirm() }
            }
        }
    }

    // ───────────────────────── teclado + rodapé ─────────────────────────
    Item {
        id: keys
        anchors.fill: parent
        focus: cst.open
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Tab: case Qt.Key_Right: cst.step(1); break
            case Qt.Key_Backtab: case Qt.Key_Left: cst.step(-1); break
            case Qt.Key_Down: cst.stepNode(1); break
            case Qt.Key_Up: cst.stepNode(-1); break
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: cst.confirm(); break
            case Qt.Key_Escape: cst.open = false; break
            default: return
            }
            event.accepted = true
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt && cst.altMode && cst.open) { cst.confirm(); event.accepted = true }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 34
        spacing: 6
        opacity: cst.reveal
        z: 20000
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property var t: cst.selNode >= 0 ? null : cst.targets[cst.sel]
            text: cst.selNode >= 0 && cst.nodes[cst.selNode] ? "WORKSPACE " + cst.nodes[cst.selNode].id
                  : (t ? (t.top.wayland ? t.top.wayland.appId : "") + "  ·  workspace " + t.ws.id : "")
            font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 15; font.letterSpacing: 2
            color: cst.primary
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: cst.altMode ? "TAB próxima · SHIFT+TAB anterior · solte ALT para ir"
                              : "arrastar gira · scroll zoom · ←/→ janela · ↑/↓ workspace · ENTER entra · ESC sai"
            font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15; font.letterSpacing: 1
            color: Qt.alpha(cst.fg, 0.6)
        }
    }
}
