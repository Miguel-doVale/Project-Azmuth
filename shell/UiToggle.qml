// Liga/desliga com rótulo e dica — padrão da Central.
import QtQuick

Item {
    id: tg
    property bool checked: false
    property string label: ""
    property string hint: ""
    signal toggled(bool value)
    width: parent ? parent.width : 0
    height: hint ? 48 : 34
    Column {
        anchors.left: parent.left; anchors.right: sw.left; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text { text: tg.label; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; color: Colors.fg }
        Text { visible: tg.hint !== ""; width: parent.width; elide: Text.ElideRight; text: tg.hint; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.55) }
    }
    Rectangle {
        id: sw
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: 48; height: 26; radius: 13
        color: tg.checked ? Colors.primary : Qt.alpha(Colors.fg, 0.12)
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            width: 20; height: 20; radius: 10; y: 3
            x: tg.checked ? parent.width - width - 3 : 3
            color: tg.checked ? Colors.bg : Colors.fg
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { tg.checked = !tg.checked; tg.toggled(tg.checked) } }
}
