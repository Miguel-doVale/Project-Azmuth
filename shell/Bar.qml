// Project Azmuth — barra (substitui a waybar). Uma instância por monitor.
// Cores e DNA vêm de `theme` (theme.json escrito pelo core.py a cada transformação).

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Networking

PanelWindow {
    id: bar

    required property var theme
    required property var shell
    required property ShellScreen modelData
    screen: modelData

    readonly property color primary: theme.primary
    readonly property color secondary: theme.secondary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"

    visible: theme.bar !== false
    anchors { top: true; left: true; right: true }
    implicitHeight: 40
    color: "transparent"
    WlrLayershell.namespace: "azmuth-bar"
    WlrLayershell.layer: WlrLayer.Top

    function iconFor(appId) {
        const entry = DesktopEntries.heuristicLookup(appId)
        return Quickshell.iconPath(entry ? entry.icon : appId, true)
            || Quickshell.iconPath("application-x-executable", true)
            || Quickshell.iconPath("utilities-terminal", true)
    }
    function run(cmd) { Quickshell.execDetached(cmd) }

    // fundo + linha neon
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(bar.bg, 0.9)
        Behavior on color { ColorAnimation { duration: 400 } }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(bar.primary, 0.15) }
                GradientStop { position: 0.5; color: bar.primary }
                GradientStop { position: 1.0; color: Qt.alpha(bar.primary, 0.15) }
            }
        }
    }

    // ─────────────────────────── esquerda ───────────────────────────
    Row {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -1
        spacing: 10

        // mini Omnitrix: DNA ativo
        Item {
            id: omni
            width: dial.width + nameClip.width
            height: 30
            property bool hovered: omniMouse.containsMouse

            Rectangle {
                id: dial
                width: 30; height: 30; radius: 15
                color: "#101316"
                border.width: 2
                border.color: bar.primary
                Behavior on border.color { ColorAnimation { duration: 300 } }

                Shape {   // ampulheta
                    anchors.fill: parent
                    anchors.margins: 6
                    id: glass
                    ShapePath {
                        strokeWidth: 0
                        fillColor: bar.primary
                        Behavior on fillColor { ColorAnimation { duration: 300 } }
                        startX: 0; startY: 0
                        PathLine { x: glass.width; y: 0 }
                        PathLine { x: glass.width / 2; y: glass.height / 2 - 0.5 }
                        PathLine { x: 0; y: 0 }
                    }
                    ShapePath {
                        strokeWidth: 0
                        fillColor: bar.primary
                        Behavior on fillColor { ColorAnimation { duration: 300 } }
                        startX: 0; startY: glass.height
                        PathLine { x: glass.width; y: glass.height }
                        PathLine { x: glass.width / 2; y: glass.height / 2 + 0.5 }
                        PathLine { x: 0; y: glass.height }
                    }
                }

                // gira a cada transformação
                RotationAnimation on rotation {
                    id: spin
                    running: false
                    from: 0; to: 360; duration: 700; easing.type: Easing.OutBack
                }
                Connections {
                    target: bar.shell
                    function onThemeChanged() { spin.restart() }
                }

                // Master Control ligado: pulso
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 8; height: width; radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: bar.primary
                    visible: bar.theme.master === true
                    SequentialAnimation on opacity {
                        running: bar.theme.master === true
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.9; to: 0.1; duration: 900 }
                        NumberAnimation { from: 0.1; to: 0.9; duration: 900 }
                    }
                }
            }

            // nome do DNA desliza para fora no hover
            Item {
                id: nameClip
                anchors.left: dial.right
                anchors.verticalCenter: dial.verticalCenter
                height: 30
                clip: true
                width: omni.hovered ? nameText.implicitWidth + 18 : 0
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Text {
                    id: nameText
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: (bar.theme.name || "").toUpperCase() + (bar.theme.master ? "  · MASTER" : "")
                    font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 12
                    font.letterSpacing: 1
                    color: bar.primary
                }
            }

            MouseArea {
                id: omniMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) bar.run([bar.az, "random"])
                    else if (mouse.button === Qt.MiddleButton) bar.run([bar.az, "master", "toggle"])
                    else bar.run([bar.az, "hud", "toggle"])
                }
            }
        }

        // workspaces com os apps dentro
        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: Hyprland.workspaces.values
                    .filter(ws => ws.id > 0 && ws.monitor === bar.monitor)
                    .sort((a, b) => a.id - b.id)

                Rectangle {
                    id: wsPill
                    required property HyprlandWorkspace modelData
                    readonly property bool isActive: bar.monitor && bar.monitor.activeWorkspace === modelData
                    readonly property var wins: modelData.toplevels.values

                    height: 28
                    width: wsRow.implicitWidth + 16
                    radius: 14
                    color: isActive ? Qt.alpha(bar.primary, 0.18) : (wsMouse.containsMouse ? Qt.alpha(bar.primary, 0.08) : "transparent")
                    border.width: 1
                    border.color: isActive ? bar.primary : Qt.alpha(bar.primary, 0.25)
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 180 } }

                    MouseArea {
                        id: wsMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: wsPill.modelData.activate()
                    }

                    Row {
                        id: wsRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: wsPill.modelData.id
                            font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 12
                            color: wsPill.isActive ? bar.primary : Qt.alpha(bar.fg, 0.6)
                        }
                        Repeater {
                            model: wsPill.wins
                            IconImage {
                                required property HyprlandToplevel modelData
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 18
                                source: bar.iconFor(modelData.wayland ? modelData.wayland.appId : (modelData.lastIpcObject.class || ""))
                                opacity: modelData.activated ? 1 : 0.7
                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    onClicked: mouse => {
                                        if (!parent.modelData.wayland) return
                                        if (mouse.button === Qt.MiddleButton) parent.modelData.wayland.close()
                                        else parent.modelData.wayland.activate()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // minimizados (special:minimized) — clique restaura
            Rectangle {
                readonly property var mins: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.name === "special:minimized")
                visible: mins.length > 0
                height: 28
                width: minRow.implicitWidth + 16
                radius: 14
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(bar.fg, 0.2)
                Row {
                    id: minRow
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 11
                        color: Qt.alpha(bar.fg, 0.5)
                    }
                    Repeater {
                        model: parent.parent.mins
                        IconImage {
                            required property HyprlandToplevel modelData
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 18
                            opacity: 0.45
                            source: bar.iconFor(modelData.wayland ? modelData.wayland.appId : "")
                            MouseArea {
                                anchors.fill: parent
                                onClicked: if (parent.modelData.wayland) parent.modelData.wayland.activate()
                            }
                        }
                    }
                }
            }
        }
    }

    // ─────────────────────────── centro: janela ativa ───────────────────────────
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        width: Math.min(implicitWidth, bar.width * 0.3)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        readonly property var activeWin: Hyprland.activeToplevel
        text: activeWin && activeWin.workspace && activeWin.workspace.monitor === bar.monitor ? activeWin.title : ""
        font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15
        color: Qt.alpha(bar.fg, 0.75)
    }

    // ─────────────────────────── direita ───────────────────────────
    component Chip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property color tint: bar.fg
        signal clicked(var mouse)
        signal wheel(var wheel)
        height: 28
        width: chipRow.implicitWidth + 22
        radius: 14
        color: chipMouse.containsMouse ? Qt.alpha(bar.primary, 0.16) : Qt.alpha(bar.primary, 0.06)
        border.width: 1
        border.color: Qt.alpha(bar.primary, 0.3)
        Behavior on color { ColorAnimation { duration: 150 } }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 7
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                visible: chip.icon !== ""
                font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 13
                color: bar.primary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                visible: chip.label !== ""
                font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15
                color: chip.tint
            }
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => chip.clicked(mouse)
            onWheel: wheel => chip.wheel(wheel)
        }
    }

    // CPU / RAM a partir do /proc
    QtObject {
        id: sys
        property real cpu: 0
        property real ram: 0
        property var last: null
    }
    FileView { id: stat; path: "/proc/stat" }
    FileView { id: meminfo; path: "/proc/meminfo" }
    Timer {
        interval: 2500; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            stat.reload(); meminfo.reload()
            const c = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = c[3] + c[4], total = c.reduce((a, b) => a + b, 0)
            if (sys.last) sys.cpu = 100 * (1 - (idle - sys.last.idle) / Math.max(1, total - sys.last.total))
            sys.last = { idle: idle, total: total }
            const m = {}
            meminfo.text().split("\n").forEach(l => { const p = l.split(/:\s+/); if (p.length > 1) m[p[0]] = parseInt(p[1]) })
            if (m.MemTotal) sys.ram = 100 * (1 - m.MemAvailable / m.MemTotal)
        }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -1
        spacing: 6

        // bandeja do sistema
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            rightPadding: 4
            Repeater {
                model: SystemTray.items.values
                IconImage {
                    id: trayIcon
                    required property SystemTrayItem modelData
                    implicitSize: 18
                    source: modelData.icon
                    QsMenuAnchor {
                        id: trayMenu
                        menu: trayIcon.modelData.menu
                        anchor.item: trayIcon
                        anchor.edges: Edges.Bottom
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton || trayIcon.modelData.onlyMenu) {
                                if (trayIcon.modelData.hasMenu) trayMenu.open()
                            } else trayIcon.modelData.activate()
                        }
                    }
                }
            }
        }

        Chip {   // volume: scroll ajusta, clique abre pavucontrol, direito muta
            readonly property var audio: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
            readonly property int vol: audio ? Math.round(audio.volume * 100) : 0
            icon: !audio || audio.muted ? "" : (vol > 60 ? "" : (vol > 20 ? "" : ""))
            label: audio && audio.muted ? "Mudo" : vol + "%"
            tint: audio && audio.muted ? Qt.alpha(bar.fg, 0.45) : bar.fg
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) { if (audio) audio.muted = !audio.muted }
                else bar.run(["pavucontrol"])
            }
            onWheel: wheel => {
                if (!audio) return
                audio.volume = Math.max(0, Math.min(1, audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
            }
        }

        Chip {   // rede
            readonly property var dev: Networking.devices.values.find(d => d.connected) || null
            readonly property var net: dev && dev.networks ? dev.networks.values.find(n => n.connected) : null
            icon: !dev ? "" : (dev.type === DeviceType.Wifi ? "" : "")
            label: !dev ? "Sem rede" : (net ? net.name : dev.name)
            tint: dev ? bar.fg : "#ff5a5a"
            onClicked: bar.run(["nm-connection-editor"])
        }

        Chip {
            icon: ""
            label: Math.round(sys.cpu) + "%"
            onClicked: bar.run(["kitty", "-e", "btop"])
        }
        Chip {
            icon: ""
            label: Math.round(sys.ram) + "%"
            onClicked: bar.run(["kitty", "-e", "btop"])
        }

        Chip {   // bateria
            readonly property var dev: UPower.displayDevice
            readonly property int pct: dev ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 0
            readonly property bool charging: dev && dev.state === UPowerDeviceState.Charging
            visible: dev && dev.isPresent
            icon: charging ? "" : (pct > 85 ? "" : pct > 60 ? "" : pct > 35 ? "" : pct > 12 ? "" : "")
            label: pct + "%"
            tint: pct <= 12 && !charging ? "#ff5a5a" : (pct <= 25 && !charging ? "#ffd76a" : bar.fg)
        }

        Chip {   // energia
            icon: ""
            onClicked: mouse => bar.run([bar.az, mouse.button === Qt.RightButton ? "lock" : "power"])
        }
    }
}
