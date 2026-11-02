import QtQuick
import "components"

Rectangle {
    id: search
    property alias text: input.text
    property string placeholder: "Buscar"
    signal edited(string value)
    signal accepted()
    height: 38; radius: 7
    color: Qt.alpha(Colors.fg,.035)
    border.width: 1
    border.color:input.activeFocus?Colors.primary:Qt.alpha(Colors.fg,.18)
    function activate() { input.forceActiveFocus(); input.selectAll() }
    Glyph { x:12; anchors.verticalCenter:parent.verticalCenter; width:17;height:17; name:"visao";color:Colors.primary;stroke:1.5 }
    TextInput {
        id:input
        x:40;width:parent.width-50;height:parent.height
        clip:true;selectByMouse:true
        verticalAlignment:TextInput.AlignVCenter
        font.family:"Rajdhani";font.pixelSize:17;color:Colors.fg
        selectionColor:Qt.alpha(Colors.primary,.35)
        onTextEdited:search.edited(text)
        onAccepted:search.accepted()
        Accessible.name:search.placeholder
    }
    Text { x:40;anchors.verticalCenter:parent.verticalCenter;visible:!input.text;text:search.placeholder;font:input.font;color:Qt.alpha(Colors.fg,.62) }
}
