// Project Azmuth — menu de energia (Super + Shift + Q), no estilo do Omnitrix.
// Ações irreversíveis (sair, reiniciar, desligar) têm contagem de 3 s cancelável.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

PanelWindow {
    id: pm

    required property var theme
    readonly property color primary: theme.primary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property color danger: "#ff5a5a"
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"

    property bool open: false
    property int index: 0
    property int countdown: -1        // >= 0 durante a contagem
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: pm.open ? 300 : 160; easing.type: Easing.OutCubic } }

    readonly property var actions: [
        { key: "B", name: "BLOQUEAR",  icon: "", risky: false, cmd: [az, "lock"] },
        { key: "S", name: "SUSPENDER", icon: "", risky: false, cmd: ["systemctl", "suspend"] },
        { key: "E", name: "SAIR",      icon: "", risky: true,  cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { key: "R", name: "REINICIAR", icon: "", risky: true,  cmd: ["systemctl", "reboot"] },
        { key: "D", name: "DESLIGAR",  icon: "", risky: true,  cmd: ["systemctl", "poweroff"] }
    ]
    readonly property var current: actions[index]

    function toggle() {
        if (open) { close(); return }
        index = 0
        countdown = -1
        uptimeFile.reload()
        open = true
        keys.forceActiveFocus()
        play("hud_open")
    }
    function close() { countdown = -1; tick.stop(); open = false }
    function play(n) {
        Quickshell.execDetached(["pw-play", decodeURIComponent(Qt.resolvedUrl("../assets/sounds/" + n + ".wav").toString().replace("file://", ""))])
    }
    function rotate(d) { if (countdown < 0) { index = (index + d + actions.length) % actions.length; play("tick") } }
    function confirm() {
        if (countdown >= 0) return
        if (current.risky) { countdown = 3; play("beep"); tick.restart() }
        else run()
    }
    function run() {
        const cmd = current.cmd
        close()
        Quickshell.execDetached(cmd)
    }
    Timer {
        id: tick
        interval: 1000; repeat: true
        onTriggered: {
            pm.countdown--
            if (pm.countdown <= 0) { stop(); pm.run() } else pm.play("beep")
        }
    }

    // tempo ligado
    FileView { id: uptimeFile; path: "/proc/uptime" }
    readonly property string uptime: {
        const s = parseFloat((uptimeFile.text() || "0").split(" ")[0])
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return (d ? d + "d " : "") + h + "h " + String(m).padStart(2, "0") + "m"
    }

    visible: open || reveal > 0.01
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-power"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.75 * pm.reveal
    }
    MouseArea {
        anchors.fill: parent
        onClicked: pm.close()
        onWheel: wheel => pm.rotate(wheel.angleDelta.y < 0 ? 1 : -1)
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: pm.open
        Keys.onPressed: event => {
            const k = event.key
            if (k === Qt.Key_Escape) { pm.countdown >= 0 ? (pm.countdown = -1, tick.stop()) : pm.close() }
            else if (k === Qt.Key_Right || k === Qt.Key_Down || k === Qt.Key_Tab) pm.rotate(1)
            else if (k === Qt.Key_Left || k === Qt.Key_Up || k === Qt.Key_Backtab) pm.rotate(-1)
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) pm.confirm()
            else if (k >= Qt.Key_1 && k <= Qt.Key_5) { pm.index = k - Qt.Key_1; pm.confirm() }
            else {
                const i = pm.actions.findIndex(a => event.text && a.key === event.text.toUpperCase())
                if (i < 0) return
                pm.index = i; pm.confirm()
            }
            event.accepted = true
        }
    }

    Item {
        id: dial
        readonly property real size: Math.min(parent.width, parent.height) * 0.56
        width: size; height: size
        anchors.centerIn: parent
        scale: 0.8 + 0.2 * pm.reveal
        opacity: pm.reveal
        readonly property color accent: pm.current.risky ? pm.danger : pm.primary

        Rectangle {   // aro
            anchors.fill: parent
            radius: width / 2
            color: "#12151a"
            border.width: 3
            border.color: Qt.alpha(dial.accent, 0.5)
        }

        // ações no anel
        Repeater {
            model: pm.actions
            Item {
                id: btn
                required property var modelData
                required property int index
                readonly property real a: (index / pm.actions.length) * 2 * Math.PI - Math.PI / 2
                readonly property bool sel: pm.index === index
                readonly property color tint: modelData.risky ? pm.danger : pm.primary
                width: dial.size * 0.2; height: width
                x: dial.size / 2 + Math.cos(a) * dial.size * 0.39 - width / 2
                y: dial.size / 2 + Math.sin(a) * dial.size * 0.39 - height / 2
                scale: sel ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: btn.sel ? Qt.alpha(btn.tint, 0.22) : "#0c0f11"
                    border.width: btn.sel ? 3 : 1.5
                    border.color: btn.sel ? btn.tint : Qt.alpha(btn.tint, 0.45)
                }
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -parent.height * 0.08
                    text: btn.modelData.icon
                    font.family: "Font Awesome 7 Free"; font.styleName: "Solid"
                    font.pixelSize: parent.width * 0.3
                    color: btn.sel ? btn.tint : Qt.alpha(pm.fg, 0.8)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.14
                    text: (btn.index + 1) + " · " + btn.modelData.key
                    font.family: "Orbitron"; font.pixelSize: Math.max(9, parent.width * 0.1)
                    color: Qt.alpha(pm.fg, 0.5)
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: if (pm.countdown < 0) pm.index = btn.index
                    onClicked: { pm.index = btn.index; pm.confirm() }
                }
            }
        }

        // centro: Omnitrix com a ação
        Rectangle {
            id: face
            anchors.centerIn: parent
            width: dial.size * 0.46; height: width; radius: width / 2
            color: "#07090b"
            border.width: 4
            border.color: dial.accent

            // anel da contagem regressiva
            Shape {
                anchors.fill: parent
                visible: pm.countdown >= 0
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: pm.danger; strokeWidth: 6; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: face.width / 2; centerY: face.height / 2
                        radiusX: face.width / 2 - 10; radiusY: radiusX
                        startAngle: -90; sweepAngle: 360 * Math.max(0, pm.countdown) / 3
                        Behavior on sweepAngle { NumberAnimation { duration: 900 } }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pm.countdown >= 0 ? pm.countdown : pm.current.icon
                    font.family: pm.countdown >= 0 ? "Orbitron" : "Font Awesome 7 Free"
                    font.styleName: pm.countdown >= 0 ? "" : "Solid"
                    font.weight: Font.Black
                    font.pixelSize: face.width * 0.22
                    color: dial.accent
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pm.current.name
                    font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: face.width * 0.08; font.letterSpacing: 2
                    color: dial.accent
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pm.countdown >= 0 ? "ESC para cancelar" : "ligado há " + pm.uptime
                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: face.width * 0.06
                    color: Qt.alpha(pm.fg, 0.7)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property var dev: UPower.displayDevice
                    visible: pm.countdown < 0 && dev && dev.isPresent
                    text: dev ? "bateria " + Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) + "%" : ""
                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: face.width * 0.06
                    color: Qt.alpha(pm.fg, 0.5)
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dial.bottom; anchors.topMargin: 24
        opacity: pm.reveal
        text: "←/→ · scroll  escolher      ENTER  confirmar      1–5 / B S E R D  atalho      ESC  sair"
        font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15; font.letterSpacing: 1
        color: Qt.alpha(pm.fg, 0.55)
    }
}
