// Project Azmuth — menu de energia (Super + Shift + Q): o Omnitrix com outra função.
// Mesmo disco do HUD (OmnitrixDial). Ações irreversíveis têm contagem de 3 s cancelável.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.UPower

PanelWindow {
    id: pm

    required property var theme
    readonly property color danger: "#ff5a5a"
    readonly property color fg: theme.foreground
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"

    property bool open: false
    property int index: 0
    property int countdown: -1
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: pm.open ? 320 : 180; easing.type: Easing.OutCubic } }

    readonly property var actions: [
        { key: "B", name: "BLOQUEAR",  desc: "Trava a sessão (desbloqueio pelo Omnitrix)", icon: "", color: theme.primary, risky: false, cmd: [az, "lock"] },
        { key: "S", name: "SUSPENDER", desc: "Dorme e trava ao acordar", icon: "", color: theme.primary, risky: false, cmd: ["sh", "-c", "$HOME/.local/bin/azmuth lock; sleep 0.8; systemctl suspend"] },
        { key: "E", name: "SAIR",      desc: "Encerra a sessão do Hyprland", icon: "", color: danger, risky: true, cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { key: "R", name: "REINICIAR", desc: "Reinicia o computador", icon: "", color: danger, risky: true, cmd: ["systemctl", "reboot"] },
        { key: "D", name: "DESLIGAR",  desc: "Desliga o computador", icon: "", color: danger, risky: true, cmd: ["systemctl", "poweroff"] }
    ]
    readonly property var current: actions[index]
    readonly property color accent: current.color

    function toggle() {
        if (open) { close(); return }
        index = 0; countdown = -1
        uptimeFile.reload()
        open = true
        keys.forceActiveFocus()
        play("hud_open")
    }
    function close() { countdown = -1; tick.stop(); open = false }
    function play(n) { Quickshell.execDetached(["pw-play", decodeURIComponent(Qt.resolvedUrl("../assets/sounds/" + n + ".wav").toString().replace("file://", ""))]) }
    function rotate(d) { if (countdown < 0) { index = (index + d + actions.length) % actions.length; play("tick") } }
    function confirm() {
        if (countdown >= 0) return
        if (current.risky) { countdown = 3; play("beep"); tick.restart() } else run()
    }
    function run() { const c = current.cmd; close(); Quickshell.execDetached(c) }
    Timer {
        id: tick
        interval: 1000; repeat: true
        onTriggered: { pm.countdown--; if (pm.countdown <= 0) { stop(); pm.run() } else pm.play("beep") }
    }

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

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.8 * pm.reveal }
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

    OmnitrixDial {
        id: dial
        size: Math.min(pm.width, pm.height) * 0.56
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -pm.height * 0.04
        scale: 0.85 + 0.15 * pm.reveal
        opacity: pm.reveal
        rotation: (1 - pm.reveal) * -25
        accent: pm.countdown >= 0 ? pm.danger : pm.accent
        items: pm.actions.map(a => ({ icon: a.icon, color: a.color }))
        index: pm.index

        // ampulheta esmaecida ao fundo
        Shape {
            id: hg
            anchors.fill: parent
            anchors.margins: parent.width * 0.18
            opacity: 0.16
            ShapePath { strokeWidth: 0; fillColor: dial.accent; startX: 0; startY: 0; PathLine { x: hg.width; y: 0 } PathLine { x: hg.width / 2; y: hg.height / 2 - 1 } PathLine { x: 0; y: 0 } }
            ShapePath { strokeWidth: 0; fillColor: dial.accent; startX: 0; startY: hg.height; PathLine { x: hg.width; y: hg.height } PathLine { x: hg.width / 2; y: hg.height / 2 + 1 } PathLine { x: 0; y: hg.height } }
        }
        // ícone da ação / número da contagem
        Text {
            anchors.centerIn: parent
            text: pm.countdown >= 0 ? pm.countdown : pm.current.icon
            font.family: pm.countdown >= 0 ? "Orbitron" : "Font Awesome 7 Free"
            font.styleName: pm.countdown >= 0 ? "" : "Solid"
            font.weight: Font.Black
            font.pixelSize: dial.faceSize * 0.36
            color: dial.accent
        }
        // anel da contagem regressiva
        Shape {
            anchors.fill: parent
            visible: pm.countdown >= 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: pm.danger; strokeWidth: 7; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: dial.faceSize / 2; centerY: dial.faceSize / 2
                    radiusX: dial.faceSize / 2 - 14; radiusY: radiusX
                    startAngle: -90; sweepAngle: 360 * Math.max(0, pm.countdown) / 3
                    Behavior on sweepAngle { NumberAnimation { duration: 900 } }
                }
            }
        }
    }

    // placa (igual à do HUD)
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dial.bottom
        anchors.topMargin: pm.height * 0.035
        spacing: 6
        opacity: pm.reveal
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: pm.current.name
            font.family: "Orbitron"; font.pixelSize: 34; font.weight: Font.Black; font.letterSpacing: 4
            color: dial.accent
            style: Text.Outline; styleColor: Qt.alpha(dial.accent, 0.25)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            readonly property var dev: UPower.displayDevice
            text: pm.countdown >= 0 ? "Executando em " + pm.countdown + "s · ESC cancela"
                  : pm.current.desc + " · ligado há " + pm.uptime
                    + (dev && dev.isPresent ? " · bateria " + Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) + "%" : "")
            font.family: "Rajdhani"; font.pixelSize: 18; font.weight: Font.DemiBold
            color: "#c9d1d9"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 14
            text: "←/→ · scroll  girar      ENTER  confirmar      1–5 · B S E R D  atalho      ESC  sair"
            font.family: "Rajdhani"; font.pixelSize: 16; font.letterSpacing: 1
            color: "#9aa4b0"
        }
    }
}
