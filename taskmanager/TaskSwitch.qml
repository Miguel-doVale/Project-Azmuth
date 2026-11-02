import QtQuick
import "components"

Rectangle {
    id: control
    property bool checked: false
    property string label: ""
    signal toggled(bool value)
    width: 44; height: 24; radius: 12
    activeFocusOnTab: enabled
    opacity:enabled?1:.4
    color: checked ? Colors.primary : Qt.alpha(Colors.fg,.15)
    border.width: activeFocus ? 2 : 0
    border.color: Colors.fg
    Accessible.role: Accessible.CheckBox
    Accessible.name:label
    Accessible.checked:checked
    Keys.onSpacePressed: toggled(!checked)
    Rectangle {
        width:18; height:18; y:3; x:control.checked?23:3; radius:9
        color:control.checked?Colors.bg:Colors.fg
        Behavior on x { NumberAnimation { duration:140; easing.type:Easing.OutCubic } }
    }
    MouseArea { anchors.fill:parent; cursorShape:Qt.PointingHandCursor; onClicked:control.toggled(!control.checked) }
}
