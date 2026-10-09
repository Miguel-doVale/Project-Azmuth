// Project Azmuth — Dashboard (Super + W) e painel de Configuração do Omnitrix (Super + Shift + O).
// Desliza pela direita. A aba Configuração edita ~/.local/state/azmuth/settings.json
// via `azmuth set` — nada de mexer em código.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Mpris

PanelWindow {
    id: dash

    required property var theme
    property var notifications: null      // Notifications.qml (servidor + popups)
    property bool open: false
    property bool allNotifs: false        // histórico: 4 por padrão, "ver mais" mostra tudo
    property int tab: 0                 // só o Painel; configurações ficam na Central (Super+Shift+O)
    signal openCentral
    signal quickEvent(date d)
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: dash.open ? 320 : 200; easing.type: Easing.OutCubic } }

    readonly property color primary: theme.primary
    readonly property color secondary: theme.secondary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"

    function toggle(t) {
        if (open && (t === undefined || t === tab)) { open = false; return }
        if (t !== undefined) tab = t
        settingsProc.running = true
        open = true
    }
    function set(path, value) {
        Quickshell.execDetached([az, "set", path, JSON.stringify(value)])
        refresh.restart()
    }
    function mmss(s) { s = Math.max(0, Math.ceil(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

    visible: open || reveal > 0.01
    anchors { top: true; right: true; bottom: true }
    implicitWidth: 460
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-dashboard"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // clique fora fecha
    HyprlandFocusGrab {
        windows: [dash]
        active: dash.open
        onCleared: dash.open = false
    }

    // ── dados da configuração ──
    property var cfg: null
    Process {
        id: settingsProc
        command: [dash.az, "settings"]
        stdout: StdioCollector { onStreamFinished: { try { dash.cfg = JSON.parse(this.text) } catch (e) {} } }
    }
    Timer { id: refresh; interval: 350; onTriggered: settingsProc.running = true }

    // ── timer do DNA (mesma conta da barra) ──
    // energia do Omnitrix: ver Energy.qml (singleton)

    // ───────────────────────── componentes ─────────────────────────
    component Section: Text {
        font.family: "Orbitron"; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 2
        color: Qt.alpha(dash.fg, 0.55)
        topPadding: 6
    }
    component Card: Rectangle {
        width: parent ? parent.width : 0
        radius: 10
        color: Qt.alpha(dash.primary, 0.05)
        border.width: 1
        border.color: Qt.alpha(dash.primary, 0.25)
    }
    component Toggle: Item {
        id: tg
        property bool checked: false
        property string label: ""
        property string hint: ""
        signal toggled(bool value)
        width: parent ? parent.width : 0
        height: hint ? 46 : 32
        Column {
            anchors.left: parent.left; anchors.right: sw.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text { text: tg.label; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: dash.fg }
            Text { visible: tg.hint !== ""; width: parent.width; elide: Text.ElideRight; text: tg.hint; font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(dash.fg, 0.55) }
        }
        Rectangle {
            id: sw
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 46; height: 24; radius: 12
            color: tg.checked ? dash.primary : Qt.alpha(dash.fg, 0.12)
            Behavior on color { ColorAnimation { duration: 160 } }
            Rectangle {
                width: 18; height: 18; radius: 9
                y: 3; x: tg.checked ? parent.width - width - 3 : 3
                color: tg.checked ? dash.bg : dash.fg
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { tg.checked = !tg.checked; tg.toggled(tg.checked) }
        }
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
        height: 34
        Text { anchors.verticalCenter: parent.verticalCenter; text: st.label; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: dash.fg }
        Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Repeater {
                model: [-1, 0, 1]
                Item {
                    required property int modelData
                    width: modelData === 0 ? 70 : 28; height: 28
                    Rectangle {
                        visible: parent.modelData !== 0
                        anchors.fill: parent; radius: 14
                        color: btn.containsMouse ? Qt.alpha(dash.primary, 0.25) : Qt.alpha(dash.primary, 0.08)
                        border.width: 1; border.color: Qt.alpha(dash.primary, 0.4)
                        Text { anchors.centerIn: parent; text: parent.parent.modelData < 0 ? "−" : "+"; font.pixelSize: 16; font.bold: true; color: dash.primary }
                        MouseArea {
                            id: btn
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const v = Math.max(st.min, Math.min(st.max, st.value + parent.parent.modelData * st.step))
                                if (v !== st.value) { st.value = v; st.edited(v) }
                            }
                        }
                    }
                    Text {
                        visible: parent.modelData === 0
                        anchors.centerIn: parent
                        text: st.value + " " + st.unit
                        font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 13; color: dash.primary
                    }
                }
            }
        }
    }
    component Pill: Rectangle {
        id: pill
        property string text: ""
        signal clicked
        height: 28; width: pt.implicitWidth + 24; radius: 14
        color: pm.containsMouse ? dash.primary : "transparent"
        border.width: 1; border.color: dash.primary
        Text { id: pt; anchors.centerIn: parent; text: pill.text; font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold; color: pm.containsMouse ? dash.bg : dash.primary }
        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.clicked() }
    }

    // ───────────────────────── painel ─────────────────────────
    Rectangle {
        id: panel
        width: parent.width - 16
        height: parent.height - 56
        y: 46
        x: 8 + (1 - dash.reveal) * (parent.width + 20)
        opacity: dash.reveal
        radius: 14
        color: Qt.alpha(dash.bg, 0.97)
        border.width: 1.5
        border.color: Qt.alpha(dash.primary, 0.6)

        Keys.onEscapePressed: dash.open = false
        focus: dash.open

        // abas
        Row {
            id: tabs
            x: 20; y: 16
            spacing: 18
            Repeater {
                model: ["PAINEL", "CENTRAL ↗"]
                Text {
                    required property int index
                    required property string modelData
                    text: modelData
                    font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 13; font.letterSpacing: 2
                    color: dash.tab === index ? dash.primary : Qt.alpha(dash.fg, 0.4)
                    Rectangle {
                        anchors.top: parent.bottom; anchors.topMargin: 5
                        width: parent.width; height: 2; radius: 1
                        color: dash.primary
                        visible: dash.tab === parent.index
                    }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { if (parent.index === 1) { dash.open = false; dash.openCentral() } else dash.tab = 0 } }
                }
            }
        }

        Flickable {
            anchors { top: tabs.bottom; topMargin: 20; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20 }
            contentHeight: painelCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // ═════════════════════ aba PAINEL ═════════════════════
            Column {
                id: painelCol
                visible: dash.tab === 0
                width: parent.width
                spacing: 14

                // relógio
                Item {
                    width: parent.width; height: 74
                    property date clock: new Date()
                    Timer { interval: 1000; running: dash.visible; repeat: true; triggeredOnStart: true; onTriggered: parent.clock = new Date() }
                    Text { id: bigClock; text: Qt.formatTime(parent.clock, "HH:mm"); font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 52; color: dash.primary }
                    Text {
                        anchors.left: bigClock.right; anchors.leftMargin: 14; anchors.bottom: bigClock.bottom; anchors.bottomMargin: 10
                        text: Qt.locale("pt_BR").toString(parent.clock, "dddd\nd 'de' MMMM")
                        font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; lineHeight: 0.9
                        color: dash.fg
                    }
                }

                // DNA ativo
                Card {
                    height: 196
                    Rectangle {
                        id: dnaBadge
                        x: 16; anchors.verticalCenter: parent.verticalCenter
                        width: 104; height: 104; radius: 52
                        color: "#0c0f11"
                        border.width: 3; border.color: dash.primary
                        Image {
                            anchors.centerIn: parent
                            width: 92; height: 92
                            visible: dash.theme.art !== undefined && dash.theme.art !== ""
                            source: visible ? "file://" + dash.theme.art : ""
                            sourceSize: Qt.size(184, 184)
                        }
                        Shape {
                            id: hg
                            visible: !dash.theme.art
                            anchors.fill: parent; anchors.margins: 28
                            ShapePath { strokeWidth: 0; fillColor: dash.primary; startX: 0; startY: 0; PathLine { x: hg.width; y: 0 } PathLine { x: hg.width / 2; y: hg.height / 2 - 1 } PathLine { x: 0; y: 0 } }
                            ShapePath { strokeWidth: 0; fillColor: dash.primary; startX: 0; startY: hg.height; PathLine { x: hg.width; y: hg.height } PathLine { x: hg.width / 2; y: hg.height / 2 + 1 } PathLine { x: 0; y: hg.height } }
                        }
                    }
                    Column {
                        anchors.left: dnaBadge.right; anchors.leftMargin: 16
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text { text: "DNA ATIVO"; font.family: "Orbitron"; font.pixelSize: 10; font.letterSpacing: 2; color: Qt.alpha(dash.fg, 0.55) }
                        Text { text: (dash.theme.name || "").toUpperCase(); font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 19; color: dash.primary }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                            text: dash.theme.description || ""
                            font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14; color: dash.fg
                        }
                        // energia do Omnitrix
                        Item {
                            width: parent.width; height: 26
                            visible: Energy.enabled
                            Rectangle {
                                y: 2; width: parent.width; height: 6; radius: 3
                                color: Qt.alpha(Energy.locked ? "#ff5a5a" : dash.primary, 0.15)
                                Rectangle {
                                    height: parent.height; radius: 3
                                    width: parent.width * Energy.level
                                    color: Energy.locked ? "#ff5a5a" : dash.primary
                                }
                                Rectangle {   // marca do mínimo para transformar
                                    x: parent.width * Energy.min - 1; y: -3; width: 2; height: 12
                                    color: Qt.alpha(dash.fg, 0.5)
                                }
                            }
                            Text {
                                y: 12
                                text: "ENERGIA " + Energy.percent + "%" + (
                                      dash.theme.master ? " · MASTER CONTROL (congelada)"
                                    : Energy.draining ? " · resta " + Energy.mmss(Energy.secondsLeft)
                                    : Energy.locked ? " · transforma em " + Energy.mmss(Energy.secondsToMin)
                                    : Energy.charging ? " · cheia em " + Energy.mmss(Energy.secondsToFull)
                                    : " · carregada")
                                font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1
                                color: Energy.locked ? "#ff5a5a" : dash.primary
                            }
                        }
                        Row {
                            topPadding: 4; spacing: 8
                            Pill { text: "HUD"; onClicked: { dash.open = false; Quickshell.execDetached([dash.az, "hud", "toggle"]) } }
                            Pill { text: "RANDOM"; onClicked: Quickshell.execDetached([dash.az, "random"]) }
                            Pill { text: "NEUTRAL"; onClicked: Quickshell.execDetached([dash.az, "neutral"]) }
                        }
                    }
                }

                // música
                Card {
                    id: music
                    readonly property var p: { const ps = Mpris.players.values; return ps.find(x => x.isPlaying) || ps[0] || null }
                    visible: p !== null
                    height: 128
                    Timer { interval: 1000; repeat: true; running: dash.visible && music.p !== null && music.p.isPlaying; onTriggered: music.p.positionChanged() }
                    ClippingRectangle {
                        id: cover
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 100; height: 100; radius: 8
                        color: Qt.alpha(dash.primary, 0.12)
                        Image { anchors.fill: parent; source: music.p ? music.p.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                    }
                    Column {
                        anchors.left: cover.right; anchors.leftMargin: 14
                        anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text { width: parent.width; elide: Text.ElideRight; text: music.p ? (music.p.trackTitle || music.p.identity) : ""; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; color: dash.fg }
                        Text { width: parent.width; elide: Text.ElideRight; text: music.p ? (music.p.trackArtist || music.p.identity) : ""; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(dash.fg, 0.6) }
                        // visualizador (animado enquanto toca)
                        Row {
                            spacing: 3; height: 18
                            Repeater {
                                model: 18
                                Rectangle {
                                    required property int index
                                    anchors.bottom: parent.bottom
                                    width: 4; radius: 2
                                    color: dash.primary
                                    property real level: 0.2
                                    height: 3 + level * 15
                                    Behavior on height { NumberAnimation { duration: 140 } }
                                    Timer {
                                        interval: 140 + (parent.index % 5) * 20; repeat: true
                                        running: dash.visible && music.p !== null && music.p.isPlaying
                                        onTriggered: parent.level = Math.random()
                                        onRunningChanged: if (!running) parent.level = 0.15
                                    }
                                }
                            }
                        }
                        Rectangle {
                            width: parent.width; height: 4; radius: 2
                            color: Qt.alpha(dash.primary, 0.18)
                            visible: music.p && music.p.lengthSupported && music.p.length > 0
                            Rectangle { height: parent.height; radius: 2; color: dash.primary; width: music.p && music.p.length > 0 ? parent.width * Math.min(1, music.p.position / music.p.length) : 0 }
                        }
                        Row {
                            spacing: 24; topPadding: 2
                            Repeater {
                                model: [
                                    { i: "", f: () => music.p.previous() },
                                    { i: music.p && music.p.isPlaying ? "" : "", f: () => music.p.togglePlaying() },
                                    { i: "", f: () => music.p.next() }
                                ]
                                Text {
                                    required property var modelData
                                    text: modelData.i
                                    font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 16
                                    color: mb.containsMouse ? dash.primary : dash.fg
                                    MouseArea { id: mb; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (music.p) parent.modelData.f() }
                                }
                            }
                        }
                    }
                }

                // calendário
                Card {
                    id: cal
                    property date month: new Date()
                    readonly property var today: new Date()
                    height: calCol.implicitHeight + 24
                    Column {
                        id: calCol
                        x: 14; y: 12
                        width: parent.width - 28
                        spacing: 6
                        Item {
                            width: parent.width; height: 22
                            Text { text: Qt.locale("pt_BR").toString(cal.month, "MMMM yyyy").toUpperCase(); font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 12; color: dash.primary; anchors.verticalCenter: parent.verticalCenter }
                            Row {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 16
                                Repeater {
                                    model: [-1, 1]
                                    Text {
                                        required property int modelData
                                        text: modelData < 0 ? "" : ""
                                        font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 12; color: dash.fg
                                        MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: cal.month = new Date(cal.month.getFullYear(), cal.month.getMonth() + parent.modelData, 1) }
                                    }
                                }
                            }
                        }
                        Grid {
                            columns: 7
                            width: parent.width
                            readonly property real cell: width / 7
                            Repeater {
                                model: ["D", "S", "T", "Q", "Q", "S", "S"]
                                Text { required property string modelData; width: parent.cell; horizontalAlignment: Text.AlignHCenter; text: modelData; font.family: "Orbitron"; font.pixelSize: 10; color: Qt.alpha(dash.fg, 0.45) }
                            }
                            Repeater {
                                model: 42
                                Item {
                                    required property int index
                                    readonly property int first: new Date(cal.month.getFullYear(), cal.month.getMonth(), 1).getDay()
                                    readonly property int days: new Date(cal.month.getFullYear(), cal.month.getMonth() + 1, 0).getDate()
                                    readonly property int day: index - first + 1
                                    readonly property bool isToday: day === cal.today.getDate() && cal.month.getMonth() === cal.today.getMonth() && cal.month.getFullYear() === cal.today.getFullYear()
                                    width: parent.cell; height: 26
                                    visible: index < Math.ceil((first + days) / 7) * 7
                                    Rectangle { anchors.centerIn: parent; width: 24; height: 24; radius: 12; color: dash.primary; visible: parent.isToday }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: parent.day >= 1 && parent.day <= parent.days
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { dash.open = false; dash.quickEvent(new Date(cal.month.getFullYear(), cal.month.getMonth(), parent.day)) }
                                    }
                                    Rectangle {   // tem evento
                                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                                        width: 4; height: 4; radius: 2
                                        visible: parent.day >= 1 && parent.day <= parent.days && Events.hasDay(new Date(cal.month.getFullYear(), cal.month.getMonth(), parent.day))
                                        color: parent.isToday ? dash.fg : dash.primary
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.day >= 1 && parent.day <= parent.days ? parent.day : ""
                                        font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 14
                                        color: parent.isToday ? dash.bg : dash.fg
                                    }
                                }
                            }
                        }
                    }
                }

                // notificações (histórico)
                Item {
                    width: parent.width; height: 22
                    readonly property int count: dash.notifications ? dash.notifications.server.trackedNotifications.values.length : 0
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "NOTIFICAÇÕES · " + parent.count; font.family: "Orbitron"; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 2; color: Qt.alpha(dash.fg, 0.55) }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        visible: parent.count > 0
                        text: "LIMPAR"
                        font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold
                        color: clr.containsMouse ? "#ff5a5a" : dash.primary
                        MouseArea { id: clr; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dash.notifications.clearAll() }
                    }
                }
                Text {
                    visible: !dash.notifications || dash.notifications.server.trackedNotifications.values.length === 0
                    text: "Nada por aqui."
                    font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(dash.fg, 0.4)
                }
                Repeater {
                    model: dash.notifications ? dash.notifications.server.trackedNotifications.values.slice().reverse().slice(0, dash.allNotifs ? 50 : 4) : []
                    Card {
                        id: hn
                        required property var modelData
                        height: hcol.implicitHeight + 18
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) { dash.open = false; dash.notifications.activate(hn.modelData) }
                                else hn.modelData.dismiss()
                            }
                        }
                        Column {
                            id: hcol
                            x: 14; y: 9; width: parent.width - 48
                            spacing: 2
                            Text { text: (hn.modelData.appName || "Sistema").toUpperCase(); font.family: "Orbitron"; font.pixelSize: 9; font.weight: Font.Bold; color: dash.primary }
                            Text { width: parent.width; elide: Text.ElideRight; text: hn.modelData.summary; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 15; color: dash.fg }
                            Text { width: parent.width; visible: text !== ""; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; textFormat: Text.StyledText; text: hn.modelData.body; font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(dash.fg, 0.65) }
                        }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: 14; y: 10
                            text: "\uf00d"
                            font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 12
                            color: hx.containsMouse ? "#ff5a5a" : Qt.alpha(dash.fg, 0.45)
                            MouseArea { id: hx; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: hn.modelData.dismiss() }
                        }
                    }
                }

                Text {
                    readonly property int count: dash.notifications ? dash.notifications.server.trackedNotifications.values.length : 0
                    visible: count > 4
                    text: dash.allNotifs ? "VER MENOS" : "VER MAIS (" + (count - 4) + ")"
                    font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1
                    color: vm.containsMouse ? dash.fg : dash.primary
                    MouseArea { id: vm; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dash.allNotifs = !dash.allNotifs }
                }

                // sistema
                Card {
                    height: 92
                    Row {
                        anchors.centerIn: parent
                        spacing: 22
                        Repeater {
                            model: [
                                { k: "CPU", v: SysStats.cpu, t: Math.round(SysStats.cpu) + "%" },
                                { k: "RAM", v: SysStats.ram, t: SysStats.ramUsedGiB.toFixed(1) + " GiB" },
                                { k: "TEMP", v: SysStats.temp, t: Math.round(SysStats.temp) + "°C" }
                            ]
                            Column {
                                required property var modelData
                                spacing: 6
                                Text { text: modelData.k; font.family: "Orbitron"; font.pixelSize: 10; font.letterSpacing: 2; color: Qt.alpha(dash.fg, 0.55) }
                                Rectangle {
                                    width: 110; height: 6; radius: 3; color: Qt.alpha(dash.primary, 0.15)
                                    Rectangle { height: parent.height; radius: 3; width: parent.width * Math.min(1, modelData.v / 100); color: modelData.v >= 85 ? "#ff5a5a" : dash.primary; Behavior on width { NumberAnimation { duration: 600 } } }
                                }
                                Text { text: modelData.t; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 13; color: dash.fg }
                            }
                        }
                    }
                }
            }
        }
    }
}
