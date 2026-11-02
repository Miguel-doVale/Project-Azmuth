import QtQuick
import Quickshell
import "components"

Item {
    id: appIcon
    property string iconName: ""
    property string fallback: "portal"
    Glyph {anchors.fill:parent;visible:icon.status!==Image.Ready;name:appIcon.fallback;color:Colors.primary;stroke:1.7}
    Image {
        id:icon
        anchors.fill:parent
        source:appIcon.iconName?Quickshell.iconPath(appIcon.iconName,true):""
        sourceSize:Qt.size(width*2,height*2)
        fillMode:Image.PreserveAspectFit
    }
}
