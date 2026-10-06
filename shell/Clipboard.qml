// Project Azmuth — área de transferência (Super + Shift + V), sobre o cliphist.
// Busca ao digitar, miniaturas de imagens, ↑/↓ + Enter copia, Delete apaga, Esc fecha.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: cb

    required property var theme
    property bool open: false
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: cb.open ? 260 : 160; easing.type: Easing.OutCubic } }

    readonly property color primary: theme.primary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property string cache: Quickshell.env("HOME") + "/.cache/azmuth/clip"

    property var entries: []          // [{id, text, image, meta}]
    property string query: ""
    property int stamp: 0             // força recarregar miniaturas
    readonly property var filtered: {
        const q = query.toLowerCase()
        return q ? entries.filter(e => e.text.toLowerCase().includes(q)) : entries
    }

    function toggle() {
        if (open) { open = false; return }
        query = ""
        search.text = ""
        listProc.running = true
        open = true
        search.forceActiveFocus()
    }
    function copy(e) {
        if (!e) return
        Quickshell.execDetached(["sh", "-c", "cliphist decode " + e.id + " | wl-copy"])
        open = false
    }
    function remove(e) {
        if (!e) return
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t%s\\n' \"$1\" \"$2\" | cliphist delete", "sh", e.id, e.raw])
        entries = entries.filter(x => x.id !== e.id)
    }

    visible: open || reveal > 0.01
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-clipboard"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of this.text.split("\n")) {
                    const tab = line.indexOf("\t")
                    if (tab < 0) continue
                    const id = line.slice(0, tab), text = line.slice(tab + 1)
                    const m = text.match(/^\[\[ binary data (.+?) (png|jpe?g|webp|gif|bmp) (\d+x\d+) \]\]$/)
                    out.push({ id: id, raw: text, text: m ? "imagem " + m[3] : text, image: !!m, meta: m ? m[3] + " · " + m[1] : "" })
                    if (out.length >= 300) break
                }
                cb.entries = out
                list.currentIndex = 0
                thumbProc.running = true
            }
        }
    }
    // gera miniaturas das imagens que ainda não estão no cache
    Process {
        id: thumbProc
        command: ["sh", "-c", "mkdir -p \"$1\"; cliphist list | grep -F '[[ binary data' | head -60 | cut -f1 | while read id; do [ -s \"$1/$id\" ] || cliphist decode \"$id\" > \"$1/$id\"; done", "sh", cb.cache]
        onExited: cb.stamp++
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.5 * cb.reveal
        MouseArea { anchors.fill: parent; onClicked: cb.open = false }
    }

    Rectangle {
        id: card
        width: 720
        height: Math.min(parent.height * 0.78, 680)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - cb.reveal) * 40
        opacity: cb.reveal
        radius: 14
        color: Qt.alpha(cb.bg, 0.97)
        border.width: 1.5
        border.color: Qt.alpha(cb.primary, 0.6)
        MouseArea { anchors.fill: parent }   // não fecha ao clicar dentro

        Column {
            id: header
            x: 22; y: 18
            width: parent.width - 44
            spacing: 14
            Row {
                spacing: 12
                Text {
                    text: ""
                    font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 18
                    color: cb.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "ÁREA DE TRANSFERÊNCIA"
                    font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 15; font.letterSpacing: 2
                    color: cb.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: cb.filtered.length + " itens"
                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15
                    color: Qt.alpha(cb.fg, 0.5)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Rectangle {   // busca
                width: parent.width; height: 44; radius: 8
                color: Qt.alpha(cb.primary, 0.07)
                border.width: search.activeFocus ? 2 : 1
                border.color: Qt.alpha(cb.primary, search.activeFocus ? 0.9 : 0.35)
                Text {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 14
                    color: Qt.alpha(cb.fg, 0.5)
                }
                TextInput {
                    id: search
                    anchors.fill: parent; anchors.leftMargin: 40; anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 17
                    color: cb.fg
                    selectionColor: cb.primary
                    onTextChanged: { cb.query = text; list.currentIndex = 0 }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) cb.open = false
                        else if (event.key === Qt.Key_Down) list.incrementCurrentIndex()
                        else if (event.key === Qt.Key_Up) list.decrementCurrentIndex()
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) cb.copy(cb.filtered[list.currentIndex])
                        else if (event.key === Qt.Key_Delete) cb.remove(cb.filtered[list.currentIndex])
                        else return
                        event.accepted = true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length === 0
                        text: "Buscar no histórico…"
                        font: search.font
                        color: Qt.alpha(cb.fg, 0.35)
                    }
                }
            }
        }

        ListView {
            id: list
            anchors { top: header.bottom; topMargin: 14; left: parent.left; right: parent.right; bottom: footer.top; margins: 14 }
            clip: true
            spacing: 6
            model: cb.filtered
            highlightMoveDuration: 120
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: ListView.isCurrentItem
                width: list.width
                height: modelData.image ? 112 : Math.min(74, txt.implicitHeight + 24)
                radius: 8
                color: sel ? Qt.alpha(cb.primary, 0.16) : (hover.containsMouse ? Qt.alpha(cb.primary, 0.07) : "transparent")
                border.width: sel ? 1.5 : 0
                border.color: cb.primary

                Rectangle {   // filete de seleção
                    x: 0; y: 10; width: 3; height: parent.height - 20; radius: 1.5
                    color: cb.primary
                    visible: row.sel
                }

                Image {
                    id: thumb
                    visible: row.modelData.image
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    width: 150; height: 92
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    source: row.modelData.image ? "file://" + cb.cache + "/" + row.modelData.id + "?v=" + cb.stamp : ""
                    sourceSize: Qt.size(300, 184)
                }
                Text {
                    id: txt
                    anchors.left: row.modelData.image ? thumb.right : parent.left
                    anchors.leftMargin: row.modelData.image ? 16 : 16
                    anchors.right: trash.left; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.image ? row.modelData.meta : row.modelData.text
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: row.modelData.image ? "Orbitron" : "JetBrainsMono Nerd Font"
                    font.pixelSize: row.modelData.image ? 11 : 14
                    color: row.modelData.image ? Qt.alpha(cb.fg, 0.6) : cb.fg
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = row.index
                    onClicked: cb.copy(row.modelData)
                }
                Text {
                    id: trash
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 14
                    color: trashMouse.containsMouse ? "#ff5a5a" : Qt.alpha(cb.fg, 0.4)
                    visible: row.sel
                    MouseArea {
                        id: trashMouse
                        anchors.fill: parent; anchors.margins: -8
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: cb.remove(row.modelData)
                    }
                }
            }
        }

        Text {
            id: footer
            anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            text: "↑/↓ navegar      ENTER copiar      DEL apagar      ESC fechar"
            font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14; font.letterSpacing: 1
            color: Qt.alpha(cb.fg, 0.5)
        }
    }
}
