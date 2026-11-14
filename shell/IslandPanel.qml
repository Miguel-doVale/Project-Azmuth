// Project Azmuth — painel da ilha (fase 3), 728×458, uma página só:
// cabeçalho (alien/DNA · hora) · botões rápidos · som e brilho · música | calendário | notificações · rodapé.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: panel
    required property var theme
    property var notifications: null
    property bool active: false
    signal openCentral(int tab)
    signal closeRequested()
    signal quickEvent(var day)
    property alias tray: trayStrip

    readonly property color primary: Colors.mode ? Colors.modeColor : theme.primary
    readonly property color fg: theme.foreground || "#cdd6f4"
    readonly property color card: "#131c2e"
    readonly property color line: Qt.alpha(primary, 0.18)
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"
    function run(cmd) { Quickshell.execDetached(cmd) }

    anchors.fill: parent

    Column {
        id: col
        anchors.fill: parent
        anchors.leftMargin: 20; anchors.rightMargin: 20; anchors.topMargin: 18; anchors.bottomMargin: 16
        spacing: 10

        // ───────── cabeçalho ─────────
        Item {
            width: col.width; height: 60   // folga entre a linha de sistema e os botões
            Row {
                spacing: 10
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {   // retrato do DNA ativo (arte do alien; sem arte → Omnitrix)
                    width: 48; height: 48; radius: 14; clip: true
                    color: Qt.alpha(panel.primary, 0.12)
                    border.width: 1; border.color: Qt.alpha(panel.primary, 0.4)
                    Image {
                        id: art
                        anchors.fill: parent; anchors.margins: 2
                        source: panel.theme.art ? "file://" + panel.theme.art : ""
                        fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
                        visible: status === Image.Ready
                    }
                    OmnitrixMark { anchors.centerIn: parent; size: 30; glow: false; status: false; visible: !art.visible; color: panel.primary }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { panel.run([panel.az, "hud", "toggle"]); panel.closeRequested() } }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: (panel.theme.name || "").toUpperCase(); font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 14; font.letterSpacing: 2; color: panel.primary }
                    Text {
                        text: !Energy.enabled ? "energia livre" : Energy.draining ? "troca em " + Math.max(1, Math.ceil(Energy.secondsLeft / 60)) + " min"
                              : Energy.locked ? "recarregando · " + Energy.mmss(Energy.secondsToMin) : "energia " + Energy.percent + "%"
                        font.family: "Rajdhani"; font.weight: Font.Medium; font.pixelSize: 13; color: Qt.alpha(panel.fg, 0.6)
                    }
                    Rectangle {
                        width: 150; height: 3; radius: 2; color: Qt.alpha(panel.primary, 0.15)
                        Rectangle { width: parent.width * Energy.level; height: parent.height; radius: 2; color: panel.primary }
                    }
                }
            }
            Column {
                anchors.right: parent.right; anchors.top: parent.top
                spacing: 1
                Text { anchors.right: parent.right; text: Qt.formatTime(clock.date, "hh:mm"); font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 22; color: panel.fg }
                Text { anchors.right: parent.right; text: Qt.locale("pt_BR").toString(clock.date, "dddd, d 'de' MMMM"); font.family: "Rajdhani"; font.weight: Font.Medium; font.pixelSize: 12; color: Qt.alpha(panel.fg, 0.55) }
                Text {
                    anchors.right: parent.right
                    readonly property var dev: UPower.displayDevice
                    readonly property int pct: dev ? Math.round(dev.percentage * (dev.percentage <= 1 ? 100 : 1)) : 0
                    text: (dev && dev.isPresent ? pct + "% · " : "") + "CPU " + Math.round(SysStats.cpu) + "% · RAM " + Math.round(SysStats.ram) + "% · " + Math.round(SysStats.temp) + "°"
                    font.family: "Rajdhani"; font.pixelSize: 11; color: Qt.alpha(panel.fg, 0.5)
                }
            }
        }

        // ───────── botões rápidos ─────────
        Row {
            id: tiles
            spacing: 8
            readonly property real tw: (col.width - spacing * 3) / 4
            readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
            readonly property var wifiNet: wifiDev && wifiDev.networks ? (wifiDev.networks.values.find(n => n.connected) || null) : null
            readonly property var bt: Bluetooth.defaultAdapter
            readonly property var btConn: Bluetooth.devices.values.filter(d => d.connected)

            Tile { glyph: "◠"; title: "Wi-Fi"; on: Networking.wifiEnabled
                   sub: !Networking.wifiEnabled ? "Desligado" : tiles.wifiNet ? tiles.wifiNet.name : (tiles.wifiDev ? "Desconectado" : "Sem adaptador")
                   onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                   onLongPressed: panel.openCentral(2) }
            Tile { glyph: "✱"; title: "Bluetooth"; on: tiles.bt !== null && tiles.bt.enabled
                   sub: !tiles.bt ? "Sem adaptador" : !tiles.bt.enabled ? "Desligado" : tiles.btConn.length ? (tiles.btConn[0].name || tiles.btConn[0].deviceName) : "Ligado"
                   onToggled: if (tiles.bt) tiles.bt.enabled = !tiles.bt.enabled
                   onLongPressed: panel.openCentral(3) }
            Tile { glyph: "☾"; title: "Não perturbe"; on: panel.theme.dnd === true
                   sub: on ? "Ligado" : "Desligado"
                   onToggled: panel.run([panel.az, "set", "dnd", on ? "false" : "true"]) }
            Tile { glyph: "◈"; title: "Life-Form"; on: Colors.lifeform
                   sub: on ? "DNA travado" : "DNA livre"
                   onToggled: panel.run([panel.az, "lifeform", "toggle"]) }
        }

        // ───────── som e brilho ─────────
        Row {
            id: controls
            spacing: 8
            readonly property real cw: (col.width - spacing) / 2
            readonly property var rawSink: Pipewire.defaultAudioSink
            // com o equalizador no meio, o volume que se ouve é o do aparelho real atrás dele
            readonly property var sink: panel.viaEq && panel.eqOut ? panel.eqOut : rawSink
            PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource, panel.eqOut].filter(o => o) }

            Slide {
                id: vol
                glyph: "♪"
                value: controls.sink && controls.sink.audio ? controls.sink.audio.volume : 0
                muted: controls.sink && controls.sink.audio ? controls.sink.audio.muted : false
                onMoved: v => { if (controls.sink && controls.sink.audio) controls.sink.audio.volume = v }
                onGlyphClicked: if (controls.sink && controls.sink.audio) controls.sink.audio.muted = !controls.sink.audio.muted
                Rectangle {   // saída atual → cascata
                    id: outBtn
                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(130, outText.implicitWidth + 16); height: 22; radius: 9
                    color: Qt.alpha(panel.primary, 0.1); border.width: 1; border.color: Qt.alpha(panel.primary, picker.open ? 0.9 : 0.25)
                    Text { id: outText; anchors.centerIn: parent; width: parent.width - 12; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                           text: panel.outLabel + " ▾"; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 12; color: panel.fg }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: picker.open = !picker.open }
                }
                rightReserve: outBtn.width + 14
            }
            Slide {
                id: bright
                glyph: "◐"
                value: brightness.level
                onMoved: v => brightness.set(v)
            }
        }

        // ───────── música | calendário | notificações ─────────
        Row {
            id: mid
            width: col.width; height: 196
            spacing: 10
            MusicCard { width: 196; height: 196; primary: panel.primary; fg: panel.fg; active: panel.active; onOpened: panel.closeRequested() }

            Rectangle {   // calendário compacto
                id: cal
                width: 240; height: 196; radius: 16
                color: panel.card; border.width: 1; border.color: panel.line
                readonly property date today: clock.date
                readonly property date month: new Date(today.getFullYear(), today.getMonth(), 1)
                Text { x: 12; y: 10; text: Qt.locale("pt_BR").toString(cal.month, "MMMM yyyy").toUpperCase()
                       font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 10; font.letterSpacing: 1.5; color: panel.primary }
                Grid {
                    x: 8; y: 30; width: cal.width - 16
                    columns: 7
                    readonly property real cell: width / 7
                    Repeater {
                        model: ["D", "S", "T", "Q", "Q", "S", "S"]
                        Text { required property string modelData; width: parent.cell; horizontalAlignment: Text.AlignHCenter; text: modelData
                               font.family: "Rajdhani"; font.pixelSize: 10; color: Qt.alpha(panel.fg, 0.45); bottomPadding: 2 }
                    }
                    Repeater {
                        model: 42
                        Item {
                            required property int index
                            readonly property int first: cal.month.getDay()
                            readonly property int days: new Date(cal.month.getFullYear(), cal.month.getMonth() + 1, 0).getDate()
                            readonly property int day: index - first + 1
                            readonly property bool valid: day >= 1 && day <= days
                            readonly property bool isToday: valid && day === cal.today.getDate()
                            readonly property var dots: valid ? Events.colorsOn(new Date(cal.month.getFullYear(), cal.month.getMonth(), day)) : []
                            width: parent.cell; height: 23
                            visible: index < Math.ceil((first + days) / 7) * 7
                            Rectangle { anchors.centerIn: parent; width: 26; height: 19; radius: 8; color: panel.primary; visible: parent.isToday }
                            Text { anchors.centerIn: parent; text: parent.valid ? parent.day : ""; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 12
                                   color: parent.isToday ? Colors.bg : panel.fg }
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; width: 4; height: 4; radius: 2
                                        visible: parent.dots.length > 0 && !parent.isToday; color: parent.dots[0] || panel.primary }
                            MouseArea { anchors.fill: parent; enabled: parent.valid; cursorShape: Qt.PointingHandCursor
                                        onClicked: { panel.closeRequested(); panel.quickEvent(new Date(cal.month.getFullYear(), cal.month.getMonth(), parent.day)) } }
                        }
                    }
                }
            }

            Rectangle {   // notificações
                id: notifCard
                width: mid.width - 196 - 240 - 20; height: 196; radius: 16
                color: panel.card; border.width: 1; border.color: panel.line
                readonly property var list: panel.notifications ? panel.notifications.server.trackedNotifications.values.slice().reverse() : []
                Text { x: 12; y: 10; text: "NOTIFICAÇÕES"; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 10; font.letterSpacing: 1.5; color: panel.primary }
                Text { anchors.right: parent.right; anchors.rightMargin: 12; y: 8; visible: notifCard.list.length > 0; text: "limpar"
                       font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 12; color: Qt.alpha(panel.fg, 0.7)
                       MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: panel.notifications.clearAll() } }
                Text { anchors.centerIn: parent; visible: notifCard.list.length === 0; text: "Nada por aqui."
                       font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(panel.fg, 0.4) }
                ListView {
                    x: 6; y: 30; width: parent.width - 12; height: parent.height - 36
                    clip: true; spacing: 3
                    model: notifCard.list
                    delegate: Rectangle {
                        id: nrow
                        required property var modelData
                        width: ListView.view.width; height: 38; radius: 9
                        color: nma.containsMouse ? Qt.alpha(panel.primary, 0.07) : "transparent"
                        Rectangle {
                            x: 6; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; radius: 7; clip: true
                            color: Qt.alpha(panel.primary, 0.18)
                            Image { anchors.fill: parent; source: panel.notifications ? panel.notifications.iconFor(nrow.modelData) : ""; fillMode: Image.PreserveAspectFit; asynchronous: true }
                        }
                        Column {
                            x: 36; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 58
                            Text { width: parent.width; elide: Text.ElideRight; text: (nrow.modelData.appName || "Sistema") + " · " + (nrow.modelData.summary || "")
                                   font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 13; color: panel.fg }
                            Text { width: parent.width; elide: Text.ElideRight; text: (nrow.modelData.body || "").replace(/<[^>]*>/g, "").replace(/\n/g, " ")
                                   font.family: "Rajdhani"; font.pixelSize: 11; color: Qt.alpha(panel.fg, 0.6) }
                        }
                        MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; onClicked: panel.notifications.activate(nrow.modelData) }
                        Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; visible: nma.containsMouse || xma.containsMouse
                               text: "✕"; font.pixelSize: 11; font.bold: xma.containsMouse
                               color: xma.containsMouse ? "#ff5a5a" : Qt.alpha(panel.fg, 0.7)   // vermelho com o mouse em cima
                               Rectangle { anchors.centerIn: parent; width: 20; height: 20; radius: 10; z: -1
                                           color: Qt.alpha("#ff5a5a", 0.16); visible: xma.containsMouse }
                               MouseArea { id: xma; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: nrow.modelData.dismiss() } }
                    }
                }
            }
        }

        // ───────── rodapé ─────────
        Item {
            id: foot
            width: col.width; height: 40
            Row {
                spacing: 8
                Rectangle {   // CENTRAL
                    width: centralRow.width + 22; height: 40; radius: 13
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha(panel.primary, cma.containsMouse ? 0.32 : 0.22) }
                        GradientStop { position: 1; color: panel.card }
                    }
                    border.width: 1; border.color: Qt.alpha(panel.primary, 0.55)
                    Row {
                        id: centralRow
                        anchors.centerIn: parent; spacing: 8
                        OmnitrixMark { anchors.verticalCenter: parent.verticalCenter; size: 24; glow: false; status: false; color: panel.primary }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "CENTRAL"; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 12; font.letterSpacing: 1.5; color: panel.fg }
                    }
                    MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.openCentral(0) }
                }
                TrayStrip { id: trayStrip; primary: panel.primary; fg: panel.fg }
            }
            Row {
                anchors.right: parent.right
                spacing: 6
                Repeater {
                    model: [{ g: "⌖", t: "Captura", c: ["shot", "menu"] }, { g: "▦", t: "Atalhos", c: ["atalhos", "menu"] },
                            { g: "◈", t: "Bloquear", c: ["lock"] }, { g: "⏻", t: "Energia", c: ["power"] }]
                    Rectangle {
                        id: act
                        required property var modelData
                        width: 40; height: 40; radius: 13
                        color: panel.card; border.width: 1; border.color: ama.containsMouse ? panel.primary : panel.line
                        Text { anchors.centerIn: parent; text: act.modelData.g; font.pixelSize: 15; color: panel.primary }
                        MouseArea { id: ama; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onContainsMouseChanged: containsMouse ? tipDelay.restart() : (tipDelay.stop(), tip.shown = false)
                                    onClicked: { panel.closeRequested(); panel.run([panel.az].concat(act.modelData.c)) } }
                        Timer { id: tipDelay; interval: 550; onTriggered: tip.shown = true }
                        Rectangle {   // nome do botão com o mouse parado em cima (acima: embaixo o painel corta)
                            id: tip
                            property bool shown: false
                            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.top; anchors.bottomMargin: 6
                            width: tipText.implicitWidth + 16; height: 22; radius: 8; z: 10
                            color: "#0e1626"; border.width: 1; border.color: Qt.alpha(panel.primary, 0.5)
                            opacity: shown ? 1 : 0; visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Text { id: tipText; anchors.centerIn: parent; text: act.modelData.t; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 12; color: panel.fg }
                        }
                    }
                }
            }
        }
    }

    AudioPicker {
        id: picker
        x: controls.x + col.x + 70; z: 5

        y: col.y + controls.y + controls.height + 6 + (open ? 0 : -6)
        primary: panel.primary; fg: panel.fg
        onChosen: closeTimer.restart()
    }
    Timer { id: closeTimer; interval: 180; onTriggered: picker.open = false }
    onActiveChanged: { if (!active) { picker.open = false; trayStrip.close() } else brightness.read() }

    // brilho via brightnessctl
    QtObject {
        id: brightness
        property real level: 0.5
        function read() { readProc.running = true }
        function set(v) { level = Math.max(0.01, Math.min(1, v)); setProc.command = ["brightnessctl", "-q", "set", Math.round(level * 100) + "%"]; setProc.running = true }
    }
    Process {
        id: readProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector { onStreamFinished: { const f = text.trim().split(","); if (f.length >= 5) brightness.level = Number(f[2]) / Number(f[4]) } }
    }
    Process { id: setProc }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // com o equalizador no meio, a saída padrão é a virtual do EasyEffects: mostra o aparelho real dele
    readonly property bool viaEq: controls.rawSink !== null && (controls.rawSink.name || "").startsWith("easyeffects")
    readonly property var eqOut: Pipewire.nodes.values.find(n => n.name === eqConf.outputDevice) || null
    readonly property string outLabel: viaEq ? "EQ · " + (eqOut ? picker.label(eqOut) : "saída") : picker.label(controls.rawSink)
    FileView {
        id: eqConf
        path: Quickshell.env("HOME") + "/.config/easyeffects/db/easyeffectsrc"
        watchChanges: true
        onFileChanged: reload()
        readonly property string outputDevice: { const m = /outputDevice=(.*)/.exec(text()); return m ? m[1].trim() : "" }
    }

    // ───────── componentes ─────────
    component Tile: Rectangle {
        id: t
        property string glyph
        property string title
        property string sub
        property bool on: false
        signal toggled()
        signal longPressed()
        width: tiles.tw; height: 50; radius: 14
        color: on ? panel.primary : (ma.containsMouse ? Qt.lighter(panel.card, 1.25) : panel.card)
        border.width: on ? 0 : 1; border.color: panel.line
        Behavior on color { ColorAnimation { duration: 180 } }
        Row {
            anchors.left: parent.left; anchors.leftMargin: 11; anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            Text { anchors.verticalCenter: parent.verticalCenter; width: 18; horizontalAlignment: Text.AlignHCenter; text: t.glyph; font.pixelSize: 16; color: t.on ? Colors.bg : panel.primary }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: t.title; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 14; color: t.on ? Colors.bg : panel.fg }
                Text { width: t.width - 50; text: t.sub; elide: Text.ElideRight; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 11; color: Qt.alpha(t.on ? Colors.bg : panel.fg, t.on ? 0.75 : 0.55) }
            }
        }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => mouse.button === Qt.RightButton ? t.longPressed() : t.toggled()
                    onPressAndHold: t.longPressed() }
    }

    component Slide: Rectangle {
        id: b
        property string glyph
        property real value: 0
        property bool muted: false
        property real rightReserve: 0
        signal moved(real v)
        signal glyphClicked()
        width: controls.cw; height: 36; radius: 14
        color: panel.card; border.width: 1; border.color: panel.line
        Text { id: g; anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
               text: b.glyph; font.pixelSize: 14; color: b.muted ? Qt.alpha(panel.fg, 0.35) : panel.primary
               MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: b.glyphClicked() } }
        Text { id: pct; anchors.right: parent.right; anchors.rightMargin: 12 + b.rightReserve; anchors.verticalCenter: parent.verticalCenter
               text: Math.round(b.value * 100) + "%"; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 13; color: panel.fg }
        Item {
            id: track
            anchors.left: g.right; anchors.leftMargin: 10; anchors.right: pct.left; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter; height: 16
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Qt.alpha(panel.primary, 0.15) }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.min(1, b.value); height: 4; radius: 2; color: b.muted ? Qt.alpha(panel.fg, 0.35) : panel.primary }
            Rectangle { x: parent.width * Math.min(1, b.value) - 6; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: panel.fg; border.width: 2; border.color: panel.primary }
            MouseArea {
                anchors.fill: parent; anchors.margins: -6
                function at(mx) { return Math.max(0, Math.min(1, (mx - 6) / (width - 12))) }
                onPressed: mouse => b.moved(at(mouse.x))
                onPositionChanged: mouse => { if (pressed) b.moved(at(mouse.x)) }
            }
        }
        MouseArea {   // rolar (mouse ou touchpad) muda o valor: um "clique" de roda = 5%
            anchors.fill: parent; z: -1
            acceptedButtons: Qt.NoButton
            onWheel: wheel => b.moved(Math.max(0, Math.min(1, b.value + wheel.angleDelta.y / 2400)))
        }
    }
}
