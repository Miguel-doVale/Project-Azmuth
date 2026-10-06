// Project Azmuth — área de transferência (Super + Shift + V), sobre o cliphist.
// Lista + prévia, filtros por tipo, fixados (persistem), amostra de cores,
// miniaturas de imagens. ↑/↓ navega, Enter copia, Ctrl+P fixa, Del apaga,
// Tab troca o filtro, Esc fecha.

import QtQuick
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
    readonly property string pinsPath: Quickshell.env("HOME") + "/.local/state/azmuth/clip-pins.json"

    property var entries: []          // [{id, raw, text, kind, meta}]
    property var pins: []             // textos fixados
    property string query: ""
    property int filter: 0
    readonly property var filters: [
        { name: "TUDO", kind: "" }, { name: "TEXTO", kind: "text" }, { name: "LINKS", kind: "link" },
        { name: "CORES", kind: "color" }, { name: "IMAGENS", kind: "image" }, { name: "FIXADOS", kind: "pin" }
    ]
    property int stamp: 0

    readonly property var filtered: {
        const q = query.toLowerCase(), want = filters[filter].kind
        const pinned = pins.map(t => ({ id: "", raw: t, text: t, kind: classify(t), meta: "", pinned: true }))
        const rest = entries.filter(e => !pins.includes(e.text)).map(e => Object.assign({ pinned: false }, e))
        let all = want === "pin" ? pinned : pinned.concat(rest)
        if (want && want !== "pin") all = all.filter(e => e.kind === want || (want === "text" && (e.kind === "code" || e.kind === "path")))
        return q ? all.filter(e => e.text.toLowerCase().includes(q)) : all
    }
    readonly property var current: filtered[list.currentIndex] || null

    function classify(t) {
        const s = t.trim()
        if (/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(s) || /^rgba?\(/i.test(s)) return "color"
        if (/^(https?|ftp):\/\/\S+$/i.test(s)) return "link"
        if (/^(~|\/)[^\s]*$/.test(s) && s.length > 1) return "path"
        if (/[{};]|=>|\bdef |\bfunction |\bimport /.test(s) && s.includes("\n")) return "code"
        return "text"
    }
    readonly property var kindIcon: ({ text: "", link: "", color: "", path: "", code: "", image: "" })

    function toggle() {
        if (open) { open = false; return }
        query = ""; search.text = ""; filter = 0
        pinsFile.reload()
        listProc.running = true
        open = true
        search.forceActiveFocus()
    }
    function copy(e) {
        if (!e) return
        if (e.id) Quickshell.execDetached(["sh", "-c", "cliphist decode " + e.id + " | wl-copy"])
        else Quickshell.execDetached(["wl-copy", e.text])
        open = false
    }
    function remove(e) {
        if (!e) return
        if (e.pinned) { togglePin(e); return }
        Quickshell.execDetached(["sh", "-c", "printf '%s\\t%s\\n' \"$1\" \"$2\" | cliphist delete", "sh", e.id, e.raw])
        entries = entries.filter(x => x.id !== e.id)
    }
    property bool wipeArmed: false
    Timer { id: wipeDisarm; interval: 3000; onTriggered: cb.wipeArmed = false }
    function wipe() {
        if (!wipeArmed) { wipeArmed = true; wipeDisarm.restart(); return }
        wipeArmed = false
        Quickshell.execDetached(["sh", "-c", "cliphist wipe; rm -rf \"$1\"", "sh", cache])
        entries = []
    }
    function togglePin(e) {
        if (!e || e.kind === "image") return
        pins = pins.includes(e.text) ? pins.filter(t => t !== e.text) : [e.text].concat(pins)
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"", "sh", pinsPath, JSON.stringify(pins)])
    }

    visible: open || reveal > 0.01
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-clipboard"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    FileView {
        id: pinsFile
        path: cb.pinsPath
        onLoaded: { try { cb.pins = JSON.parse(text()) || [] } catch (e) { cb.pins = [] } }
        onLoadFailed: cb.pins = []
    }
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
                    out.push(m ? { id: id, raw: text, text: "imagem " + m[3], kind: "image", meta: m[3] + " · " + m[1] }
                               : { id: id, raw: text, text: text, kind: cb.classify(text), meta: "" })
                    if (out.length >= 400) break
                }
                cb.entries = out
                list.currentIndex = 0
                thumbProc.running = true
            }
        }
    }
    Process {   // miniaturas das imagens que ainda não estão no cache
        id: thumbProc
        command: ["sh", "-c", "mkdir -p \"$1\"; cliphist list | grep -F '[[ binary data' | head -80 | cut -f1 | while read id; do [ -s \"$1/$id\" ] || cliphist decode \"$id\" > \"$1/$id\"; done", "sh", cb.cache]
        onExited: cb.stamp++
    }
    // texto completo do item selecionado (a lista do cliphist vem truncada)
    property string fullText: ""
    Process {
        id: fullProc
        stdout: StdioCollector { onStreamFinished: cb.fullText = this.text }
    }
    onCurrentChanged: {
        fullText = current && current.kind !== "image" ? current.text : ""
        if (current && current.id && current.kind !== "image") {
            fullProc.command = ["sh", "-c", "cliphist decode \"$1\" | head -c 20000", "sh", current.id]
            fullProc.running = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.55 * cb.reveal
        MouseArea { anchors.fill: parent; onClicked: cb.open = false }
    }

    Rectangle {
        id: card
        width: Math.min(parent.width * 0.86, 1080)
        height: Math.min(parent.height * 0.8, 700)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - cb.reveal) * 40
        opacity: cb.reveal
        radius: 14
        color: Qt.alpha(cb.bg, 0.97)
        border.width: 1.5
        border.color: Qt.alpha(cb.primary, 0.6)
        MouseArea { anchors.fill: parent }
            Rectangle {   // apagar tudo (2 cliques; fixados ficam)
                anchors.right: parent.right; anchors.rightMargin: 22
                anchors.top: parent.top; anchors.topMargin: 16
                height: 28; width: wt.implicitWidth + 26; radius: 14
                color: cb.wipeArmed ? "#ff5a5a" : (wm.containsMouse ? Qt.alpha("#ff5a5a", 0.15) : "transparent")
                border.width: 1; border.color: "#ff5a5a"
                Text {
                    id: wt
                    anchors.centerIn: parent
                    text: cb.wipeArmed ? "\uf1f8  CONFIRMAR?" : "\uf1f8  APAGAR TUDO"
                    font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold
                    color: cb.wipeArmed ? cb.bg : "#ff5a5a"
                }
                MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cb.wipe() }
            }

        // ── cabeçalho: título, busca, filtros ──
        Column {
            id: header
            x: 22; y: 18
            width: parent.width - 44
            spacing: 12
            Row {
                spacing: 12
                Text { text: ""; font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 18; color: cb.primary; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "ÁREA DE TRANSFERÊNCIA"; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 15; font.letterSpacing: 2; color: cb.primary; anchors.verticalCenter: parent.verticalCenter }
                Text { text: cb.filtered.length + " itens · " + cb.pins.length + " fixados"; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15; color: Qt.alpha(cb.fg, 0.5); anchors.verticalCenter: parent.verticalCenter }
            }
            Rectangle {
                width: parent.width; height: 42; radius: 8
                color: Qt.alpha(cb.primary, 0.07)
                border.width: search.activeFocus ? 2 : 1
                border.color: Qt.alpha(cb.primary, search.activeFocus ? 0.9 : 0.35)
                Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: ""; font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 14; color: Qt.alpha(cb.fg, 0.5) }
                TextInput {
                    id: search
                    anchors.fill: parent; anchors.leftMargin: 40; anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 17
                    color: cb.fg
                    selectionColor: cb.primary
                    onTextChanged: { cb.query = text; list.currentIndex = 0 }
                    Keys.onPressed: event => {
                        const ctrl = event.modifiers & Qt.ControlModifier
                        if (event.key === Qt.Key_Escape) cb.open = false
                        else if (event.key === Qt.Key_Down) list.incrementCurrentIndex()
                        else if (event.key === Qt.Key_Up) list.decrementCurrentIndex()
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) cb.copy(cb.current)
                        else if (event.key === Qt.Key_Delete) cb.remove(cb.current)
                        else if (ctrl && event.key === Qt.Key_P) cb.togglePin(cb.current)
                        else if (event.key === Qt.Key_Tab) { cb.filter = (cb.filter + 1) % cb.filters.length; list.currentIndex = 0 }
                        else if (event.key === Qt.Key_Backtab) { cb.filter = (cb.filter + cb.filters.length - 1) % cb.filters.length; list.currentIndex = 0 }
                        else return
                        event.accepted = true
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: search.text.length === 0; text: "Buscar no histórico…"; font: search.font; color: Qt.alpha(cb.fg, 0.35) }
                }
            }
            Row {   // filtros
                spacing: 8
                Repeater {
                    model: cb.filters
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: cb.filter === index
                        height: 26; width: ft.implicitWidth + 22; radius: 13
                        color: on ? cb.primary : (fm.containsMouse ? Qt.alpha(cb.primary, 0.12) : "transparent")
                        border.width: 1; border.color: Qt.alpha(cb.primary, on ? 1 : 0.4)
                        Text { id: ft; anchors.centerIn: parent; text: parent.modelData.name; font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold; color: parent.on ? cb.bg : cb.primary }
                        MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { cb.filter = parent.index; list.currentIndex = 0; search.forceActiveFocus() } }
                    }
                }
            }
        }

        // ── lista ──
        ListView {
            id: list
            anchors { top: header.bottom; topMargin: 14; left: parent.left; leftMargin: 14; bottom: footer.top; bottomMargin: 10 }
            width: card.width * 0.52
            clip: true
            spacing: 5
            model: cb.filtered
            highlightMoveDuration: 120
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: ListView.isCurrentItem
                readonly property bool isColor: modelData.kind === "color"
                width: list.width
                height: modelData.kind === "image" ? 72 : 46
                radius: 8
                color: sel ? Qt.alpha(cb.primary, 0.16) : (hover.containsMouse ? Qt.alpha(cb.primary, 0.07) : "transparent")
                border.width: sel ? 1.5 : 0
                border.color: cb.primary

                Rectangle { x: 0; y: 10; width: 3; height: parent.height - 20; radius: 1.5; color: cb.primary; visible: row.sel }

                // ícone do tipo / amostra de cor / miniatura
                Item {
                    id: lead
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    width: row.modelData.kind === "image" ? 96 : 22; height: row.modelData.kind === "image" ? 58 : 22
                    Text {
                        anchors.centerIn: parent
                        visible: !row.isColor && row.modelData.kind !== "image"
                        text: cb.kindIcon[row.modelData.kind] || ""
                        font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 14
                        color: row.sel ? cb.primary : Qt.alpha(cb.fg, 0.5)
                    }
                    Rectangle {
                        anchors.fill: parent; radius: 6
                        visible: row.isColor
                        color: row.isColor ? row.modelData.text.trim() : "transparent"
                        border.width: 1; border.color: Qt.alpha(cb.fg, 0.3)
                    }
                    Image {
                        anchors.fill: parent
                        visible: row.modelData.kind === "image"
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true; cache: false
                        source: row.modelData.kind === "image" ? "file://" + cb.cache + "/" + row.modelData.id + "?v=" + cb.stamp : ""
                        sourceSize: Qt.size(192, 116)
                    }
                }
                Text {
                    anchors.left: lead.right; anchors.leftMargin: 12
                    anchors.right: pin.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.kind === "image" ? row.modelData.meta : row.modelData.text.replace(/\s+/g, " ")
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: row.modelData.kind === "image" ? "Orbitron" : "JetBrainsMono Nerd Font"
                    font.pixelSize: row.modelData.kind === "image" ? 11 : 13
                    color: row.modelData.kind === "link" ? cb.primary : (row.modelData.kind === "image" ? Qt.alpha(cb.fg, 0.6) : cb.fg)
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: list.currentIndex = row.index
                    onClicked: cb.copy(row.modelData)
                }
                Text {   // fixar
                    id: pin
                    anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.modelData.kind !== "image" && (row.sel || row.modelData.pinned)
                    text: ""
                    font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 13
                    rotation: row.modelData.pinned ? 0 : 45
                    color: row.modelData.pinned ? cb.primary : (pinMouse.containsMouse ? cb.primary : Qt.alpha(cb.fg, 0.4))
                    MouseArea { id: pinMouse; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cb.togglePin(row.modelData) }
                }
            }
        }

        // ── prévia ──
        Rectangle {
            id: preview
            anchors { top: header.bottom; topMargin: 14; left: list.right; leftMargin: 14; right: parent.right; rightMargin: 14; bottom: footer.top; bottomMargin: 10 }
            radius: 10
            color: Qt.alpha(cb.primary, 0.04)
            border.width: 1; border.color: Qt.alpha(cb.primary, 0.2)
            clip: true
            readonly property var e: cb.current

            Text {
                anchors.centerIn: parent
                visible: !preview.e
                text: "Nada selecionado"
                font.family: "Rajdhani"; font.pixelSize: 15; color: Qt.alpha(cb.fg, 0.4)
            }
            Column {
                visible: !!preview.e
                anchors.fill: parent; anchors.margins: 16
                spacing: 10
                Row {
                    spacing: 8
                    Text {
                        text: preview.e ? (cb.kindIcon[preview.e.kind] || "") : ""
                        font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 12; color: cb.primary
                    }
                    Text {
                        text: !preview.e ? "" : ({ text: "TEXTO", link: "LINK", color: "COR", path: "CAMINHO", code: "CÓDIGO", image: "IMAGEM" })[preview.e.kind]
                              + (preview.e.pinned ? " · FIXADO" : "")
                              + (preview.e.kind === "image" ? " · " + preview.e.meta
                                 : " · " + cb.fullText.length + " caracteres · " + (cb.fullText.split("\n").length) + " linhas")
                        font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1; color: cb.primary
                    }
                }
                Rectangle {   // cor em destaque
                    visible: preview.e && preview.e.kind === "color"
                    width: parent.width; height: 90; radius: 10
                    color: preview.e && preview.e.kind === "color" ? preview.e.text.trim() : "transparent"
                    border.width: 1; border.color: Qt.alpha(cb.fg, 0.3)
                }
                Image {
                    visible: preview.e && preview.e.kind === "image"
                    width: parent.width; height: parent.height - 30
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true; cache: false
                    source: preview.e && preview.e.kind === "image" ? "file://" + cb.cache + "/" + preview.e.id + "?v=" + cb.stamp : ""
                }
                Flickable {
                    visible: preview.e && preview.e.kind !== "image"
                    width: parent.width; height: parent.height - 30 - (preview.e && preview.e.kind === "color" ? 100 : 0)
                    contentHeight: full.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Text {
                        id: full
                        width: parent.width
                        text: cb.fullText
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13
                        color: cb.fg
                    }
                }
            }
        }

        Text {
            id: footer
            anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            text: "↑/↓ navegar    ENTER copiar    CTRL+P fixar    DEL apagar    TAB filtro    ESC fechar"
            font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14; font.letterSpacing: 1
            color: Qt.alpha(cb.fg, 0.5)
        }
    }
}
