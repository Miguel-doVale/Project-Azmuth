// Project Azmuth — o disco do Omnitrix como peça reutilizável (mesmo visual do HUD):
// halo, aro com 4 garras, marcador no topo, anel de slots e face central.
// Usado pelo menu de energia, lançador e tela de bloqueio — "o mesmo relógio,
// outra função". O conteúdo da face vem de fora (default property).
//
//   items: [{ icon: "" | image: "file:///…", color: "#hex", dim: bool }]
//   index: slot selecionado (fica no topo). Com mais itens que `maxSlots`, a roda
//   vira "infinita": cada slot mostra o item mais próximo daquela posição.

import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets

Item {
    id: od

    property real size: 400
    property color accent: "#38bdf8"
    property var items: []
    property int index: 0
    property int turn: index                    // posição angular sem limite (roda infinita gira sempre pro lado certo)
    property int maxSlots: 12
    property bool showSlots: true
    property real kick: 0                       // tranco do aro (graus), volta sozinho
    default property alias faceContent: faceSlot.data
    readonly property real faceSize: size * 0.58
    readonly property int slotCount: Math.max(1, Math.min(items.length, maxSlots))
    readonly property real step: 360 / slotCount

    width: size; height: size

    function shake() { shakeAnim.restart() }
    function nudge(dir) { kickAnim.stop(); kick = dir * 16; kickAnim.start() }

    // item mostrado no slot k (roda infinita quando há mais itens que slots)
    function itemAt(k) {
        const n = items.length
        if (n <= slotCount) return k < n ? k : -1
        const half = Math.floor(slotCount / 2)
        const top = ((turn % slotCount) + slotCount) % slotCount
        let d = ((k - top) % slotCount + slotCount) % slotCount
        if (d >= half) d -= slotCount
        return ((index + d) % n + n) % n
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation { target: od; property: "anchors.horizontalCenterOffset"; to: -14; duration: 45 }
        NumberAnimation { target: od; property: "anchors.horizontalCenterOffset"; to: 12; duration: 70 }
        NumberAnimation { target: od; property: "anchors.horizontalCenterOffset"; to: -6; duration: 60 }
        NumberAnimation { target: od; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
    }
    NumberAnimation { id: kickAnim; target: od; property: "kick"; to: 0; duration: 420; easing.type: Easing.OutElastic; easing.amplitude: 1.2; easing.period: 0.45 }

    // halo
    Rectangle {
        anchors.centerIn: parent
        width: od.size * 1.06; height: width; radius: width / 2
        color: "transparent"
        border.width: od.size * 0.05
        border.color: Qt.alpha(od.accent, 0.18)
        Behavior on border.color { ColorAnimation { duration: 220 } }
    }

    // aro com garras (gira no "tranco")
    Rectangle {
        id: bezel
        anchors.fill: parent
        radius: width / 2
        rotation: od.kick
        color: "#15181b"
        border.width: 3
        border.color: Qt.alpha(od.accent, 0.55)
        Behavior on border.color { ColorAnimation { duration: 220 } }
        Repeater {
            model: 4
            Rectangle {
                required property int index
                readonly property real a: (45 + 90 * index) * Math.PI / 180
                width: bezel.width * 0.09; height: bezel.width * 0.035; radius: height / 2
                color: "#2a2f35"
                x: bezel.width / 2 + Math.cos(a) * bezel.width * 0.465 - width / 2
                y: bezel.height / 2 + Math.sin(a) * bezel.height * 0.465 - height / 2
                rotation: 135 + 90 * index
            }
        }
    }

    // marcador do slot selecionado
    Shape {
        visible: od.showSlots
        anchors.horizontalCenter: parent.horizontalCenter
        y: -od.size * 0.035
        width: od.size * 0.06; height: width * 0.7
        ShapePath {
            strokeWidth: 0; fillColor: od.accent
            startX: 0; startY: 0
            PathLine { x: od.size * 0.06; y: 0 }
            PathLine { x: od.size * 0.03; y: od.size * 0.042 }
            PathLine { x: 0; y: 0 }
        }
    }

    // anel de slots
    Item {
        id: spin
        visible: od.showSlots
        anchors.fill: parent
        rotation: -od.turn * od.step
        Behavior on rotation { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
    Item {
        id: dial
        anchors.fill: parent
        rotation: od.kick
        readonly property real total: spin.rotation + rotation
        Repeater {
            model: od.slotCount
            Item {
                id: slot
                required property int index
                readonly property int item: od.itemAt(index)
                readonly property var d: item >= 0 ? od.items[item] : null
                readonly property bool selected: item === od.index
                readonly property real a: index * od.step * Math.PI / 180
                width: od.size * 0.13; height: width
                x: od.size / 2 + Math.sin(a) * od.size * 0.405 - width / 2
                y: od.size / 2 - Math.cos(a) * od.size * 0.405 - height / 2
                visible: d !== null

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    readonly property color c: slot.d ? (slot.d.color || od.accent) : od.accent
                    color: slot.selected ? Qt.alpha(c, 0.25) : "#0d0f11"
                    border.width: slot.selected ? 3 : 1.5
                    border.color: slot.d && slot.d.dim ? "#3a4048" : c
                    scale: slot.selected ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent
                        rotation: -dial.total
                        visible: slot.d && !slot.d.image && !slot.d.glyph
                        text: slot.d ? (slot.d.icon || "") : ""
                        font.family: "Font Awesome 7 Free"; font.styleName: "Solid"
                        font.pixelSize: parent.width * 0.36
                        color: slot.d && slot.d.dim ? "#4a525c" : parent.c
                    }
                    Glyph {   // slot com runa Galvan: { glyph: "chave" }
                        anchors.centerIn: parent
                        rotation: -dial.total
                        visible: slot.d && !!slot.d.glyph
                        width: parent.width * 0.5; height: width
                        name: slot.d && slot.d.glyph ? slot.d.glyph : "nucleo"
                        color: parent.c
                        stroke: 1.8
                    }
                    IconImage {
                        anchors.centerIn: parent
                        rotation: -dial.total
                        visible: slot.d && !!slot.d.image
                        implicitSize: parent.width * 0.6
                        source: slot.d && slot.d.image ? slot.d.image : ""
                        asynchronous: true
                    }
                }
            }
        }
    }

    }

    // face
    Rectangle {
        id: face
        anchors.centerIn: parent
        width: od.faceSize; height: width; radius: width / 2
        color: "#07090b"
        border.width: 5
        border.color: od.accent
        Behavior on border.color { ColorAnimation { duration: 220 } }
        Item { id: faceSlot; anchors.fill: parent }
    }
}
