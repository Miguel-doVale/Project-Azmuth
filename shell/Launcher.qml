// Project Azmuth — lançador de apps (Super + D): o Omnitrix com apps no lugar dos aliens.
// ←/→ (ou scroll) giram entre os apps da playlist · ↑/↓ (ou Tab) trocam a playlist ·
// Enter abre · digitar busca em tudo · Ctrl+F favorita · Esc fecha.
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
    property int sel: 0                    // app selecionado (índice em `shown`)
    property int turn: 0                   // posição angular do disco (sem limite)
    readonly property var curApp: shown.length ? shown[Math.min(sel, shown.length - 1)] : null
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
        sel = 0; turn = 0
        // abre na primeira playlist com apps (Favoritos começa vazio)
        for (let i = 0; i < playlists.length; i++) {
            pl = i
            if (shown.length) break
        }
        open = true
        search.forceActiveFocus()
        play("hud_open")
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
        sel = 0; turn = 0
        play("tick")
    }

    function play(n) { Quickshell.execDetached(["pw-play", decodeURIComponent(Qt.resolvedUrl("../assets/sounds/" + n + ".wav").toString().replace("file://", ""))]) }
    function step(d) {
        if (!shown.length) return
        sel = (sel + d + shown.length) % shown.length
        turn += d
        play("tick")
    }
    function iconOf(e) { return Quickshell.iconPath(e.icon, "application-x-executable") }

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

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.8 * ln.reveal }
    MouseArea {
        anchors.fill: parent
        onClicked: ln.open = false
        onWheel: wheel => ln.step(wheel.angleDelta.y < 0 ? 1 : -1)
    }

    // ───────────── playlists (acima do disco) ─────────────
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: dial.top; anchors.bottomMargin: ln.height * 0.04
        spacing: 14
        opacity: ln.reveal * (ln.query ? 0.35 : 1)
        Repeater {
            model: ln.playlists
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool on: ln.pl === index
                width: on ? 44 : 36; height: width; radius: width / 2
                color: on ? Qt.alpha(modelData.color, 0.25) : "#0d0f11"
                border.width: on ? 2.5 : 1.2; border.color: modelData.color
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: parent.width * 0.4
                    color: parent.modelData.color
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ln.query = ""; search.text = ""; ln.pl = parent.index; ln.sel = 0; ln.turn = 0 } }
            }
        }
    }

    // ───────────── o disco ─────────────
    OmnitrixDial {
        id: dial
        size: Math.min(ln.width, ln.height) * 0.56
        anchors.centerIn: parent
        anchors.verticalCenterOffset: ln.height * 0.01
        scale: 0.85 + 0.15 * ln.reveal
        opacity: ln.reveal
        rotation: (1 - ln.reveal) * -25
        readonly property var plc: ln.playlists[ln.pl]
        accent: ln.query ? ln.theme.primary : plc.color
        items: ln.shown.map(e => ({ image: ln.iconOf(e), color: dial.accent }))
        index: ln.sel
        turn: ln.turn
        maxSlots: 12

        // holograma: ícone do app grande sobre a ampulheta esmaecida
        Shape {
            id: hg
            anchors.fill: parent
            anchors.margins: parent.width * 0.18
            opacity: 0.14
            ShapePath { strokeWidth: 0; fillColor: dial.accent; startX: 0; startY: 0; PathLine { x: hg.width; y: 0 } PathLine { x: hg.width / 2; y: hg.height / 2 - 1 } PathLine { x: 0; y: 0 } }
            ShapePath { strokeWidth: 0; fillColor: dial.accent; startX: 0; startY: hg.height; PathLine { x: hg.width; y: hg.height } PathLine { x: hg.width / 2; y: hg.height / 2 + 1 } PathLine { x: 0; y: hg.height } }
        }
        IconImage {
            id: big
            anchors.centerIn: parent
            implicitSize: dial.faceSize * 0.5
            source: ln.curApp ? ln.iconOf(ln.curApp) : ""
            asynchronous: true
            onSourceChanged: { scale = 0.8; pop.restart() }
            NumberAnimation { id: pop; target: big; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack }
        }
        Text {
            anchors.centerIn: parent
            visible: !ln.curApp
            text: ln.query ? "\uf002" : dial.plc.icon
            font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: dial.faceSize * 0.3
            color: Qt.alpha(dial.accent, 0.6)
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ln.launch(ln.curApp) }
    }

    // ───────────── placa ─────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dial.bottom; anchors.topMargin: ln.height * 0.035
        spacing: 6
        opacity: ln.reveal
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Text {
                text: ln.curApp ? ln.curApp.name.toUpperCase() : (ln.query ? "NADA ENCONTRADO" : "PLAYLIST VAZIA")
                font.family: "Orbitron"; font.pixelSize: 32; font.weight: Font.Black; font.letterSpacing: 3
                color: dial.accent
                style: Text.Outline; styleColor: Qt.alpha(dial.accent, 0.25)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: ln.curApp && ln.data_.pins.includes(ln.curApp.id)
                text: "\uf005"; font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 18
                color: "#ffd76a"
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (ln.query ? "BUSCA · " : dial.plc.name + " · ") + (ln.shown.length ? (ln.sel + 1) + " de " + ln.shown.length : "0 apps")
                  + (ln.curApp && (ln.curApp.genericName || ln.curApp.comment) ? " · " + (ln.curApp.genericName || ln.curApp.comment) : "")
            font.family: "Rajdhani"; font.pixelSize: 18; font.weight: Font.DemiBold
            color: "#c9d1d9"
        }
        // busca: aparece ao digitar
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(260, typed.implicitWidth + 60); height: 40; radius: 20
            color: Qt.alpha(dial.accent, ln.query ? 0.12 : 0.04)
            border.width: 1; border.color: Qt.alpha(dial.accent, ln.query ? 0.8 : 0.25)
            Text {
                x: 18; anchors.verticalCenter: parent.verticalCenter
                text: "\uf002"; font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 13
                color: Qt.alpha(ln.fg, 0.5)
            }
            Text {
                id: typed
                anchors.centerIn: parent
                text: ln.query || "digite para buscar"
                font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 17
                color: ln.query ? ln.fg : Qt.alpha(ln.fg, 0.35)
            }
            TextInput {
                id: search
                width: 0; height: 0; opacity: 0   // captura o teclado; o texto aparece acima
                onTextChanged: { ln.query = text; ln.sel = 0; ln.turn = 0 }
                Keys.onPressed: event => {
                    const k = event.key, ctrl = event.modifiers & Qt.ControlModifier
                    if (k === Qt.Key_Escape) { if (search.text) search.text = ""; else ln.open = false }
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) ln.launch(ln.curApp)
                    else if (ctrl && k === Qt.Key_F) ln.togglePin(ln.curApp)
                    else if (k === Qt.Key_Right) ln.step(1)
                    else if (k === Qt.Key_Left) ln.step(-1)
                    else if (k === Qt.Key_Down || k === Qt.Key_Tab) ln.rotate(1)
                    else if (k === Qt.Key_Up || k === Qt.Key_Backtab) ln.rotate(-1)
                    else return
                    event.accepted = true
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 8
            text: "←/→ · scroll  app      ↑/↓ · TAB  playlist      ENTER  abrir      CTRL+F  favoritar      ESC  sair"
            font.family: "Rajdhani"; font.pixelSize: 16; font.letterSpacing: 1
            color: "#9aa4b0"
        }
    }
}
