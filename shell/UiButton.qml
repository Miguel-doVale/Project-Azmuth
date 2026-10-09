// Botão em pílula com runa Galvan e/ou texto — padrão da Central.
import QtQuick

Rectangle {
    id: btn
    property string glyph: ""
    property string text: ""
    property color tint: Colors.primary
    property bool filled: false
    signal clicked
    height: 30; width: text ? row.implicitWidth + 24 : 30; radius: 15
    color: filled ? (bm.containsMouse ? Qt.lighter(tint, 1.15) : tint) : (bm.containsMouse ? Qt.alpha(tint, 0.22) : "transparent")
    border.width: 1; border.color: Qt.alpha(tint, 0.6)
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Glyph { visible: btn.glyph !== ""; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; name: btn.glyph || "nucleo"; color: btn.filled ? Colors.bg : btn.tint; stroke: 1.6 }
        Text {
            visible: btn.text !== ""; anchors.verticalCenter: parent.verticalCenter; text: btn.text
            font.family: btn.text.length === 1 ? "JetBrainsMono Nerd Font" : "Orbitron"
            font.pixelSize: btn.text.length === 1 ? 15 : 10; font.weight: Font.Bold
            color: btn.filled ? Colors.bg : btn.tint
        }
    }
    MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
}
