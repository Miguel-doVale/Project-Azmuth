// Project Azmuth — shell (Quickshell / QML): barra, Omnitrix HUD e widgets.
//
// Camada visual apenas: a lógica dos DNAs continua no core.py.
//   qs -p shell/                       sobe a shell (barra + HUD residente)
//   qs -p shell/ ipc call hud toggle   abre/fecha o disco
//   ... hud theme                      relê o theme.json (o core.py chama a cada DNA)
//   ... hud next | prev | confirm    gira / confirma
//   ... hud flash "#rrggbb"          onda de energia da transformação

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root

    property var roster: []
    property int index: 0
    property bool open: false
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: root.open ? 320 : 180; easing.type: Easing.OutCubic } }

    readonly property string azmuth: Quickshell.env("HOME") + "/.local/bin/azmuth"
    readonly property var current: roster.length ? roster[index] : null
    readonly property color accent: current && current.available ? current.color : "#5b6470"
    readonly property string archPath: "M11.39.605C10.376 3.092 9.764 4.72 8.635 7.132c.693.734 1.543 1.589 2.923 2.554-1.484-.61-2.496-1.224-3.252-1.86C6.86 10.842 4.596 15.138 0 23.395c3.612-2.085 6.412-3.37 9.021-3.862a6.61 6.61 0 01-.171-1.547l.003-.115c.058-2.315 1.261-4.095 2.687-3.973 1.426.12 2.534 2.096 2.478 4.409a6.52 6.52 0 01-.146 1.243c2.58.505 5.352 1.787 8.914 3.844-.702-1.293-1.33-2.459-1.929-3.57-.943-.73-1.926-1.682-3.933-2.713 1.38.359 2.367.772 3.137 1.234-6.09-11.334-6.582-12.84-8.67-17.74z"

    // DNA ativo (theme.json, escrito pelo core.py)
    property var theme: ({ id: "neutral", name: "Neutral", description: "", master: false, bar: true,
                           primary: "#38bdf8", secondary: "#89b4fa", background: "#0b0f19",
                           foreground: "#cdd6f4", border_active: "#38bdf8", border_inactive: "#1e293b" })
    FileView {
        id: themeFile
        path: Quickshell.env("HOME") + "/.local/state/azmuth/theme.json"
        onLoaded: {
            try { root.theme = JSON.parse(text()) } catch (e) { console.warn("theme.json inválido:", e) }
            Energy.t = root.theme.timer || ({})
        }
    }

    Variants {
        model: Quickshell.screens
        Bar {
            theme: root.theme
            shell: root
        }
    }

    Variants {
        model: Quickshell.screens
        LiveDesktop { theme: root.theme; hudOpen: root.open }
    }

    Variants {
        model: Quickshell.screens
        Widgets { theme: root.theme }
    }

    Constellation {
        id: constellation
        theme: root.theme
        screen: root.targetScreen()
    }

    Notifications {
        id: notifs
        theme: root.theme
        screen: root.targetScreen()
    }

    Launcher {
        id: launcher
        theme: root.theme
        screen: root.targetScreen()
    }

    Lock {
        id: lockScreen
        theme: root.theme
        screen: root.targetScreen()
    }

    PowerMenu {
        id: powerMenu
        theme: root.theme
        screen: root.targetScreen()
    }

    Clipboard {
        id: clipboard
        theme: root.theme
        screen: root.targetScreen()
    }

    Dashboard {
        id: dashboard
        theme: root.theme
        notifications: notifs
        screen: root.targetScreen()
    }

    property color flashColor: "#38bdf8"
    property int flashTick: 0

    function asset(name) {
        return decodeURIComponent(Qt.resolvedUrl("../assets/sounds/" + name + ".wav").toString().replace("file://", ""))
    }
    function play(name) { Quickshell.execDetached(["pw-play", asset(name)]) }

    function show() {
        rosterProc.running = true
    }
    function close() { open = false }
    function rotate(step) {
        if (!open || !roster.length) return
        index = (index + step + roster.length) % roster.length
        play("tick")
    }
    function confirm() {
        if (!open || !current) return
        if (!current.available) {
            shake.restart()
            play("error")
            return
        }
        const id = current.id
        open = false
        if (!current.current)
            Quickshell.execDetached([azmuth, "apply", id])
    }
    function jumpToKey(k) {
        for (let i = 0; i < roster.length; i++)
            if (roster[i].key === k) { index = i; play("tick"); return }
    }

    function targetScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
        for (let i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
        return Quickshell.screens[0]
    }

    Process {
        id: rosterProc
        command: [root.azmuth, "roster"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.roster = JSON.parse(this.text) } catch (e) { console.warn("roster inválido:", e); return }
                let cur = 0
                for (let i = 0; i < root.roster.length; i++) if (root.roster[i].current) cur = i
                root.index = cur
                hud.screen = root.targetScreen()
                root.open = true
                root.play("hud_open")
            }
        }
    }

    IpcHandler {
        target: "hud"
        function toggle(): void { root.open ? root.close() : root.show() }
        function next(): void { root.rotate(1) }
        function prev(): void { root.rotate(-1) }
        function confirm(): void { root.confirm() }
        function theme(): void { themeFile.reload() }
        function dashboard(): void { dashboard.screen = root.targetScreen(); dashboard.toggle(0) }
        function altTab(): void { if (!constellation.open) constellation.screen = root.targetScreen(); constellation.altTab(1) }
        function altTabPrev(): void { if (!constellation.open) constellation.screen = root.targetScreen(); constellation.altTab(-1) }
        function altRelease(): void { constellation.altRelease() }
        function overview(): void { if (!constellation.open) constellation.screen = root.targetScreen(); constellation.overview() }
        function launcher(): void { launcher.screen = root.targetScreen(); launcher.toggle() }
        function lock(): void { lockScreen.lock() }
        function lockPreview(): void { lockScreen.screen = root.targetScreen(); lockScreen.preview() }
        function power(): void { powerMenu.screen = root.targetScreen(); powerMenu.toggle() }
        function clipboard(): void { clipboard.screen = root.targetScreen(); clipboard.toggle() }
        function config(): void { dashboard.screen = root.targetScreen(); dashboard.toggle(1) }
        function flash(color: string): void {
            root.flashColor = color
            root.flashTick++
        }
    }

    // ───────────────────────── disco do Omnitrix ─────────────────────────
    PanelWindow {
        id: hud
        visible: root.open || root.reveal > 0.01
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "azmuth-hud"
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.8 * root.reveal
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
            onWheel: wheel => root.rotate(wheel.angleDelta.y < 0 ? 1 : -1)
        }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Right: case Qt.Key_Down: case Qt.Key_Tab: root.rotate(1); break
                case Qt.Key_Left: case Qt.Key_Up: case Qt.Key_Backtab: root.rotate(-1); break
                case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: root.confirm(); break
                case Qt.Key_Escape: root.close(); break
                default:
                    if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) root.jumpToKey(event.key - Qt.Key_0)
                    else return
                }
                event.accepted = true
            }
        }

        Item {
            id: disc
            readonly property real size: Math.min(parent.width, parent.height) * 0.62
            width: size; height: size
            anchors.centerIn: parent
            // nasce do Omnitrix da área de trabalho: mesmo centro, começa do tamanho dele
            scale: 0.87 + 0.13 * root.reveal
            opacity: root.reveal
            rotation: (1 - root.reveal) * -25   // o core "gira para fora" ao abrir

            SequentialAnimation {
                id: shake
                NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: -14; duration: 45 }
                NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
                NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: -6; duration: 60 }
                NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
            }

            // halo
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.06; height: width; radius: width / 2
                color: "transparent"
                border.width: parent.width * 0.05
                border.color: Qt.alpha(root.accent, 0.18)
                Behavior on border.color { ColorAnimation { duration: 220 } }
            }

            // aro externo (bezel)
            Rectangle {
                id: bezel
                anchors.fill: parent
                radius: width / 2
                color: "#15181b"
                border.width: 3
                border.color: Qt.alpha(root.accent, 0.55)
                Behavior on border.color { ColorAnimation { duration: 220 } }

                Repeater {   // 4 garras do relógio
                    model: 4
                    Rectangle {
                        required property int index
                        readonly property real a: (45 + 90 * index) * Math.PI / 180
                        width: bezel.width * 0.09; height: bezel.width * 0.035; radius: height / 2
                        color: "#2a2f35"
                        x: bezel.width / 2 + Math.cos(a) * bezel.width * 0.465 - width / 2
                        y: bezel.height / 2 + Math.sin(a) * bezel.height * 0.465 - height / 2
                        rotation: 45 + 90 * index + 90
                    }
                }
            }

            // marcador do slot selecionado (topo)
            Shape {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -parent.height * 0.035
                width: parent.width * 0.06; height: width * 0.7
                ShapePath {
                    strokeWidth: 0
                    fillColor: root.accent
                    startX: 0; startY: 0
                    PathLine { x: disc.width * 0.06; y: 0 }
                    PathLine { x: disc.width * 0.03; y: disc.width * 0.042 }
                    PathLine { x: 0; y: 0 }
                }
            }

            // anel giratório com os DNAs
            Item {
                id: dial
                anchors.fill: parent
                readonly property real step: root.roster.length ? 360 / root.roster.length : 36
                rotation: -root.index * step
                Behavior on rotation { RotationAnimation { direction: RotationAnimation.Shortest; duration: 280; easing.type: Easing.OutBack } }

                Repeater {
                    model: root.roster
                    Item {
                        id: slot
                        required property var modelData
                        required property int index
                        readonly property real a: index * dial.step * Math.PI / 180
                        readonly property bool selected: index === root.index
                        readonly property real r: disc.width * 0.405
                        width: disc.width * 0.13; height: width
                        x: disc.width / 2 + Math.sin(a) * r - width / 2
                        y: disc.height / 2 - Math.cos(a) * r - height / 2

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: slot.selected ? Qt.alpha(slot.modelData.color || "#5b6470", 0.25) : "#0d0f11"
                            border.width: slot.selected ? 3 : 1.5
                            border.color: slot.modelData.available ? (slot.modelData.color || "#5b6470") : "#3a4048"
                            scale: slot.selected ? 1.12 : 1
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                            Shape {   // Neutral: logo do Arch
                                id: slotArch
                                visible: slot.modelData.key === null
                                anchors.centerIn: parent
                                rotation: -dial.rotation
                                width: parent.width * 0.48; height: width
                                ShapePath {
                                    strokeWidth: 0
                                    fillColor: slot.modelData.color || "#38bdf8"
                                    scale: Qt.size(slotArch.width / 24, slotArch.height / 24)
                                    PathSvg { path: root.archPath }
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: slot.modelData.key !== null
                                rotation: -dial.rotation
                                text: slot.modelData.available ? String(slot.modelData.key) : ""
                                font.family: slot.modelData.available && slot.modelData.key !== null ? "Orbitron" : "Font Awesome 7 Free"
                                font.styleName: slot.modelData.available && slot.modelData.key !== null ? "" : "Solid"
                                font.pixelSize: parent.width * 0.36
                                font.weight: Font.Black
                                color: slot.modelData.available ? (slot.modelData.color || "#cdd6f4") : "#4a525c"
                            }
                        }
                    }
                }
            }

            // face do relógio
            Rectangle {
                id: face
                anchors.centerIn: parent
                width: parent.width * 0.58; height: width; radius: width / 2
                color: "#07090b"
                border.width: 5
                border.color: root.accent
                Behavior on border.color { ColorAnimation { duration: 220 } }

                // ampulheta do Omnitrix
                Shape {
                    id: hourglass
                    anchors.fill: parent
                    visible: root.current && root.current.key !== null
                    opacity: root.current && root.current.available ? 1 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    readonly property real f: face.width
                    // "ativação" (1ª transformação do Ben): as pontas avançam uma sobre a
                    // outra e se cruzam, abrindo espaço para o alien aparecer no meio
                    property real cross: 0
                    readonly property real tip: cross * 0.24
                    SequentialAnimation {
                        id: crossIn
                        PauseAnimation { duration: 180 }
                        NumberAnimation { target: hourglass; property: "cross"; to: 1; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                    }
                    Connections {
                        target: root
                        function onOpenChanged() {
                            if (root.open) { hourglass.cross = 0; crossIn.restart() }
                            else { crossIn.stop(); hourglass.cross = 0 }
                        }
                    }
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: Qt.alpha(root.accent, hourglass.cross)
                        fillColor: Qt.alpha(root.accent, 1 - 0.72 * hourglass.cross)
                        joinStyle: ShapePath.MiterJoin
                        startX: hourglass.f * 0.22; startY: hourglass.f * 0.12
                        PathLine { x: hourglass.f * 0.78; y: hourglass.f * 0.12 }
                        PathLine { x: hourglass.f * 0.84; y: hourglass.f * 0.17 }
                        PathLine { x: hourglass.f * 0.5;  y: hourglass.f * (0.485 + hourglass.tip) }
                        PathLine { x: hourglass.f * 0.16; y: hourglass.f * 0.17 }
                        PathLine { x: hourglass.f * 0.22; y: hourglass.f * 0.12 }
                    }
                    ShapePath {
                        strokeWidth: 3
                        strokeColor: Qt.alpha(root.accent, hourglass.cross)
                        fillColor: Qt.alpha(root.accent, 1 - 0.72 * hourglass.cross)
                        joinStyle: ShapePath.MiterJoin
                        startX: hourglass.f * 0.22; startY: hourglass.f * 0.88
                        PathLine { x: hourglass.f * 0.78; y: hourglass.f * 0.88 }
                        PathLine { x: hourglass.f * 0.84; y: hourglass.f * 0.83 }
                        PathLine { x: hourglass.f * 0.5;  y: hourglass.f * (0.515 - hourglass.tip) }
                        PathLine { x: hourglass.f * 0.16; y: hourglass.f * 0.83 }
                        PathLine { x: hourglass.f * 0.22; y: hourglass.f * 0.88 }
                    }
                }

                // core Arch (estado Neutral)
                Shape {
                    id: arch
                    visible: root.current && root.current.key === null
                    anchors.centerIn: parent
                    width: face.width * 0.56; height: width
                    ShapePath {
                        strokeWidth: 0
                        fillColor: root.accent
                        scale: Qt.size(arch.width / 24, arch.height / 24)
                        PathSvg { path: root.archPath }
                    }
                }

                // holograma do alien (hud.art do DNA) sobre a ampulheta esmaecida
                Image {
                    id: alienArt
                    anchors.centerIn: parent
                    width: face.width * 0.7; height: width
                    source: root.current && root.current.art ? "file://" + root.current.art : ""
                    sourceSize: Qt.size(width * 2, height * 2)
                    visible: source != ""
                    smooth: true
                    opacity: 0
                    scale: 0.85
                    onSourceChanged: { opacity = 0; scale = 0.85; artIn.restart() }
                    ParallelAnimation {
                        id: artIn
                        NumberAnimation { target: alienArt; property: "opacity"; to: 1; duration: 260; easing.type: Easing.OutCubic }
                        NumberAnimation { target: alienArt; property: "scale"; to: 1; duration: 320; easing.type: Easing.OutBack }
                    }
                }

                Text {   // cadeado sobre DNA bloqueado
                    anchors.centerIn: parent
                    visible: root.current && !root.current.available
                    text: ""
                    font.family: "Font Awesome 7 Free"
                    font.styleName: "Solid"
                    font.pixelSize: face.width * 0.2
                    color: "#c9d1d9"
                }
            }
        }

        // placa de identificação
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: disc.bottom
            anchors.topMargin: parent.height * 0.035
            spacing: 6
            opacity: root.reveal

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.current ? root.current.name.toUpperCase() : ""
                font.family: "Orbitron"
                font.pixelSize: 34
                font.weight: Font.Black
                font.letterSpacing: 4
                color: root.accent
                style: Text.Outline
                styleColor: Qt.alpha(root.accent, 0.25)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !root.current ? "" :
                      (!root.current.available ? "DNA BLOQUEADO — ainda não sequenciado"
                       : (root.current.current ? "DNA ATIVO · " : "") + root.current.description)
                font.family: "Rajdhani"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: "#c9d1d9"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 14
                text: "←/→ · scroll  girar      ENTER  transformar      0–9  slot      ESC  sair"
                font.family: "Rajdhani"
                font.pixelSize: 16
                font.letterSpacing: 1
                color: "#9aa4b0"
            }
        }
    }

    // ───────────────────── onda de energia da transformação ─────────────────────
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: flashWin
            required property var modelData
            screen: modelData
            visible: wave.running
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "azmuth-flash"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            mask: Region {}   // não captura clique nem teclado

            readonly property real diag: Math.sqrt(width * width + height * height)

            Connections {
                target: root
                function onFlashTickChanged() { wave.restart() }
            }

            Rectangle {   // clarão
                id: glow
                anchors.fill: parent
                color: root.flashColor
                opacity: 0
            }
            Rectangle {   // onda circular saindo do centro
                id: ring
                anchors.centerIn: parent
                width: 0; height: width; radius: width / 2
                color: Qt.alpha(root.flashColor, 0.35)
                border.width: 18
                border.color: root.flashColor
                opacity: 0
            }

            ParallelAnimation {
                id: wave
                NumberAnimation { target: ring; property: "width"; from: 40; to: flashWin.diag * 1.1; duration: 650; easing.type: Easing.OutCubic }
                NumberAnimation { target: ring; property: "opacity"; from: 0.95; to: 0; duration: 650; easing.type: Easing.InQuad }
                SequentialAnimation {
                    NumberAnimation { target: glow; property: "opacity"; from: 0; to: 0.45; duration: 90 }
                    NumberAnimation { target: glow; property: "opacity"; to: 0; duration: 420; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
