// Project Azmuth — lançador de apps (Super + D) com playlists no disco do Omnitrix.
// ←/→ ou scroll no disco: troca de playlist · ↑/↓ app · Enter abre · digitar busca
// em tudo · Ctrl+F (ou clique direito) fixa/desfixa nos Favoritos · Esc fecha.
// Playlists vêm das categorias dos .desktop; Favoritos = fixados + mais usados.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: ln

    required property var theme
    readonly property color primary: theme.primary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/azmuth/launcher.json"

    property bool open: false
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: ln.open ? 300 : 160; easing.type: Easing.OutCubic } }

    property int pl: 0                     // playlist atual
    property string query: ""
    property var data_: ({ pins: [], counts: {} })   // persistido em launcher.json

    readonly property var playlists: [
        { name: "FAVORITOS",  icon: "", color: "#ffd76a", cats: [] },
        { name: "DEV",        icon: "", color: "#4dff8a", cats: ["Development", "IDE", "TerminalEmulator"] },
        { name: "INTERNET",   icon: "", color: "#38bdf8", cats: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging"] },
        { name: "MÍDIA",      icon: "", color: "#f472b6", cats: ["AudioVideo", "Audio", "Video", "Graphics", "Photography"] },
        { name: "JOGOS",      icon: "", color: "#ef4444", cats: ["Game"] },
        { name: "ESCRITÓRIO", icon: "", color: "#a3e635", cats: ["Office", "TextEditor", "Education", "Science"] },
        { name: "SISTEMA",    icon: "", color: "#94a3b8", cats: ["System", "Settings", "Utility", "FileManager", "Monitor"] }
    ]

    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    function catsOf(e) { return Array.isArray(e.categories) ? e.categories : String(e.categories || "").split(/[;,]/) }
    function inPlaylist(e, p) {
        if (p.cats.length === 0) return data_.pins.includes(e.id) || (data_.counts[e.id] || 0) >= 3
        const c = catsOf(e)
        return p.cats.some(x => c.includes(x))
    }
    readonly property var shown: {
        const q = query.trim().toLowerCase()
        if (q) {
            const score = e => {
                const n = e.name.toLowerCase()
                if (n.startsWith(q)) return 0
                if (n.includes(q)) return 1
                if ((e.genericName || "").toLowerCase().includes(q) || String(e.keywords || "").toLowerCase().includes(q)) return 2
                return 9
            }
            return apps.filter(e => score(e) < 9).sort((a, b) => score(a) - score(b) || (data_.counts[b.id] || 0) - (data_.counts[a.id] || 0))
        }
        const p = playlists[pl]
        const list = apps.filter(e => inPlaylist(e, p))
        if (p.cats.length === 0) list.sort((a, b) => (data_.pins.includes(b.id) - data_.pins.includes(a.id)) || (data_.counts[b.id] || 0) - (data_.counts[a.id] || 0))
        return list
    }

    function toggle() {
        if (open) { open = false; return }
        query = ""; search.text = ""
        stateFile.reload()
        open = true
        grid.currentIndex = 0
        search.forceActiveFocus()
    }
    function save() {
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"", "sh", statePath, JSON.stringify(data_)])
    }
    function launch(e) {
        if (!e) return
        const d = Object.assign({}, data_); d.counts = Object.assign({}, d.counts)
        d.counts[e.id] = (d.counts[e.id] || 0) + 1
        data_ = d; save()
        open = false
        e.execute()
    }
    function togglePin(e) {
        if (!e) return
        const d = Object.assign({}, data_)
        d.pins = d.pins.includes(e.id) ? d.pins.filter(x => x !== e.id) : d.pins.concat([e.id])
        data_ = d; save()
    }
    function rotate(d) {
        query = ""; search.text = ""
        pl = (pl + d + playlists.length) % playlists.length
        grid.currentIndex = 0
    }

    FileView {
        id: stateFile
        path: ln.statePath
        onLoaded: { try { const d = JSON.parse(text()); ln.data_ = { pins: d.pins || [], counts: d.counts || {} } } catch (e) {} }
    }

    visible: open || reveal > 0.01
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-launcher"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.6 * ln.reveal
        MouseArea { anchors.fill: parent; onClicked: ln.open = false }
    }

    Rectangle {
        id: card
        width: Math.min(parent.width * 0.86, 1180)
        height: Math.min(parent.height * 0.78, 660)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - ln.reveal) * 40
        opacity: ln.reveal
        radius: 16
        color: Qt.alpha(ln.bg, 0.96)
        border.width: 1.5
        border.color: Qt.alpha(ln.primary, 0.6)
        MouseArea { anchors.fill: parent }

        // ───────────── disco das playlists ─────────────
        Item {
            id: disc
            readonly property real size: Math.min(card.height - 80, card.width * 0.36)
            width: size; height: size
            x: 30; anchors.verticalCenter: parent.verticalCenter
            readonly property var cur: ln.playlists[ln.pl]
            opacity: ln.query ? 0.35 : 1
            Behavior on opacity { NumberAnimation { duration: 180 } }

            MouseArea { anchors.fill: parent; onWheel: wheel => ln.rotate(wheel.angleDelta.y < 0 ? 1 : -1) }

            Rectangle { anchors.fill: parent; radius: width / 2; color: "#15181b"; border.width: 3; border.color: Qt.alpha(disc.cur.color, 0.6) }
            Shape {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -disc.size * 0.035
                width: disc.size * 0.06; height: width * 0.7
                ShapePath { strokeWidth: 0; fillColor: disc.cur.color; startX: 0; startY: 0; PathLine { x: disc.size * 0.06; y: 0 } PathLine { x: disc.size * 0.03; y: disc.size * 0.042 } PathLine { x: 0; y: 0 } }
            }
            Item {
                id: dial
                anchors.fill: parent
                readonly property real step: 360 / ln.playlists.length
                rotation: -ln.pl * step
                Behavior on rotation { RotationAnimation { direction: RotationAnimation.Shortest; duration: 260; easing.type: Easing.OutBack } }
                Repeater {
                    model: ln.playlists
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property real a: index * dial.step * Math.PI / 180
                        readonly property bool sel: index === ln.pl
                        width: disc.size * 0.17; height: width; radius: width / 2
                        x: disc.size / 2 + Math.sin(a) * disc.size * 0.39 - width / 2
                        y: disc.size / 2 - Math.cos(a) * disc.size * 0.39 - height / 2
                        color: sel ? Qt.alpha(modelData.color, 0.25) : "#0d0f11"
                        border.width: sel ? 3 : 1.5; border.color: modelData.color
                        scale: sel ? 1.12 : 1
                        Behavior on scale { NumberAnimation { duration: 160 } }
                        Text {
                            anchors.centerIn: parent
                            rotation: -dial.rotation
                            text: parent.modelData.icon
                            font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: parent.width * 0.36
                            color: parent.modelData.color
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ln.query = ""; search.text = ""; ln.pl = parent.index; grid.currentIndex = 0 } }
                    }
                }
            }
            Rectangle {   // centro: playlist atual
                anchors.centerIn: parent
                width: disc.size * 0.5; height: width; radius: width / 2
                color: "#07090b"
                border.width: 4; border.color: disc.cur.color
                Column {
                    anchors.centerIn: parent
                    spacing: 4
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: disc.cur.icon; font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: disc.size * 0.11; color: disc.cur.color }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: disc.cur.name; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: disc.size * 0.05; font.letterSpacing: 1; color: disc.cur.color }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: ln.query ? "busca" : ln.shown.length + " apps"; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: disc.size * 0.045; color: Qt.alpha(ln.fg, 0.6) }
                }
            }
        }

        // ───────────── busca + grade ─────────────
        Item {
            id: right
            anchors { left: disc.right; leftMargin: 34; right: parent.right; rightMargin: 26; top: parent.top; topMargin: 24; bottom: parent.bottom; bottomMargin: 18 }

            Rectangle {
                id: searchBox
                width: parent.width; height: 46; radius: 10
                color: Qt.alpha(ln.primary, 0.07)
                border.width: search.activeFocus ? 2 : 1
                border.color: Qt.alpha(ln.primary, search.activeFocus ? 0.9 : 0.35)
                Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: ""; font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 15; color: Qt.alpha(ln.fg, 0.5) }
                TextInput {
                    id: search
                    anchors.fill: parent; anchors.leftMargin: 44; anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 18
                    color: ln.fg
                    selectionColor: ln.primary
                    onTextChanged: { ln.query = text; grid.currentIndex = 0 }
                    Keys.onPressed: event => {
                        const k = event.key, ctrl = event.modifiers & Qt.ControlModifier
                        const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth))
                        if (k === Qt.Key_Escape) ln.open = false
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) ln.launch(ln.shown[grid.currentIndex])
                        else if (ctrl && k === Qt.Key_F) ln.togglePin(ln.shown[grid.currentIndex])
                        else if (k === Qt.Key_Tab) ln.rotate(1)
                        else if (k === Qt.Key_Backtab) ln.rotate(-1)
                        else if ((k === Qt.Key_Left || k === Qt.Key_Right) && search.text === "") ln.rotate(k === Qt.Key_Left ? -1 : 1)
                        else if (k === Qt.Key_Left && search.text !== "") return
                        else if (k === Qt.Key_Right && search.text !== "") return
                        else if (k === Qt.Key_Down) grid.currentIndex = Math.min(ln.shown.length - 1, grid.currentIndex + cols)
                        else if (k === Qt.Key_Up) grid.currentIndex = Math.max(0, grid.currentIndex - cols)
                        else return
                        event.accepted = true
                    }
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: search.text.length === 0; text: "Buscar app… (ou gire o disco)"; font: search.font; color: Qt.alpha(ln.fg, 0.35) }
                }
            }

            GridView {
                id: grid
                anchors { top: searchBox.bottom; topMargin: 16; left: parent.left; right: parent.right; bottom: hint.top; bottomMargin: 8 }
                cellWidth: width / Math.max(1, Math.floor(width / 124)); cellHeight: 118
                clip: true
                model: ln.shown
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 100
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool sel: GridView.isCurrentItem
                    readonly property bool pinned: ln.data_.pins.includes(modelData.id)
                    width: grid.cellWidth; height: grid.cellHeight
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 5
                        radius: 12
                        color: cell.sel ? Qt.alpha(ln.primary, 0.16) : (cm.containsMouse ? Qt.alpha(ln.primary, 0.07) : "transparent")
                        border.width: cell.sel ? 1.5 : 0; border.color: ln.primary
                    }
                    IconImage {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 16
                        implicitSize: 52
                        source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                        asynchronous: true
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 76; width: parent.width - 14
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        elide: Text.ElideRight
                        font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14
                        color: cell.sel ? ln.primary : ln.fg
                    }
                    Text {
                        visible: cell.pinned
                        x: parent.width - 26; y: 10
                        text: ""; font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 11
                        color: "#ffd76a"
                    }
                    MouseArea {
                        id: cm
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: grid.currentIndex = cell.index
                        onClicked: mouse => mouse.button === Qt.RightButton ? ln.togglePin(cell.modelData) : ln.launch(cell.modelData)
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: ln.shown.length === 0
                    text: ln.query ? "Nenhum app encontrado" : (ln.pl === 0 ? "Fixe apps com Ctrl+F ou clique direito" : "Nenhum app nesta playlist")
                    font.family: "Rajdhani"; font.pixelSize: 16; color: Qt.alpha(ln.fg, 0.45)
                }
            }

            Text {
                id: hint
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                text: "←/→ · TAB playlist    ↑/↓ app    ENTER abrir    CTRL+F favoritar    ESC fechar"
                font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14; font.letterSpacing: 1
                color: Qt.alpha(ln.fg, 0.5)
            }
        }
    }
}
