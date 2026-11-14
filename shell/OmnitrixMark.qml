// Project Azmuth — o Omnitrix desenhado (ilha, dock, painel). Anel + ampulheta na cor do DNA;
// arcos girando no modo do core (scan/recalibração), runa Chave no Life-Form Lock e pulso do
// Master Control. `ring` mostra o anel de energia do timer em volta.
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: mark
    property real size: 44
    property color color: Colors.primary
    property color bg: Colors.bg
    property bool glow: true
    property bool ring: false          // anel de energia (fase 2 da ilha)
    property bool status: true         // modo do core, Life-Form e Master Control
    property bool master: false
    width: size; height: size


    // anel de energia
    Shape {
        visible: mark.ring
        anchors.centerIn: parent
        width: mark.size + 14; height: width
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.alpha(mark.color, 0.18); strokeWidth: 3; fillColor: "transparent"
            PathAngleArc { centerX: (mark.size + 14) / 2; centerY: centerX; radiusX: mark.size / 2 + 5; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: mark.color; strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: (mark.size + 14) / 2; centerY: centerX; radiusX: mark.size / 2 + 5; radiusY: radiusX
                           startAngle: -90; sweepAngle: 360 * Math.max(0.001, Energy.level) }
        }
        opacity: Energy.critical ? blink.v : 1
        QtObject { id: blink; property real v: 1 }
        SequentialAnimation {
            running: mark.ring && Energy.critical; loops: Animation.Infinite
            NumberAnimation { target: blink; property: "v"; to: 0.25; duration: 300 }
            NumberAnimation { target: blink; property: "v"; to: 1; duration: 300 }
        }
    }

    // modo do core: dois arcos girando
    Shape {
        visible: mark.status && Colors.mode !== ""
        anchors.centerIn: parent
        width: mark.size + 10; height: width
        preferredRendererType: Shape.CurveRenderer
        RotationAnimation on rotation { running: Colors.mode !== ""; loops: Animation.Infinite; from: 0; to: 360; duration: Colors.mode === "scan" ? 900 : 1600 }
        ShapePath {
            strokeColor: Colors.modeColor; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: (mark.size + 10) / 2; centerY: centerX; radiusX: mark.size / 2 + 3; radiusY: radiusX; startAngle: 0; sweepAngle: 100 }
        }
        ShapePath {
            strokeColor: Colors.modeColor; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: (mark.size + 10) / 2; centerY: centerX; radiusX: mark.size / 2 + 3; radiusY: radiusX; startAngle: 180; sweepAngle: 100 }
        }
    }

    // corpo
    Rectangle {
        id: dial
        anchors.centerIn: parent
        width: mark.size; height: width; radius: width / 2
        color: mark.bg
        border.width: Math.max(2, mark.size * 0.07)
        border.color: mark.color
        // neon: brilho desfocado em volta (como o box-shadow do protótipo), não um disco chapado
        layer.enabled: mark.glow
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true
            shadowColor: mark.color
            shadowBlur: 1.0
            blurMax: Math.max(16, mark.size * 0.45)
            shadowOpacity: 0.95
            shadowScale: 1.04
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: dial.border.width + mark.size * 0.08
            radius: width / 2; color: "transparent"
            border.width: 1.5; border.color: Qt.alpha(mark.color, 0.45)
        }
        Shape {
            id: glass
            anchors.centerIn: parent
            width: mark.size * 0.38; height: mark.size * 0.42
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0; fillColor: mark.color
                startX: 0; startY: 0
                PathLine { x: glass.width; y: 0 }
                PathLine { x: glass.width / 2; y: glass.height / 2 - 0.5 }
                PathLine { x: 0; y: 0 }
            }
            ShapePath {
                strokeWidth: 0; fillColor: mark.color
                startX: 0; startY: glass.height
                PathLine { x: glass.width; y: glass.height }
                PathLine { x: glass.width / 2; y: glass.height / 2 + 0.5 }
                PathLine { x: 0; y: glass.height }
            }
        }
    }

    // Master Control: pulso externo
    Rectangle {
        anchors.centerIn: parent
        width: mark.size + 8; height: width; radius: width / 2
        color: "transparent"; border.width: 2; border.color: mark.color
        visible: mark.status && mark.master
        SequentialAnimation on opacity {
            running: mark.status && mark.master; loops: Animation.Infinite
            NumberAnimation { from: 0.9; to: 0.1; duration: 900 }
            NumberAnimation { from: 0.1; to: 0.9; duration: 900 }
        }
    }

    // Life-Form Lock: runa Chave
    Rectangle {
        visible: mark.status && Colors.lifeform && mark.size >= 30
        x: mark.size - mark.size * 0.3; y: -mark.size * 0.05
        width: mark.size * 0.42; height: width; radius: width / 2
        color: mark.bg; border.width: 1.5; border.color: mark.color
        Glyph { anchors.centerIn: parent; width: parent.width * 0.6; height: width; name: "chave"; color: mark.color; stroke: 1.5 }
    }
}
