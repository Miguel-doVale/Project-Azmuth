import QtQuick
import "components"

Rectangle {
    id: button
    property string text: ""
    property string glyph: ""
    property color tint: Colors.primary
    property bool filled: false
    signal clicked()
    height: 34
    implicitWidth: label.implicitWidth + (glyph ? 48 : 26)
    width: implicitWidth
    radius: 7
    activeFocusOnTab: enabled
    opacity: enabled ? 1 : .38
    color: filled ? (mouse.containsMouse ? Qt.lighter(tint, 1.12) : tint)
                  : Qt.alpha(tint, mouse.containsMouse ? .15 : .035)
    border.width: 1
    border.color: activeFocus ? Colors.fg : Qt.alpha(tint, .45)
    Behavior on color { ColorAnimation { duration: 120 } }
    Keys.onReturnPressed: if(enabled) clicked()
    Keys.onSpacePressed: if(enabled) clicked()
    Accessible.role: Accessible.Button
    Accessible.name: text
    Row {
        anchors.centerIn: parent
        spacing: 7
        Glyph { visible:button.glyph!==""; name:button.glyph||"nucleo"; width:16; height:16; anchors.verticalCenter:parent.verticalCenter; color:button.filled?Colors.bg:button.tint; stroke:1.6 }
        Text { id:label; text:button.text; font.family:"Rajdhani"; font.pixelSize:16; font.weight:Font.DemiBold; color:button.filled?Colors.bg:Colors.fg }
    }
    MouseArea { id:mouse; anchors.fill:parent; hoverEnabled:true; cursorShape:Qt.PointingHandCursor; onClicked:button.clicked() }
}
