// Project Azmuth — cascata de saída/entrada de som (abre embaixo do botão "Fone USB ▾" do painel).
import QtQuick
import Quickshell.Services.Pipewire

Rectangle {
    id: picker
    property color primary: Colors.primary
    property color fg: Colors.fg
    property bool open: false
    signal chosen()

    readonly property var all: Pipewire.nodes.values.filter(n => n.audio && !n.isStream && !(n.name || "").startsWith("easyeffects"))
    readonly property var sinks: all.filter(n => n.isSink)
    readonly property var sources: all.filter(n => !n.isSink && !(n.name || "").includes(".monitor"))
    function label(n) { return n ? (n.nickname || n.description || n.name) : "—" }

    width: 360; height: Math.max(outCol.height, inCol.height) + 16
    radius: 12
    color: "#0e1626"
    border.width: 1; border.color: Qt.alpha(primary, 0.4)
    opacity: open ? 1 : 0
    visible: opacity > 0
    y: open ? 0 : -6
    Behavior on opacity { NumberAnimation { duration: 220 } }
    Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    component Choice: Rectangle {
        id: ch
        required property var node
        required property bool current
        signal pick()
        width: parent.width; height: 26; radius: 8
        color: area.containsMouse ? Qt.alpha(picker.primary, 0.12) : "transparent"
        Text {
            anchors.left: parent.left; anchors.leftMargin: 8; anchors.right: mark.left; anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: picker.label(ch.node); elide: Text.ElideRight
            font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 13; color: picker.fg
        }
        Text { id: mark; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
               text: ch.current ? "✓" : ""; color: picker.primary; font.pixelSize: 13 }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: ch.pick() }
    }

    Column {
        id: outCol
        x: 8; y: 8; width: (picker.width - 22) / 2; spacing: 2
        Text { text: "SAÍDA"; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 9; font.letterSpacing: 1.5; color: picker.primary; leftPadding: 8; bottomPadding: 3 }
        Repeater {
            model: picker.sinks
            Choice {
                required property var modelData
                node: modelData; current: Pipewire.defaultAudioSink === modelData
                onPick: { Pipewire.preferredDefaultAudioSink = modelData; picker.chosen() }
            }
        }
    }
    Column {
        id: inCol
        x: outCol.x + outCol.width + 6; y: 8; width: outCol.width; spacing: 2
        Text { text: "ENTRADA"; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 9; font.letterSpacing: 1.5; color: picker.primary; leftPadding: 8; bottomPadding: 3 }
        Repeater {
            model: picker.sources
            Choice {
                required property var modelData
                node: modelData; current: Pipewire.defaultAudioSource === modelData
                onPick: { Pipewire.preferredDefaultAudioSource = modelData; picker.chosen() }
            }
        }
    }
}
