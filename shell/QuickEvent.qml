// Project Azmuth — evento rápido: clicar num dia de qualquer calendário (widget da área de
// trabalho ou Dashboard) abre este cartão. Título, hora opcional, cor; Enter salva, Esc cancela.

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: qe

    property bool open: false
    property date day: new Date()
    property color pick: "#38bdf8"
    readonly property var colors: ["#4dff8a", "#38bdf8", "#a78bfa", "#f472b6", "#ef4444", "#ffd76a"]

    function show(d) {
        day = d
        title.text = ""; time.text = ""; pick = Colors.primary
        open = true
        title.forceActiveFocus()
    }
    function save() {
        const t = title.text.trim()
        if (!t) return
        const hm = /^([01]?\d|2[0-3]):?([0-5]\d)$/.exec(time.text.trim())
        Events.add({ date: Events.key(day), title: t, time: hm ? hm[1].padStart(2, "0") + ":" + hm[2] : "", color: String(pick), remind: hm ? 10 : -1 })
        open = false
    }

    visible: open
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-quickevent"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.4; MouseArea { anchors.fill: parent; onClicked: qe.open = false } }

    Rectangle {
        anchors.centerIn: parent
        width: 460; height: col.implicitHeight + 40; radius: 14
        color: Qt.alpha(Colors.bg, 0.97)
        border.width: 1.5; border.color: Qt.alpha(Colors.primary, 0.7)
        MouseArea { anchors.fill: parent }
        Column {
            id: col
            x: 20; y: 20; width: parent.width - 40
            spacing: 12
            Row {
                spacing: 10
                Glyph { width: 22; height: 22; name: "tempo"; color: Colors.primary; stroke: 2; anchors.verticalCenter: parent.verticalCenter }
                Text { anchors.verticalCenter: parent.verticalCenter; text: Qt.locale("pt_BR").toString(qe.day, "dddd, d 'de' MMMM").toUpperCase(); font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 13; color: Colors.primary }
            }
            // eventos já marcados no dia
            Repeater {
                model: qe.open ? Events.forDay(qe.day) : []
                Row {
                    required property var modelData
                    spacing: 8
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: parent.modelData.color }
                    Text { text: (parent.modelData.time || "dia todo") + " · " + parent.modelData.title; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.75) }
                }
            }
            Row {
                spacing: 8
                Rectangle {
                    width: col.width - 100; height: 40; radius: 8
                    color: Qt.alpha(Colors.primary, 0.06)
                    border.width: title.activeFocus ? 2 : 1; border.color: Qt.alpha(Colors.primary, title.activeFocus ? 0.9 : 0.35)
                    TextInput {
                        id: title
                        anchors.fill: parent; anchors.margins: 11
                        verticalAlignment: TextInput.AlignVCenter
                        font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 16; color: Colors.fg
                        selectionColor: Colors.primary
                        KeyNavigation.tab: time
                        Keys.onReturnPressed: qe.save()
                        Keys.onEscapePressed: qe.open = false
                        Text { anchors.verticalCenter: parent.verticalCenter; visible: title.text === ""; text: "Novo evento…"; font: title.font; color: Qt.alpha(Colors.fg, 0.35) }
                    }
                }
                Rectangle {
                    width: 92; height: 40; radius: 8
                    color: Qt.alpha(Colors.primary, 0.06)
                    border.width: time.activeFocus ? 2 : 1; border.color: Qt.alpha(Colors.primary, time.activeFocus ? 0.9 : 0.35)
                    TextInput {
                        id: time
                        anchors.fill: parent; anchors.margins: 11
                        verticalAlignment: TextInput.AlignVCenter; horizontalAlignment: TextInput.AlignHCenter
                        maximumLength: 5
                        font.family: "Orbitron"; font.pixelSize: 13; color: Colors.fg
                        selectionColor: Colors.primary
                        KeyNavigation.tab: title
                        Keys.onReturnPressed: qe.save()
                        Keys.onEscapePressed: qe.open = false
                        Text { anchors.centerIn: parent; visible: time.text === ""; text: "HH:MM"; font: time.font; color: Qt.alpha(Colors.fg, 0.35) }
                    }
                }
            }
            Row {
                spacing: 8
                Repeater {
                    model: qe.colors
                    Rectangle {
                        required property string modelData
                        width: 24; height: 24; radius: 12; color: modelData
                        border.width: String(qe.pick) === modelData ? 3 : 0; border.color: Colors.fg
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: qe.pick = parent.modelData }
                    }
                }
            }
            Text { text: "ENTER salva · ESC cancela · com hora, avisa 10 min antes · detalhes na Central → Calendário"; font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(Colors.fg, 0.5) }
        }
    }
}
