// Project Azmuth — widgets fixos da área de trabalho ("orbitando o Omnitrix").
// Ficam abaixo das janelas e acima do wallpaper: relógio sobre o símbolo central
// e anéis de sistema embaixo dele. O resto (música, calendário, DNA, config)
// mora no Dashboard (Super + W).

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: desk

    required property var theme
    required property ShellScreen modelData
    screen: modelData

    readonly property color primary: theme.primary
    readonly property color fg: theme.foreground
    readonly property real symbolR: height * 0.27   // raio do Omnitrix do wallpaper

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "azmuth-widgets"
    mask: Region {}   // puramente decorativo: cliques passam direto para a área de trabalho

    // ───────────────────────── relógio ─────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.verticalCenter
        anchors.bottomMargin: desk.symbolR + 26
        spacing: 0
        property date now: new Date()
        Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.now = new Date() }

        Text {
            id: time
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(parent.now, "HH:mm")
            font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 68
            font.letterSpacing: 4
            color: desk.primary
            Behavior on color { ColorAnimation { duration: 400 } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: desk.primary; shadowBlur: 1.0; shadowOpacity: 0.6
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("pt_BR").toString(parent.now, "dddd · d 'de' MMMM").toUpperCase()
            font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; font.letterSpacing: 3
            color: Qt.alpha(desk.fg, 0.85)
        }
    }

    // ───────────────────────── anéis de sistema ─────────────────────────
    component Gauge: Item {
        id: g
        property real value: 0          // 0–100
        property string label: ""
        property string unit: "%"
        property real shown: value
        Behavior on shown { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }
        readonly property color tint: value >= 90 ? "#ff5a5a" : (value >= 75 ? "#ffd76a" : desk.primary)
        width: 76; height: 92

        Shape {
            width: 76; height: 76
            preferredRendererType: Shape.CurveRenderer
            ShapePath {   // trilho (arco de 270°)
                strokeColor: Qt.alpha(desk.primary, 0.16); strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 38; centerY: 38; radiusX: 33; radiusY: 33; startAngle: 135; sweepAngle: 270 }
            }
            ShapePath {   // valor
                strokeColor: g.tint; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 38; centerY: 38; radiusX: 33; radiusY: 33; startAngle: 135; sweepAngle: Math.max(1, 270 * Math.min(100, g.shown) / 100) }
            }
        }
        Text {
            x: 0; width: 76; y: 26
            horizontalAlignment: Text.AlignHCenter
            text: Math.round(g.value) + g.unit
            font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 15
            color: desk.fg
        }
        Text {
            x: 0; width: 76; y: 72
            horizontalAlignment: Text.AlignHCenter
            text: g.label
            font.family: "Orbitron"; font.pixelSize: 10; font.letterSpacing: 2
            color: Qt.alpha(desk.fg, 0.6)
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.verticalCenter
        anchors.topMargin: desk.symbolR + 22
        spacing: 34
        opacity: 0.9
        Gauge { label: "CPU"; value: SysStats.cpu }
        Gauge { label: "RAM"; value: SysStats.ram }
        Gauge { label: "TEMP"; value: SysStats.temp; unit: "°" }
    }
}
