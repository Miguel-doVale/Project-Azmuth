// Slider horizontal (0–1) com trilho neon; arrastar, clicar ou scroll.
import QtQuick

Item {
    id: sl
    property real value: 0          // 0..1 (pode passar de 1 se maximum > 1)
    property real maximum: 1
    property color tint: Colors.primary
    signal moved(real value)
    width: 200; height: 22
    readonly property real frac: Math.max(0, Math.min(1, value / maximum))

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 6; radius: 3
        color: Qt.alpha(sl.tint, 0.15)
        Rectangle { width: parent.width * sl.frac; height: parent.height; radius: 3; color: sl.tint }
    }
    Rectangle {
        x: (sl.width - width) * sl.frac; anchors.verticalCenter: parent.verticalCenter
        width: 16; height: 16; radius: 8
        color: Colors.bg
        border.width: 3; border.color: sl.tint
        scale: ma.pressed || ma.containsMouse ? 1.2 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent; anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        function set(mx) { sl.moved(Math.max(0, Math.min(1, (mx - 6) / sl.width)) * sl.maximum) }
        onPressed: mouse => set(mouse.x)
        onPositionChanged: mouse => { if (pressed) set(mouse.x) }
        onWheel: wheel => sl.moved(Math.max(0, Math.min(sl.maximum, sl.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
