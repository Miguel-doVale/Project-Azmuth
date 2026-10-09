// Project Azmuth — aba Som da Central (PipeWire): saída/entrada padrão, volume por
// dispositivo e por app, e um visualizador com o nível REAL do áudio que está tocando.

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire

Item {
    id: sp
    property bool active: false

    readonly property var all: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: all.filter(n => n.isSink && !n.isStream)
    readonly property var sources: all.filter(n => !n.isSink && !n.isStream && !(n.name || "").includes(".monitor"))
    readonly property var streams: all.filter(n => n.isStream && n.isSink)   // apps tocando
    readonly property var out: Pipewire.defaultAudioSink

    PwObjectTracker { objects: sp.all }

    function nameOf(n) {
        const p = n.properties || {}
        return p["application.name"] || n.nickname || n.description || n.name
    }
    function iconOf(n) {
        const p = n.properties || {}
        const name = p["application.icon-name"] || p["application.process.binary"] || p["application.name"] || ""
        return Quickshell.iconPath(String(name).toLowerCase(), true) || Quickshell.iconPath("audio-volume-high", true) || ""
    }

    // nível real do que está tocando na saída padrão
    PwNodePeakMonitor { id: peak; node: sp.out; enabled: sp.active }

    component Device: Rectangle {
        id: dv
        property var node: null
        property bool isDefault: false
        property string kind: "out"     // out | in
        signal choose
        width: parent ? parent.width : 0; height: 68; radius: 10
        color: isDefault ? Qt.alpha(Colors.primary, 0.1) : (dm.containsMouse ? Qt.alpha(Colors.primary, 0.05) : "transparent")
        border.width: isDefault ? 1.5 : 0; border.color: Qt.alpha(Colors.primary, 0.6)
        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dv.choose() }
        Glyph { x: 16; y: 14; width: 22; height: 22; name: dv.kind === "out" ? "som" : "mente"; color: dv.isDefault ? Colors.primary : Qt.alpha(Colors.fg, 0.5); stroke: 1.8 }
        Text {
            x: 52; y: 10; width: parent.width - 52 - 200; elide: Text.ElideRight
            text: dv.node ? (dv.node.nickname || dv.node.description || dv.node.name) : ""
            font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: dv.isDefault ? Colors.primary : Colors.fg
        }
        Text {
            x: 52; y: 34
            text: dv.isDefault ? "PADRÃO" : "clique para usar"
            font.family: dv.isDefault ? "Orbitron" : "Rajdhani"; font.pixelSize: dv.isDefault ? 9 : 13; font.weight: Font.Bold
            color: Qt.alpha(Colors.fg, 0.5)
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            UiSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: 130
                maximum: 1.5
                value: dv.node && dv.node.audio ? dv.node.audio.volume : 0
                tint: dv.node && dv.node.audio && dv.node.audio.muted ? Qt.alpha(Colors.fg, 0.3) : Colors.primary
                onMoved: v => { if (dv.node && dv.node.audio) dv.node.audio.volume = v }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 40; horizontalAlignment: Text.AlignRight
                text: dv.node && dv.node.audio ? Math.round(dv.node.audio.volume * 100) + "%" : ""
                font.family: "Orbitron"; font.pixelSize: 11; font.weight: Font.Bold; color: Colors.fg
            }
            UiButton {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                glyph: "fantasma"
                tint: dv.node && dv.node.audio && dv.node.audio.muted ? Colors.danger : Qt.alpha(Colors.fg, 0.6)
                onClicked: if (dv.node && dv.node.audio) dv.node.audio.muted = !dv.node.audio.muted
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: Math.min(parent.width, 700)
            spacing: 8

            // ── visualizador ──
            Rectangle {
                width: parent.width; height: 120; radius: 12
                color: Qt.alpha(Colors.primary, 0.05)
                border.width: 1; border.color: Qt.alpha(Colors.primary, 0.3)
                Column {
                    x: 18; anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: "TOCANDO EM"; font.family: "Orbitron"; font.pixelSize: 10; font.letterSpacing: 2; color: Qt.alpha(Colors.fg, 0.55) }
                    Text { width: 230; elide: Text.ElideRight; text: sp.out ? (sp.out.nickname || sp.out.description || "") : "—"; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 18; color: Colors.primary }
                    Text {
                        text: sp.out && sp.out.audio ? (sp.out.audio.muted ? "MUDO" : "volume " + Math.round(sp.out.audio.volume * 100) + "%") : ""
                        font.family: "Orbitron"; font.pixelSize: 11; font.weight: Font.Bold; color: sp.out && sp.out.audio && sp.out.audio.muted ? Colors.danger : Colors.fg
                    }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    height: 80
                    Repeater {
                        model: 28
                        Rectangle {
                            required property int index
                            anchors.bottom: parent.bottom
                            width: 7; radius: 3
                            // nível real (pico) com uma "forma" de onda pela posição da barra
                            readonly property real shape: 0.45 + 0.55 * Math.abs(Math.sin(index * 0.7 + phase.t))
                            height: 4 + 76 * Math.min(1, peak.peak * 1.6 * shape)
                            color: Qt.alpha(Colors.primary, 0.35 + 0.65 * shape)
                            Behavior on height { NumberAnimation { duration: 90 } }
                        }
                    }
                }
                QtObject { id: phase; property real t: 0 }
                Timer { interval: 60; repeat: true; running: sp.active; onTriggered: phase.t += 0.35 }
            }

            UiSection { text: "SAÍDA" }
            Repeater {
                model: sp.sinks
                Device {
                    required property var modelData
                    width: col.width
                    node: modelData
                    isDefault: sp.out === modelData
                    onChoose: Pipewire.preferredDefaultAudioSink = modelData
                }
            }

            UiSection { text: "ENTRADA (MICROFONE)" }
            Repeater {
                model: sp.sources
                Device {
                    required property var modelData
                    width: col.width
                    kind: "in"
                    node: modelData
                    isDefault: Pipewire.defaultAudioSource === modelData
                    onChoose: Pipewire.preferredDefaultAudioSource = modelData
                }
            }

            UiSection { text: "APPS TOCANDO AGORA · " + sp.streams.length }
            Text {
                visible: sp.streams.length === 0
                text: "Nenhum app tocando som agora."
                font.family: "Rajdhani"; font.pixelSize: 15; color: Qt.alpha(Colors.fg, 0.5)
            }
            Repeater {
                model: sp.streams
                Item {
                    required property var modelData
                    width: col.width; height: 52
                    IconImage { x: 12; anchors.verticalCenter: parent.verticalCenter; implicitSize: 28; source: sp.iconOf(parent.modelData) }
                    Column {
                        x: 52; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 52 - 260
                        Text { width: parent.width; elide: Text.ElideRight; text: sp.nameOf(parent.parent.modelData); font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: Colors.fg }
                        Text { width: parent.width; elide: Text.ElideRight; text: (parent.parent.modelData.properties || {})["media.name"] || ""; font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(Colors.fg, 0.5) }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        UiSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 130
                            value: parent.parent.modelData.audio ? parent.parent.modelData.audio.volume : 0
                            onMoved: v => { if (parent.parent.modelData.audio) parent.parent.modelData.audio.volume = v }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40; horizontalAlignment: Text.AlignRight
                            text: parent.parent.modelData.audio ? Math.round(parent.parent.modelData.audio.volume * 100) + "%" : ""
                            font.family: "Orbitron"; font.pixelSize: 11; font.weight: Font.Bold; color: Colors.fg
                        }
                        UiButton {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 30; glyph: "fantasma"
                            tint: parent.parent.modelData.audio && parent.parent.modelData.audio.muted ? Colors.danger : Qt.alpha(Colors.fg, 0.6)
                            onClicked: if (parent.parent.modelData.audio) parent.parent.modelData.audio.muted = !parent.parent.modelData.audio.muted
                        }
                    }
                }
            }
        }
    }
}
