// Project Azmuth — um símbolo (runa) do alfabeto Galvan. Ver Galvan.js / tools/gen_galvan.py.
import QtQuick
import QtQuick.Shapes
import "Galvan.js" as Galvan

Shape {
    id: g
    property string name: "mente"
    property color color: "#38bdf8"
    property real stroke: 2
    readonly property var def: Galvan.byId(name)
    width: 24; height: 24
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: g.color
        strokeWidth: g.stroke * 24 / Math.max(1, g.width)   // espessura constante em pixels
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        scale: Qt.size(g.width / 24, g.height / 24)
        PathSvg { path: g.def.path }
    }
    ShapePath {   // nós nas pontas soltas
        strokeWidth: 0
        fillColor: g.color
        scale: Qt.size(g.width / 24, g.height / 24)
        PathSvg { path: g.def.nodes || "" }
    }
}
