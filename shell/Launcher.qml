// Project Azmuth — lançador de apps (Super + D): o Omnitrix com apps no lugar dos aliens.
// ←/→ (ou scroll) giram entre os apps · ↑/↓ (ou Tab) trocam a playlist · Enter abre ·
// digitar busca em tudo · Ctrl+F põe/tira dos Favoritos · Esc fecha.
// Playlists (nome, runa Galvan, cor, ordem, apps) vêm de Playlists.qml e são
// editadas na Central de Configuração (Super + Shift + O → Apps).

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

PanelWindow {
    id: ln

    required property var theme
    readonly property color fg: theme.foreground

    property bool open: false
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: ln.open ? 300 : 160; easing.type: Easing.OutCubic } }

    property int pl: 0
    property int sel: 0
    property int turn: 0
    property string query: ""

    // playlists do usuário + "SEM PLAYLIST" automática quando houver órfãos
    readonly property var playlists: Playlists.lists.concat(Playlists.orphans.length
        ? [{ id: "__orphans", name: "SEM PLAYLIST", glyph: "portal", color: "#94a3b8", apps: [], virtual: true }] : [])
    readonly property var cur: playlists[Math.min(pl, playlists.length - 1)] || { name: "", glyph: "nucleo", color: theme.primary, apps: [] }

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
            return Playlists.apps.filter(e => score(e) < 9).sort((a, b) => score(a) - score(b))
        }
        return cur.virtual ? Playlists.orphans : Playlists.entriesOf(cur)
    }
    readonly property var curApp: shown.length ? shown[Math.min(sel, shown.length - 1)] : null
    readonly property color accent: query ? theme.primary : cur.color

    function play(n) { Quickshell.execDetached(["pw-play", decodeURIComponent(Qt.resolvedUrl("../assets/sounds/" + n + ".wav").toString().replace("file://", ""))]) }
    function iconOf(e) { return Quickshell.iconPath(e.icon, true) || Quickshell.iconPath("application-x-executable", true) || Quickshell.iconPath("utilities-terminal", true) }

    function toggle() {
        if (open) { open = false; return }
        query = ""; search.text = ""; sel = 0; turn = 0
        for (let i = 0; i < playlists.length; i++) {   // abre na primeira playlist com apps
            pl = i
            if (shown.length) break
        }
        open = true
        search.forceActiveFocus()
        play("hud_open")
    }
    function launch(e) { if (!e) return; open = false; e.execute() }
    function toggleFav(e) { if (e && Playlists.indexOf("fav") >= 0) Playlists.toggleApp("fav", e.id) }
    function step(d) {
        if (!shown.length) return
        sel = (sel + d + shown.length) % shown.length
        turn += d
        play("tick")
    }
    function rotate(d) {
        query = ""; search.text = ""
        pl = (pl + d + playlists.length) % playlists.length
        sel = 0; turn = 0
        play("tick")
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

    // ───────────── playlists (runas acima do disco) ─────────────
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
                width: on ? 46 : 36; height: width; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: on ? Qt.alpha(modelData.color, 0.25) : "#0d0f11"
                border.width: on ? 2.5 : 1.2; border.color: modelData.color
                Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                Glyph {
                    anchors.centerIn: parent
                    width: parent.width * 0.5; height: width
                    name: parent.modelData.glyph
                    color: parent.modelData.color
                    stroke: parent.on ? 2 : 1.6
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
        accent: ln.accent
        items: ln.shown.map(e => ({ image: ln.iconOf(e), color: ln.accent }))
        index: ln.sel
        turn: ln.turn
        maxSlots: 12

        Glyph {   // runa da playlist, esmaecida ao fundo da face
            anchors.centerIn: parent
            width: dial.faceSize * 0.7; height: width
            name: ln.query ? "visao" : ln.cur.glyph
            color: dial.accent
            stroke: 3
            opacity: ln.curApp ? 0.13 : 0.6
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
            spacing: 12
            Text {
                text: ln.curApp ? ln.curApp.name.toUpperCase() : (ln.query ? "NADA ENCONTRADO" : "PLAYLIST VAZIA")
                font.family: "Orbitron"; font.pixelSize: 32; font.weight: Font.Black; font.letterSpacing: 3
                color: dial.accent
                style: Text.Outline; styleColor: Qt.alpha(dial.accent, 0.25)
            }
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: ln.curApp && Playlists.has("fav", ln.curApp.id)
                width: 22; height: 22
                name: "estrela"; color: "#ffd76a"; stroke: 2
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: (ln.query ? "BUSCA" : ln.cur.name) + " · " + (ln.shown.length ? (ln.sel + 1) + " de " + ln.shown.length : "0 apps")
                  + (ln.curApp && (ln.curApp.genericName || ln.curApp.comment) ? " · " + (ln.curApp.genericName || ln.curApp.comment) : "")
            font.family: "Rajdhani"; font.pixelSize: 18; font.weight: Font.DemiBold
            color: "#c9d1d9"
        }
        Rectangle {   // busca: aparece ao digitar
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(260, typed.implicitWidth + 60); height: 40; radius: 20
            color: Qt.alpha(dial.accent, ln.query ? 0.12 : 0.04)
            border.width: 1; border.color: Qt.alpha(dial.accent, ln.query ? 0.8 : 0.25)
            Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 15; height: 15; name: "visao"; color: Qt.alpha(ln.fg, 0.5); stroke: 1.5 }
            Text {
                id: typed
                anchors.centerIn: parent
                text: ln.query || "digite para buscar"
                font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 17
                color: ln.query ? ln.fg : Qt.alpha(ln.fg, 0.35)
            }
            TextInput {
                id: search
                width: 0; height: 0; opacity: 0
                onTextChanged: { ln.query = text; ln.sel = 0; ln.turn = 0 }
                Keys.onPressed: event => {
                    const k = event.key, ctrl = event.modifiers & Qt.ControlModifier
                    if (k === Qt.Key_Escape) { if (search.text) search.text = ""; else ln.open = false }
                    else if (k === Qt.Key_Return || k === Qt.Key_Enter) ln.launch(ln.curApp)
                    else if (ctrl && k === Qt.Key_F) ln.toggleFav(ln.curApp)
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
            text: "←/→ · scroll  app      ↑/↓ · TAB  playlist      ENTER  abrir      CTRL+F  favoritar      ESC  sair      editar: SUPER+SHIFT+O"
            font.family: "Rajdhani"; font.pixelSize: 16; font.letterSpacing: 1
            color: "#9aa4b0"
        }
    }
}
