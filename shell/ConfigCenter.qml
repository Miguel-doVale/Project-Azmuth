// Project Azmuth — Central de Configuração do Omnitrix (Super + Shift + O).
// Abas: Omnitrix (preferências) · Apps (playlists do lançador) · Wi-Fi · Som ·
// Área de trabalho. Preferências gravam via `azmuth set`; playlists via Playlists.qml.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "Galvan.js" as Galvan

PanelWindow {
    id: cc

    required property var theme
    readonly property color primary: theme.primary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"

    property bool open: false
    property int tab: 0
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: cc.open ? 300 : 160; easing.type: Easing.OutCubic } }

    readonly property var tabs: [
        { name: "OMNITRIX", glyph: "tempo" }, { name: "APPS", glyph: "portal" }, { name: "WI-FI", glyph: "rede" },
        { name: "SOM", glyph: "som" }, { name: "ÁREA DE TRABALHO", glyph: "midia" }
    ]

    function toggle(t) {
        if (open && (t === undefined || t === tab)) { open = false; return }
        if (t !== undefined) tab = t
        settingsProc.running = true
        seqFile.reload()
        open = true
        keys.forceActiveFocus()
    }
    function set(path, value) { Quickshell.execDetached([az, "set", path, JSON.stringify(value)]); refresh.restart() }

    property var cfg: null
    Process {
        id: settingsProc
        command: [cc.az, "settings"]
        stdout: StdioCollector { onStreamFinished: { try { cc.cfg = JSON.parse(this.text) } catch (e) {} } }
    }
    Timer { id: refresh; interval: 350; onTriggered: settingsProc.running = true }
    property bool seqSet: false
    FileView {
        id: seqFile
        path: Quickshell.env("HOME") + "/.local/state/azmuth/lockseq.json"
        onLoaded: cc.seqSet = true
        onLoadFailed: cc.seqSet = false
    }

    visible: open || reveal > 0.01
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-config"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ───────────────────────── componentes ─────────────────────────
    component Section: Text {
        font.family: "Orbitron"; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 2
        color: Qt.alpha(cc.fg, 0.55)
        topPadding: 10
    }
    component Toggle: Item {
        id: tg
        property bool checked: false
        property string label: ""
        property string hint: ""
        signal toggled(bool value)
        width: parent ? parent.width : 0
        height: hint ? 48 : 34
        Column {
            anchors.left: parent.left; anchors.right: sw.left; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text { text: tg.label; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; color: cc.fg }
            Text { visible: tg.hint !== ""; width: parent.width; elide: Text.ElideRight; text: tg.hint; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(cc.fg, 0.55) }
        }
        Rectangle {
            id: sw
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 48; height: 26; radius: 13
            color: tg.checked ? cc.primary : Qt.alpha(cc.fg, 0.12)
            Behavior on color { ColorAnimation { duration: 160 } }
            Rectangle {
                width: 20; height: 20; radius: 10; y: 3
                x: tg.checked ? parent.width - width - 3 : 3
                color: tg.checked ? cc.bg : cc.fg
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { tg.checked = !tg.checked; tg.toggled(tg.checked) } }
    }
    component Stepper: Item {
        id: st
        property real value: 0
        property real step: 1
        property real min: 0
        property real max: 60
        property string label: ""
        property string unit: "min"
        signal edited(real value)
        width: parent ? parent.width : 0
        height: 36
        Text { anchors.verticalCenter: parent.verticalCenter; text: st.label; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; color: cc.fg }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Repeater {
                model: [-1, 0, 1]
                Item {
                    required property int modelData
                    width: modelData === 0 ? 76 : 30; height: 30
                    Rectangle {
                        visible: parent.modelData !== 0
                        anchors.fill: parent; radius: 15
                        color: sb.containsMouse ? Qt.alpha(cc.primary, 0.25) : Qt.alpha(cc.primary, 0.08)
                        border.width: 1; border.color: Qt.alpha(cc.primary, 0.4)
                        Text { anchors.centerIn: parent; text: parent.parent.modelData < 0 ? "−" : "+"; font.pixelSize: 17; font.bold: true; color: cc.primary }
                        MouseArea {
                            id: sb
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const v = Math.max(st.min, Math.min(st.max, st.value + parent.parent.modelData * st.step))
                                if (v !== st.value) { st.value = v; st.edited(v) }
                            }
                        }
                    }
                    Text { visible: parent.modelData === 0; anchors.centerIn: parent; text: st.value + " " + st.unit; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 13; color: cc.primary }
                }
            }
        }
    }
    component SmallBtn: Rectangle {
        id: btn
        property string glyph: ""
        property string text: ""
        property color tint: cc.primary
        signal clicked
        height: 30; width: text ? row_.implicitWidth + 22 : 30; radius: 15
        color: bm.containsMouse ? Qt.alpha(tint, 0.22) : "transparent"
        border.width: 1; border.color: Qt.alpha(tint, 0.6)
        Row {
            id: row_
            anchors.centerIn: parent
            spacing: 6
            Glyph { visible: btn.glyph !== ""; anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; name: btn.glyph || "nucleo"; color: btn.tint; stroke: 1.6 }
            Text {
                visible: btn.text !== ""; anchors.verticalCenter: parent.verticalCenter; text: btn.text
                // símbolos de 1 caractere (+ ✓ ✕ ▲ ▼) não existem na Orbitron: fonte maior e comum
                font.family: btn.text.length === 1 ? "JetBrainsMono Nerd Font" : "Orbitron"
                font.pixelSize: btn.text.length === 1 ? 15 : 10; font.weight: Font.Bold; color: btn.tint
            }
        }
        MouseArea { id: bm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.65 * cc.reveal; MouseArea { anchors.fill: parent; onClicked: cc.open = false } }

    Item {
        id: keys
        anchors.fill: parent
        focus: cc.open
        Keys.onEscapePressed: cc.open = false
    }

    // ───────────────────────── janela (cantos chanfrados) ─────────────────────────
    Item {
        id: win
        width: Math.min(parent.width * 0.88, 1240)
        height: Math.min(parent.height * 0.84, 760)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - cc.reveal) * 40
        opacity: cc.reveal
        MouseArea { anchors.fill: parent }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Qt.alpha(cc.bg, 0.97)
                strokeColor: Qt.alpha(cc.primary, 0.6); strokeWidth: 1.5
                readonly property real c: 22
                startX: c; startY: 0
                PathLine { x: win.width - 22; y: 0 }
                PathLine { x: win.width; y: 22 }
                PathLine { x: win.width; y: win.height - 22 }
                PathLine { x: win.width - 22; y: win.height }
                PathLine { x: 22; y: win.height }
                PathLine { x: 0; y: win.height - 22 }
                PathLine { x: 0; y: 22 }
                PathLine { x: 22; y: 0 }
            }
        }

        // ── barra lateral ──
        Column {
            id: side
            x: 26; y: 28
            width: 220
            spacing: 6
            Row {
                spacing: 12
                bottomPadding: 18
                Glyph { width: 30; height: 30; name: "tempo"; color: cc.primary; stroke: 2.2; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "CENTRAL"; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 17; font.letterSpacing: 2; color: cc.primary }
                    Text { text: "do Omnitrix"; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14; color: Qt.alpha(cc.fg, 0.6) }
                }
            }
            Repeater {
                model: cc.tabs
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool on: cc.tab === index
                    width: side.width; height: 44; radius: 10
                    color: on ? Qt.alpha(cc.primary, 0.16) : (tm.containsMouse ? Qt.alpha(cc.primary, 0.06) : "transparent")
                    Rectangle { visible: parent.on; x: 0; y: 10; width: 3; height: 24; radius: 1.5; color: cc.primary }
                    Row {
                        x: 16; anchors.verticalCenter: parent.verticalCenter
                        spacing: 12
                        Glyph { width: 20; height: 20; name: parent.parent.modelData.glyph; color: parent.parent.on ? cc.primary : Qt.alpha(cc.fg, 0.6); stroke: 1.8; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: parent.parent.modelData.name; font.family: "Orbitron"; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.5; color: parent.parent.on ? cc.primary : Qt.alpha(cc.fg, 0.75); anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: cc.tab = parent.index }
                }
            }
        }
        Rectangle { x: side.x + side.width + 22; y: 24; width: 1; height: win.height - 48; color: Qt.alpha(cc.primary, 0.2) }

        Item {
            id: content
            x: side.x + side.width + 46; y: 28
            width: win.width - x - 30; height: win.height - 56

            // ═════════════ OMNITRIX ═════════════
            Flickable {
                anchors.fill: parent
                visible: cc.tab === 0
                contentHeight: omniCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: omniCol
                    width: Math.min(parent.width, 640)
                    spacing: 6
                    readonly property var s: cc.cfg ? cc.cfg.settings : null
                    Section { text: "OMNITRIX" }
                    Toggle { label: "Master Control"; hint: "Troca automática de DNA e energia congelada"; checked: cc.cfg ? cc.cfg.master_control : false; onToggled: v => { Quickshell.execDetached([cc.az, "master", v ? "on" : "off"]); refresh.restart() } }
                    Toggle { label: "Sugestões automáticas"; hint: "Context Engine sugere DNAs pelo app em foco"; checked: omniCol.s ? omniCol.s.context_engine : true; onToggled: v => cc.set("context_engine", v) }
                    Toggle { label: "Área de trabalho viva"; hint: "Omnitrix animado e circuitos com energia"; checked: omniCol.s ? omniCol.s.live_desktop : true; onToggled: v => cc.set("live_desktop", v) }
                    Toggle { label: "Sons"; hint: "Transformação, HUD, bipes"; checked: omniCol.s ? omniCol.s.sounds : true; onToggled: v => cc.set("sounds", v) }
                    Toggle { label: "Notificações de transformação"; checked: omniCol.s ? omniCol.s.notifications : true; onToggled: v => cc.set("notifications", v) }
                    Toggle { label: "Não perturbe"; hint: "Notificações vão direto pro histórico"; checked: omniCol.s ? omniCol.s.dnd : false; onToggled: v => cc.set("dnd", v) }

                    Section { text: "ENERGIA" }
                    Toggle { label: "Energia ligada"; hint: "Descarrega transformado, recarrega no Neutral, 0% destransforma"; checked: omniCol.s ? omniCol.s.timer.enabled : true; onToggled: v => cc.set("timer.enabled", v) }
                    Stepper { label: "Descarga (100% → 0%)"; min: 1; max: 120; value: omniCol.s ? omniCol.s.timer.minutes : 10; onEdited: v => cc.set("timer.minutes", v) }
                    Stepper { label: "Recarga (0% → 100%)"; min: 1; max: 60; value: omniCol.s ? omniCol.s.timer.recharge_minutes : 5; onEdited: v => cc.set("timer.recharge_minutes", v) }
                    Stepper { label: "Mínimo para transformar"; min: 0; max: 90; step: 5; unit: "%"; value: omniCol.s ? omniCol.s.timer.min_percent : 20; onEdited: v => cc.set("timer.min_percent", v) }

                    Section { text: "DNAs" }
                    Repeater {
                        model: cc.cfg ? cc.cfg.dnas.filter(d => d.apps.length > 0) : []
                        Toggle {
                            required property var modelData
                            label: "Abrir apps · " + modelData.name
                            hint: modelData.apps.join(", ")
                            checked: modelData.autostart_apps
                            onToggled: v => cc.set("dna." + modelData.id + ".autostart_apps", v)
                        }
                    }

                    Section { text: "BLOQUEIO" }
                    Item {
                        width: parent.width; height: 70
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 150
                            spacing: 2
                            Text { text: cc.seqSet ? "Sequência do Omnitrix configurada" : "Sem sequência (só senha)"; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; color: cc.fg }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap
                                text: "Grave num terminal seu (fora do Claude): azmuth lockseq set L R R U L R  ·  L = ←  R = →  U = ↑"
                                font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(cc.fg, 0.55)
                            }
                        }
                        SmallBtn { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "PRÉVIA"; glyph: "chave"; onClicked: { cc.open = false; Quickshell.execDetached([cc.az, "lock", "--preview"]) } }
                    }
                }
            }

            // ═════════════ APPS (playlists) ═════════════
            Item {
                id: appsTab
                anchors.fill: parent
                visible: cc.tab === 1
                property string selId: Playlists.lists.length ? Playlists.lists[0].id : ""
                readonly property bool orphMode: selId === "__orphans"
                readonly property var selPl: Playlists.lists.find(p => p.id === selId) || null

                // lista de playlists
                Column {
                    id: plList
                    width: 270
                    spacing: 6
                    Section { text: "PLAYLISTS · ordem do lançador" }
                    Repeater {
                        model: Playlists.lists
                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool on: appsTab.selId === modelData.id
                            width: plList.width; height: 46; radius: 10
                            color: on ? Qt.alpha(modelData.color, 0.16) : (pm.containsMouse ? Qt.alpha(cc.primary, 0.05) : "transparent")
                            border.width: on ? 1.5 : 0; border.color: modelData.color
                            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: appsTab.selId = parent.modelData.id }
                            Row {
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Glyph { width: 22; height: 22; name: parent.parent.modelData.glyph; color: parent.parent.modelData.color; stroke: 1.8; anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: parent.parent.parent.modelData.name; font.family: "Orbitron"; font.pixelSize: 11; font.weight: Font.Bold; color: cc.fg }
                                    Text { text: parent.parent.parent.modelData.apps.length + " apps"; font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(cc.fg, 0.5) }
                                }
                            }
                            Row {
                                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                visible: parent.on
                                SmallBtn { width: 26; height: 26; text: "▲"; onClicked: Playlists.move(parent.parent.modelData.id, -1) }
                                SmallBtn { width: 26; height: 26; text: "▼"; onClicked: Playlists.move(parent.parent.modelData.id, 1) }
                            }
                        }
                    }
                    Rectangle {   // apps sem playlist
                        readonly property bool on: appsTab.orphMode
                        visible: Playlists.orphans.length > 0
                        width: plList.width; height: 46; radius: 10
                        color: on ? Qt.alpha("#ffd76a", 0.14) : "transparent"
                        border.width: 1; border.color: Qt.alpha("#ffd76a", on ? 0.9 : 0.4)
                        Row {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            Glyph { width: 22; height: 22; name: "fantasma"; color: "#ffd76a"; stroke: 1.8; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "SEM PLAYLIST"; font.family: "Orbitron"; font.pixelSize: 11; font.weight: Font.Bold; color: "#ffd76a" }
                                Text { text: Playlists.orphans.length + " apps soltos"; font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(cc.fg, 0.5) }
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: appsTab.selId = "__orphans" }
                    }
                    SmallBtn { text: "NOVA PLAYLIST"; glyph: "estrela"; onClicked: appsTab.selId = Playlists.create("Nova playlist") }
                }

                // detalhes
                Flickable {
                    anchors { left: plList.right; leftMargin: 26; right: parent.right; top: parent.top; bottom: parent.bottom }
                    contentHeight: detail.implicitHeight + 20
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: detail
                        width: parent.width
                        spacing: 10

                        // ── modo "sem playlist": distribuir órfãos ──
                        Column {
                            visible: appsTab.orphMode
                            width: parent.width
                            spacing: 6
                            Section { text: "APPS QUE NÃO ESTÃO EM NENHUMA PLAYLIST · clique numa runa para mandar" }
                            Repeater {
                                model: appsTab.orphMode ? Playlists.orphans : []
                                Item {
                                    required property var modelData
                                    width: detail.width; height: 42
                                    IconImage { x: 4; anchors.verticalCenter: parent.verticalCenter; implicitSize: 28; source: (Quickshell.iconPath(parent.modelData.icon, true) || Quickshell.iconPath("application-x-executable", true) || Quickshell.iconPath("utilities-terminal", true)) }
                                    Text { x: 44; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 44 - targets.width - 10; elide: Text.ElideRight; text: parent.modelData.name; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: cc.fg }
                                    Row {
                                        id: targets
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        Repeater {
                                            model: Playlists.lists
                                            SmallBtn {
                                                required property var modelData
                                                width: 30; height: 30
                                                glyph: modelData.glyph; tint: modelData.color
                                                onClicked: Playlists.addApp(modelData.id, parent.parent.modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ── playlist selecionada ──
                        Column {
                            visible: !appsTab.orphMode && appsTab.selPl !== null
                            width: parent.width
                            spacing: 10
                            readonly property var p: appsTab.selPl

                            Section { text: "NOME" }
                            Item {
                                width: parent.width; height: 44
                                Rectangle {
                                    width: parent.width - 130; height: 44; radius: 8
                                    color: Qt.alpha(cc.primary, 0.06)
                                    border.width: nameIn.activeFocus ? 2 : 1; border.color: Qt.alpha(cc.primary, nameIn.activeFocus ? 0.9 : 0.35)
                                    TextInput {
                                        id: nameIn
                                        anchors.fill: parent; anchors.margins: 12
                                        verticalAlignment: TextInput.AlignVCenter
                                        text: parent.parent.parent.p ? parent.parent.parent.p.name : ""
                                        font.family: "Orbitron"; font.pixelSize: 15; font.weight: Font.Bold; color: cc.fg
                                        selectionColor: cc.primary
                                        maximumLength: 18
                                        onEditingFinished: if (parent.parent.parent.p && text.trim()) Playlists.rename(parent.parent.parent.p.id, text.trim())
                                    }
                                }
                                SmallBtn {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    text: "APAGAR"; glyph: "fogo"; tint: "#ff5a5a"
                                    visible: parent.parent.p && parent.parent.p.id !== "fav"
                                    onClicked: { const id = parent.parent.p.id; appsTab.selId = Playlists.lists.length > 1 ? Playlists.lists[0].id : ""; Playlists.remove(id) }
                                }
                            }

                            Section { text: "RUNA GALVAN" }
                            Flow {
                                width: parent.width
                                spacing: 6
                                Repeater {
                                    model: Galvan.glyphs
                                    Rectangle {
                                        required property var modelData
                                        readonly property bool on: parent.parent.p && parent.parent.p.glyph === modelData.id
                                        width: 46; height: 46; radius: 10
                                        color: on ? Qt.alpha(parent.parent.p.color, 0.22) : (gm.containsMouse ? Qt.alpha(cc.primary, 0.08) : "transparent")
                                        border.width: on ? 2 : 1; border.color: on ? parent.parent.p.color : Qt.alpha(cc.fg, 0.15)
                                        Glyph { anchors.centerIn: parent; width: 26; height: 26; name: parent.modelData.id; color: parent.on ? parent.parent.parent.p.color : Qt.alpha(cc.fg, 0.75); stroke: 1.8 }
                                        MouseArea {
                                            id: gm
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: Playlists.setGlyph(parent.parent.parent.p.id, parent.modelData.id)
                                        }
                                        Text {   // significado no hover
                                            visible: gm.containsMouse
                                            anchors.top: parent.bottom; anchors.topMargin: 4; anchors.horizontalCenter: parent.horizontalCenter
                                            z: 10
                                            text: parent.modelData.meaning
                                            font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 13; color: cc.fg
                                            Rectangle { anchors.fill: parent; anchors.margins: -5; z: -1; radius: 6; color: cc.bg; border.width: 1; border.color: Qt.alpha(cc.primary, 0.5) }
                                        }
                                    }
                                }
                            }

                            Section { text: "COR" }
                            Row {
                                spacing: 8
                                Repeater {
                                    model: ["#4dff8a", "#38bdf8", "#a78bfa", "#f472b6", "#ef4444", "#f59e0b", "#ffd76a", "#a3e635", "#2dd4bf", "#22d3ee", "#94a3b8", "#e2e8f0"]
                                    Rectangle {
                                        required property string modelData
                                        readonly property bool on: parent.parent.p && parent.parent.p.color === modelData
                                        width: 30; height: 30; radius: 15
                                        color: modelData
                                        border.width: on ? 3 : 0; border.color: cc.fg
                                        scale: on ? 1.12 : 1
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Playlists.setColor(parent.parent.parent.p.id, parent.modelData) }
                                    }
                                }
                            }

                            Section { text: "APPS NESTA PLAYLIST · " + (parent.p ? parent.p.apps.length : 0) }
                            Repeater {
                                model: parent.p ? Playlists.entriesOf(parent.p) : []
                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: detail.width; height: 42; radius: 8
                                    color: am.containsMouse ? Qt.alpha(cc.primary, 0.06) : "transparent"
                                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true }
                                    IconImage { x: 8; anchors.verticalCenter: parent.verticalCenter; implicitSize: 28; source: (Quickshell.iconPath(parent.modelData.icon, true) || Quickshell.iconPath("application-x-executable", true) || Quickshell.iconPath("utilities-terminal", true)) }
                                    Text { x: 48; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.name; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: cc.fg }
                                    Row {
                                        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        SmallBtn { width: 28; height: 28; text: "▲"; onClicked: Playlists.moveApp(appsTab.selId, parent.parent.modelData.id, -1) }
                                        SmallBtn { width: 28; height: 28; text: "▼"; onClicked: Playlists.moveApp(appsTab.selId, parent.parent.modelData.id, 1) }
                                        SmallBtn { width: 28; height: 28; text: "✕"; tint: "#ff5a5a"; onClicked: Playlists.removeApp(appsTab.selId, parent.parent.modelData.id) }
                                    }
                                }
                            }

                            Section { text: "ADICIONAR APPS" }
                            Rectangle {
                                width: parent.width; height: 40; radius: 8
                                color: Qt.alpha(cc.primary, 0.06)
                                border.width: addSearch.activeFocus ? 2 : 1; border.color: Qt.alpha(cc.primary, addSearch.activeFocus ? 0.9 : 0.3)
                                Glyph { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 15; height: 15; name: "visao"; color: Qt.alpha(cc.fg, 0.5); stroke: 1.5 }
                                TextInput {
                                    id: addSearch
                                    anchors.fill: parent; anchors.leftMargin: 36; anchors.rightMargin: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 16; color: cc.fg
                                    selectionColor: cc.primary
                                    Text { anchors.verticalCenter: parent.verticalCenter; visible: addSearch.text === ""; text: "Buscar app para adicionar…"; font: addSearch.font; color: Qt.alpha(cc.fg, 0.35) }
                                }
                            }
                            Repeater {
                                model: Playlists.apps.filter(e => !addSearch.text || e.name.toLowerCase().includes(addSearch.text.toLowerCase())).slice(0, 60)
                                Rectangle {
                                    required property var modelData
                                    readonly property bool inside: appsTab.selPl && appsTab.selPl.apps.includes(modelData.id)
                                    readonly property bool orphan: Playlists.orphans.includes(modelData)
                                    width: detail.width; height: 40; radius: 8
                                    color: om.containsMouse ? Qt.alpha(cc.primary, 0.06) : "transparent"
                                    IconImage { x: 8; anchors.verticalCenter: parent.verticalCenter; implicitSize: 26; source: (Quickshell.iconPath(parent.modelData.icon, true) || Quickshell.iconPath("application-x-executable", true) || Quickshell.iconPath("utilities-terminal", true)) }
                                    Text { x: 46; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.name; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15; color: parent.inside ? Qt.alpha(cc.fg, 0.45) : cc.fg }
                                    Text {
                                        visible: parent.orphan
                                        anchors.right: addBtn.left; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                        text: "SEM PLAYLIST"; font.family: "Orbitron"; font.pixelSize: 9; font.weight: Font.Bold; color: "#ffd76a"
                                    }
                                    SmallBtn {
                                        id: addBtn
                                        anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                        width: 28; height: 28
                                        text: parent.inside ? "✓" : "+"
                                        onClicked: Playlists.toggleApp(appsTab.selId, parent.modelData.id)
                                    }
                                    MouseArea { id: om; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                }
                            }
                        }
                    }
                }
            }

            // ═════════════ próximas abas ═════════════
            Column {
                visible: cc.tab >= 2
                anchors.centerIn: parent
                spacing: 12
                Glyph { anchors.horizontalCenter: parent.horizontalCenter; width: 64; height: 64; name: cc.tabs[cc.tab].glyph; color: Qt.alpha(cc.primary, 0.5); stroke: 2.4 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: cc.tabs[cc.tab].name; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 20; color: cc.primary }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Em construção — próxima etapa do Azmuth"; font.family: "Rajdhani"; font.pixelSize: 16; color: Qt.alpha(cc.fg, 0.55) }
            }
        }
    }
}
