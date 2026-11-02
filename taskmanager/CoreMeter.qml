import QtQuick
import QtQuick.Shapes
import "components"

Item {
    id: meter
    property real cpu: 0
    property real ram: 0
    property bool live: true
    property string label:"CPU"
    Behavior on cpu { NumberAnimation {duration:200;easing.type:Easing.OutCubic} }
    Behavior on ram { NumberAnimation {duration:200;easing.type:Easing.OutCubic} }
    function scan(){pulse.restart()}
    width:160;height:160
    Shape {
        anchors.fill:parent
        preferredRendererType:Shape.CurveRenderer
        ShapePath { strokeColor:Qt.alpha(Colors.primary,.16);strokeWidth:5;fillColor:"transparent"; PathAngleArc{centerX:80;centerY:80;radiusX:72;radiusY:72;startAngle:0;sweepAngle:360} }
        ShapePath { strokeColor:Colors.primary;strokeWidth:5;fillColor:"transparent";capStyle:ShapePath.RoundCap;PathAngleArc{centerX:80;centerY:80;radiusX:72;radiusY:72;startAngle:-90;sweepAngle:Math.max(.5,meter.cpu*3.6)} }
        ShapePath { strokeColor:Qt.alpha(Colors.fg,.13);strokeWidth:2;fillColor:"transparent";PathAngleArc{centerX:80;centerY:80;radiusX:61;radiusY:61;startAngle:0;sweepAngle:360} }
        ShapePath { strokeColor:Colors.warn;strokeWidth:2;fillColor:"transparent";capStyle:ShapePath.RoundCap;PathAngleArc{centerX:80;centerY:80;radiusX:61;radiusY:61;startAngle:90;sweepAngle:Math.max(.5,meter.ram*3.6)} }
    }
    Rectangle { anchors.centerIn:parent;width:100;height:100;radius:50;color:Qt.alpha(Colors.primary,.05);border.width:1;border.color:Qt.alpha(Colors.primary,.3) }
    Shape {
        id:glass
        anchors.centerIn:parent;width:42;height:46
        ShapePath { strokeWidth:0;fillColor:Colors.primary;PathSvg{path:"M0 0H42L21 21ZM0 46H42L21 25Z"} }
        opacity:meter.live?1:.4
    }
    SequentialAnimation {
        id:pulse
        NumberAnimation {target:glass;property:"scale";to:.76;duration:100;easing.type:Easing.OutCubic}
        NumberAnimation {target:glass;property:"scale";to:1;duration:210;easing.type:Easing.OutBack}
    }
    Text { anchors.horizontalCenter:parent.horizontalCenter;y:167;text:meter.label+" "+Math.round(meter.cpu)+"%";font.family:"JetBrainsMono Nerd Font";font.pixelSize:12;color:Colors.primary }
}
