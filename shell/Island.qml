// Project Azmuth — ilha do Omnitrix (substitui a barra de cima). Uma instância, no monitor em foco.
// Fases: "peek" (só a pontinha do Omnitrix) → "hover" (mouse em cima) → "open" (painel) ·
// "line" (fio de luz quando há app maximizado/tela cheia). Não reserva espaço da tela; a máscara
// de entrada acompanha só o que está visível. Referência: docs/design/prototipo-ilha-dock.html.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import Quickshell.Services.UPower

PanelWindow {
    id: island

    required property var theme
    property var shell: null
    property var notifications: null
    property string phase: "peek"
    readonly property alias panelSlot: panelSlot
    readonly property alias panel: panelItem

    readonly property color primary: Colors.mode ? Colors.modeColor : (Energy.locked ? "#ff4d4d" : theme.primary)
    readonly property color bg: theme.background || "#0b0f19"
    readonly property color fg: theme.foreground || "#cdd6f4"
    readonly property bool detached: !theme.island || theme.island.detached !== false
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"

    // ── app maximizado ou em tela cheia neste monitor → fio ──
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    property int refreshTick: 0
    readonly property bool maximizedHere: {
        refreshTick
        const ws = monitor ? monitor.activeWorkspace : null
        if (!ws) return false
        return ws.toplevels.values.some(t => t.lastIpcObject && t.lastIpcObject.fullscreen > 0)
    }
    readonly property string restPhase: maximizedHere ? "line" : "peek"
    onRestPhaseChanged: if (phase === "peek" || phase === "line") phase = restPhase
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (["fullscreen", "activewindow", "activewindowv2", "workspace", "workspacev2", "openwindow",
                 "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "focusedmon"].includes(ev.name))
                refresh.restart()
        }
    }
    Timer { id: refresh; interval: 60; onTriggered: { Hyprland.refreshToplevels(); island.refreshTick++ } }
    Component.onCompleted: { Hyprland.refreshToplevels(); refreshTick++ }

    function openPanel() { leaveTimer.stop(); phase = "open" }
    property bool panelVisible: false
    property bool hoverVisible: false   // o texto da fase 2 fica até a moldura quase fechar (como o painel)
    onPhaseChanged: {
        if (phase === "open") { panelHide.stop(); panelVisible = true } else if (panelVisible) panelHide.restart()
        if (phase === "hover") { hoverHide.stop(); hoverVisible = true }
        else if (phase === "open") hoverVisible = false              // o painel entra no lugar
        else if (hoverVisible) hoverHide.restart()
    }
    Timer { id: hoverHide; interval: 300; onTriggered: island.hoverVisible = false }
    // a moldura já quase fechou: some o resto do conteúdo (antes ele ficava aparecendo dentro da pontinha)
    Timer { id: panelHide; interval: 240; onTriggered: island.panelVisible = false }
    function close() { phase = restPhase }
    function toggle() { phase === "open" ? close() : openPanel() }
    function run(cmd) { Quickshell.execDetached(cmd) }

    // ── janela ──
    anchors.top: true
    implicitWidth: 960
    implicitHeight: 620
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "azmuth-island"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: phase === "open" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        Region { item: hit }
        Region { item: wireZone }
    }
    HyprlandFocusGrab {
        windows: [island, panelItem.tray.popup]   // clicar no menu do 2º plano não fecha o painel
        active: island.phase === "open"
        onCleared: island.close()
    }

    // as medidas do protótipo são pixels físicos de uma tela 1920×1080; com escala fracionada (1.2)
    // a shell trabalha em pixels lógicos — k converte para a ilha ter o mesmo tamanho do protótipo
    readonly property real k: { const m = Hyprland.monitorFor(screen); const sc = m && m.lastIpcObject ? m.lastIpcObject.scale : 1; return sc > 0 ? 1 / sc : 1 }
    property real peekReach: 80          // no repouso, a área que abre a ilha vai além do Omnitrix, de cada lado (px)
    readonly property real pk: 1.15      // fases 2 e 3 um pouco maiores que o protótipo (pedido do Miguel)
    readonly property var dims: ({
        peek:  { w: 80 * k,  h: 22 * k,  y: 0 },
        hover: { w: 420 * pk * k, h: 64 * pk * k, y: detached ? 10 * k : 0 },
        open:  { w: 728 * pk * k, h: 466 * pk * k, y: detached ? 10 * k : 0 },
        line:  { w: 140 * k, h: 3,       y: 0 }
    })
    readonly property var cur: dims[phase] || dims.peek
    readonly property real cornerR: phase === "line" ? 3 : (phase === "open" ? 30 : 32) * pk * k

    // zona do fio: encostar no topo e ficar parado ~300 ms
    Item {
        id: wireZone
        width: island.phase === "line" ? 240 * island.k : 0; height: 3
        anchors.horizontalCenter: parent.horizontalCenter; y: 0
        HoverHandler {
            id: wireHover
            onHoveredChanged: hovered ? dwell.restart() : dwell.stop()
        }
        Timer { id: dwell; interval: 300; onTriggered: if (wireHover.hovered && island.phase === "line") island.phase = "hover" }
    }

    // área sensível: do topo da tela até o fim da ilha (cobre o vão da ilha solta — sem ela, o mouse
    // parado no vão fazia a ilha abrir e fechar sem parar). Usa o tamanho final, não o animado.
    Item {
        id: hit
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0; width: island.cur.w + (island.phase === "peek" ? 2 * island.peekReach : 0); height: island.phase === "line" ? 0 : island.cur.y + island.cur.h
        HoverHandler {
            id: shapeHover
            onHoveredChanged: {
                if (hovered) { leaveTimer.stop(); if (island.phase === "peek") island.phase = "hover" }
                else if (island.phase === "hover") leaveTimer.restart()
            }
        }
    }

    // neon em volta da ilha aberta (o box-shadow do protótipo): uma cópia da forma, embaixo,
    // só para projetar o brilho desfocado — a forma de verdade recorta o conteúdo e não pode ter sombra
    Rectangle {
        anchors.horizontalCenter: shape.horizontalCenter
        y: shape.y; width: shape.width; height: shape.height
        topLeftRadius: shape.topLeftRadius; topRightRadius: shape.topRightRadius
        bottomLeftRadius: shape.bottomLeftRadius; bottomRightRadius: shape.bottomRightRadius
        color: island.bg
        opacity: island.phase === "hover" || island.phase === "open" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: island.primary
            shadowOpacity: 0.42
            shadowBlur: 1.0
            blurMax: 48
            shadowVerticalOffset: 10 * island.k
            shadowHorizontalOffset: 0
        }
    }

    Rectangle {
        id: shape
        anchors.horizontalCenter: parent.horizontalCenter
        width: island.cur.w; height: island.cur.h; y: island.cur.y
        // o raio acompanha o tamanho animado: nunca maior que meia altura/largura, nunca reto no caminho
        readonly property real r: Math.min(island.cornerR, height / 2, width / 2)
        topLeftRadius: island.detached && island.phase !== "line" ? r : 0
        topRightRadius: topLeftRadius
        bottomLeftRadius: r; bottomRightRadius: r
        // o fundo só fica transparente depois que o conteúdo do painel sumiu (senão o texto "pisca" solto)
        color: island.phase === "peek" && panelSlot.opacity === 0 && hoverContent.opacity === 0 ? "transparent" : (island.phase === "line" && panelSlot.opacity === 0 && hoverContent.opacity === 0 ? island.primary : Qt.alpha(island.bg, 0.97))
        border.width: island.detached && (island.phase === "hover" || island.phase === "open") ? 1 : 0
        border.color: Qt.alpha(island.primary, 0.35)
        Behavior on width { NumberAnimation { duration: 550; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
        Behavior on height { NumberAnimation { duration: 550; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
        Behavior on y { NumberAnimation { duration: 550; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
        Behavior on color { ColorAnimation { duration: 300 } }
        // o conteúdo fica parado no centro e a moldura fecha por cima (nada "parte ao meio")
        clip: island.phase !== "peek" || panelSlot.opacity > 0 || hoverContent.opacity > 0   // recorta até o conteúdo sumir de vez
        TapHandler {
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onTapped: (point, button) => {
                if (button === Qt.RightButton) island.run([island.az, "random"])
                else if (button === Qt.MiddleButton) island.run([island.az, "master", "toggle"])
                else if (island.phase === "hover" || island.phase === "peek") island.openPanel()
            }
        }

        // ── Omnitrix (em todas as fases) ──
        OmnitrixMark {
            id: omni
            anchors.horizontalCenter: parent.horizontalCenter
            size: (island.phase === "open" ? 46 * island.pk : (island.phase === "hover" ? 40 * island.pk : 54)) * island.k
            y: (island.phase === "peek" ? -34 : (island.phase === "hover" ? 12 * island.pk : (island.phase === "open" ? 14 * island.pk : -60))) * island.k
            opacity: island.phase === "line" ? 0 : 1
            color: island.primary; bg: island.bg
            ring: island.phase === "hover"
            master: island.theme.master === true
            Behavior on y { NumberAnimation { duration: 550; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } }
            Behavior on size { NumberAnimation { duration: 550; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }

        // recorte ARREDONDADO do conteúdo (o clip do Item é retangular: no meio do fechamento os cartões
        // encostavam nos cantos e a ilha parecia quadrada)
        ClippingRectangle {
            anchors.fill: parent
            radius: shape.r
            color: "transparent"
            // ── fase 2: DNA · energia | hora · data · bateria ──
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 420; height: 64
                transform: Scale { origin.x: 210; origin.y: 0; xScale: island.k * island.pk; yScale: island.k * island.pk }
                id: hoverContent
                opacity: island.hoverVisible ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: island.hoverVisible ? 300 : (island.phase === "open" ? 90 : 140) } }
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 36; anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {   // nomes longos (MASSA CINZENTA) encolhem em vez de invadir o Omnitrix
                        width: 128; height: 16
                        text: (island.theme.name || "").toUpperCase()
                        font.family: "Orbitron"; font.weight: Font.Medium; font.pixelSize: 13
                        font.letterSpacing: text.length > 9 ? 1 : 2.5
                        fontSizeMode: Text.HorizontalFit; minimumPixelSize: 8; elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter; color: island.fg
                    }
                    Text { text: Energy.enabled ? Energy.percent + "%" : "∞"; font.family: "Orbitron"; font.pixelSize: 10; font.letterSpacing: 1; color: island.primary }
                }
                Column {
                    anchors.right: parent.right; anchors.rightMargin: 36; anchors.verticalCenter: parent.verticalCenter
                    spacing: 5
                    Text { anchors.right: parent.right; text: Qt.formatTime(clock.date, "hh:mm"); font.family: "Orbitron"; font.weight: Font.Medium; font.pixelSize: 16; font.letterSpacing: 1; color: island.fg }
                    Text {
                        anchors.right: parent.right
                        readonly property var dev: UPower.displayDevice
                        readonly property int pct: dev ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 0
                        text: Qt.locale("pt_BR").toString(clock.date, "ddd d").replace(".", "").toUpperCase() + (dev && dev.isPresent ? " · " + pct + "%" : "")
                        font.family: "Orbitron"; font.pixelSize: 9; font.letterSpacing: 1.5; color: Qt.alpha(island.fg, 0.45)
                    }
                }
            }

            // ── fase 3: o painel entra aqui (IslandPanel) ──
            Item {
                id: panelSlot
                anchors.horizontalCenter: parent.horizontalCenter
                width: 728; height: 466
                transform: Scale { origin.x: 364; origin.y: 0; xScale: island.k * island.pk; yScale: island.k * island.pk }
                // ao fechar, o conteúdo NÃO esmaece: fica visível e a moldura recolhe por cima dele
                opacity: island.panelVisible ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: island.panelVisible ? 350 : 120 } }
                IslandPanel {
                    id: panelItem
                    theme: island.theme
                    notifications: island.notifications
                    active: island.phase === "open"
                    onCloseRequested: island.close()
                    onOpenCentral: tab => { island.close(); if (island.shell) island.shell.openConfig(tab) }
                    onQuickEvent: day => { if (island.shell) island.shell.quickEvent(day) }
                }
            }

        }

        Item {   // Esc fecha
            focus: island.phase === "open"
            Keys.onEscapePressed: island.close()
        }
    }

    Timer { id: leaveTimer; interval: 350; onTriggered: if (island.phase === "hover" && !shapeHover.hovered) island.phase = island.restPhase }
    SystemClock { id: clock; precision: SystemClock.Minutes }
}
