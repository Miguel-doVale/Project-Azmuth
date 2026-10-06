// Project Azmuth — barra "HUD galvânico". Uma instância por monitor.
// Faixa com cantos chanfrados + cápsula central pendurada com o Omnitrix e o
// anel do timer. Cores, DNA e timer vêm de `theme` (theme.json do core.py).

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

    readonly property color primary: Energy.locked ? danger : theme.primary
    readonly property color dnaColor: theme.primary
    readonly property color secondary: theme.secondary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property color danger: "#ff4d4d"
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"

    readonly property int stripH: 38      // faixa (zona exclusiva)
    readonly property int podDepth: 30    // quanto a cápsula desce abaixo da faixa
    readonly property int podTop: 235     // meia-largura da cápsula no topo
    readonly property int podBottom: 185  // meia-largura da cápsula embaixo
    readonly property real cx: width / 2

    visible: theme.bar !== false
    anchors { top: true; left: true; right: true }
    implicitHeight: stripH + podDepth + 8
    exclusiveZone: stripH
    color: "transparent"
    WlrLayershell.namespace: "azmuth-bar"
    WlrLayershell.layer: WlrLayer.Top
    // só a faixa e a cápsula recebem clique; o resto deixa passar para as janelas
    mask: Region {
        Region { item: strip }
        Region { item: podHit }
    }

    function iconFor(appId) {
        const entry = DesktopEntries.heuristicLookup(appId)
        return Quickshell.iconPath(entry ? entry.icon : appId, true)
            || Quickshell.iconPath("application-x-executable", true)
            || Quickshell.iconPath("utilities-terminal", true)
    }
    function run(cmd) { Quickshell.execDetached(cmd) }
    function mmss(s) { s = Math.max(0, Math.ceil(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

    // ─────────────────────────── timer do Omnitrix ───────────────────────────
    // energia do Omnitrix: ver Energy.qml (singleton)

    // ─────────────────────────── forma da barra ───────────────────────────
    Item { id: strip; x: 0; y: 0; width: bar.width; height: bar.stripH }
    Item {
        id: podHit
        x: bar.cx - bar.podTop; y: 0
        width: bar.podTop * 2; height: bar.stripH + bar.podDepth + 6
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Qt.alpha(bar.bg, 0.92)
            strokeColor: Qt.alpha(bar.primary, 0.85)
            strokeWidth: 1.5
            joinStyle: ShapePath.MiterJoin
            Behavior on strokeColor { ColorAnimation { duration: 400 } }
            readonly property real h: bar.stripH
            readonly property real d: bar.stripH + bar.podDepth
            startX: 0; startY: -2
            PathLine { x: bar.width; y: -2 }
            PathLine { x: bar.width; y: 26 }
            PathLine { x: bar.width - 12; y: 38 }                     // chanfro direito
            PathLine { x: bar.cx + bar.podTop; y: 38 }
            PathLine { x: bar.cx + bar.podBottom; y: 38 + bar.podDepth } // cápsula
            PathLine { x: bar.cx - bar.podBottom; y: 38 + bar.podDepth }
            PathLine { x: bar.cx - bar.podTop; y: 38 }
            PathLine { x: 12; y: 38 }
            PathLine { x: 0; y: 26 }                                  // chanfro esquerdo
            PathLine { x: 0; y: -2 }
        }
    }
    // filetes de circuito na cápsula
    Repeater {
        model: [-1, 1]
        Rectangle {
            required property int modelData
            width: 34; height: 2; radius: 1
            color: Qt.alpha(bar.primary, 0.6)
            x: bar.cx + modelData * (bar.podBottom - 26) - width / 2
            y: bar.stripH + bar.podDepth - 7
        }
    }

    // ─────────────────────────── centro: Omnitrix ───────────────────────────
    Item {
        id: omni
        readonly property int size: 60
        width: size; height: size
        x: bar.cx - size / 2
        y: bar.stripH + bar.podDepth - size + 4

        // anel do timer (fundo + arco)
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(bar.primary, 0.18); strokeWidth: 4; fillColor: "transparent"
                PathAngleArc { centerX: omni.size / 2; centerY: omni.size / 2; radiusX: omni.size / 2 - 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: bar.primary; strokeWidth: 4; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: omni.size / 2; centerY: omni.size / 2; radiusX: omni.size / 2 - 2; radiusY: radiusX
                    startAngle: -90; sweepAngle: 360 * Math.max(0.001, Energy.level)
                }
            }
            // último minuto: anel pisca
            opacity: Energy.critical ? blink.v : 1
            QtObject { id: blink; property real v: 1 }
            SequentialAnimation {
                running: Energy.critical; loops: Animation.Infinite
                NumberAnimation { target: blink; property: "v"; to: 0.25; duration: 300 }
                NumberAnimation { target: blink; property: "v"; to: 1; duration: 300 }
            }
        }

        Rectangle {   // corpo do relógio
            id: dial
            anchors.centerIn: parent
            width: omni.size - 14; height: width; radius: width / 2
            color: "#101316"
            border.width: 2
            border.color: Qt.alpha(bar.primary, 0.9)

            Shape {
                id: glass
                anchors.fill: parent
                anchors.margins: 11
                ShapePath {
                    strokeWidth: 0; fillColor: bar.primary
                    Behavior on fillColor { ColorAnimation { duration: 300 } }
                    startX: 0; startY: 0
                    PathLine { x: glass.width; y: 0 }
                    PathLine { x: glass.width / 2; y: glass.height / 2 - 0.5 }
                    PathLine { x: 0; y: 0 }
                }
                ShapePath {
                    strokeWidth: 0; fillColor: bar.primary
                    Behavior on fillColor { ColorAnimation { duration: 300 } }
                    startX: 0; startY: glass.height
                    PathLine { x: glass.width; y: glass.height }
                    PathLine { x: glass.width / 2; y: glass.height / 2 + 0.5 }
                    PathLine { x: 0; y: glass.height }
                }
            }

            RotationAnimation on rotation {
                id: spin
                running: false
                from: 0; to: 360; duration: 700; easing.type: Easing.OutBack
            }
            Connections {
                target: bar.shell
                function onThemeChanged() { spin.restart() }
            }
        }

        // Master Control: pulso externo
        Rectangle {
            anchors.centerIn: parent
            width: omni.size + 8; height: width; radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: bar.dnaColor
            visible: bar.theme.master === true
            SequentialAnimation on opacity {
                running: bar.theme.master === true
                loops: Animation.Infinite
                NumberAnimation { from: 0.9; to: 0.1; duration: 900 }
                NumberAnimation { from: 0.1; to: 0.9; duration: 900 }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) bar.run([bar.az, "random"])
                else if (mouse.button === Qt.MiddleButton) bar.run([bar.az, "master", "toggle"])
                else bar.run([bar.az, "hud", "toggle"])
            }
        }
    }

    // nome do DNA (esquerda da cápsula) e tempo/relógio (direita)
    Text {
        anchors.right: omni.left; anchors.rightMargin: 14
        y: bar.stripH + 5
        width: Math.min(implicitWidth, 150)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        text: Energy.locked ? "RECARREGANDO" : (bar.theme.name || "").toUpperCase()
        font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 11; font.letterSpacing: 1
        color: bar.primary
    }
    Text {
        anchors.left: omni.right; anchors.leftMargin: 14
        y: bar.stripH + 5
        property date clock: new Date()
        Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.clock = new Date() }
        // transformado: tempo de energia · Neutral: carga e tempo até 100% · cheio: relógio
        text: Energy.draining ? Energy.mmss(Energy.secondsLeft)
              : (Energy.charging ? Energy.percent + "% · " + Energy.mmss(Energy.secondsToFull)
                 : Qt.formatTime(clock, "HH:mm"))
        font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 11; font.letterSpacing: 1
        color: Energy.critical ? bar.danger : bar.primary
    }

    // ─────────────────────────── esquerda ───────────────────────────
    Row {
        id: leftRow
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: strip.verticalCenter
        spacing: 8

        // workspaces com os apps dentro
        Repeater {
            model: Hyprland.workspaces.values
                .filter(ws => ws.id > 0 && ws.monitor === bar.monitor)
                .sort((a, b) => a.id - b.id)

            Item {
                id: wsPill
                required property HyprlandWorkspace modelData
                readonly property bool isActive: bar.monitor && bar.monitor.activeWorkspace === modelData
                readonly property var wins: modelData.toplevels.values
                height: 26
                width: wsRow.implicitWidth + 22
                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                // pílula chanfrada (paralelogramo), no estilo da barra
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: wsPill.isActive ? Qt.alpha(bar.primary, 0.22) : (wsMouse.containsMouse ? Qt.alpha(bar.primary, 0.1) : "transparent")
                        strokeColor: wsPill.isActive ? bar.primary : Qt.alpha(bar.primary, 0.3)
                        strokeWidth: 1.2
                        startX: 7; startY: 0
                        PathLine { x: wsPill.width; y: 0 }
                        PathLine { x: wsPill.width - 7; y: wsPill.height }
                        PathLine { x: 0; y: wsPill.height }
                        PathLine { x: 7; y: 0 }
                    }
                }
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
                            opacity: modelData.activated ? 1 : 0.65
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
        Row {
            readonly property var mins: Hyprland.toplevels.values.filter(t => t.workspace && t.workspace.name === "special:minimized")
            visible: mins.length > 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            leftPadding: 4
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ""
                font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 11
                color: Qt.alpha(bar.fg, 0.5)
            }
            Repeater {
                model: parent.mins
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

        // janela ativa
        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 6
            readonly property var activeWin: Hyprland.activeToplevel
            width: Math.min(implicitWidth, Math.max(0, bar.cx - bar.podTop - x - 40))
            elide: Text.ElideRight
            text: activeWin && activeWin.workspace && activeWin.workspace.monitor === bar.monitor ? activeWin.title : ""
            font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15
            color: Qt.alpha(bar.fg, 0.7)
        }
    }

    // ─────────────────────────── direita ───────────────────────────
    component Chip: Item {
        id: chip
        property string icon: ""
        property string label: ""
        property color tint: bar.fg
        signal clicked(var mouse)
        signal wheel(var wheel)
        height: 26
        width: chipRow.implicitWidth + 26
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: chipMouse.containsMouse ? Qt.alpha(bar.primary, 0.18) : Qt.alpha(bar.primary, 0.06)
                strokeColor: Qt.alpha(bar.primary, 0.32)
                strokeWidth: 1.2
                startX: 7; startY: 0
                PathLine { x: chip.width; y: 0 }
                PathLine { x: chip.width - 7; y: chip.height }
                PathLine { x: 0; y: chip.height }
                PathLine { x: 7; y: 0 }
            }
        }
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

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: strip.verticalCenter
        spacing: 4

        // bandeja do sistema
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            rightPadding: 6
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
            tint: dev ? bar.fg : bar.danger
            onClicked: bar.run(["nm-connection-editor"])
        }

        Chip {
            icon: ""
            label: Math.round(SysStats.cpu) + "%"
            onClicked: bar.run(["kitty", "-e", "btop"])
        }
        Chip {
            icon: ""
            label: Math.round(SysStats.ram) + "%"
            onClicked: bar.run(["kitty", "-e", "btop"])
        }

        Chip {   // bateria
            readonly property var dev: UPower.displayDevice
            readonly property int pct: dev ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 0
            readonly property bool charging: dev && dev.state === UPowerDeviceState.Charging
            visible: dev && dev.isPresent
            icon: charging ? "" : (pct > 85 ? "" : pct > 60 ? "" : pct > 35 ? "" : pct > 12 ? "" : "")
            label: pct + "%"
            tint: pct <= 12 && !charging ? bar.danger : (pct <= 25 && !charging ? "#ffd76a" : bar.fg)
        }

        Chip {   // energia
            icon: ""
            onClicked: mouse => bar.run([bar.az, mouse.button === Qt.RightButton ? "lock" : "power"])
        }
    }
}
