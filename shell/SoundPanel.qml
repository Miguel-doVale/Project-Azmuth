// Project Azmuth — console de áudio: dispositivos, rotas, mixer e EQ.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Widgets

Item {
    id: sp
    property bool active: false
    property int page: 0
    property var routes: ({ outputs: [], inputs: [] })
    property var eqBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property bool eqInstalled: false
    property bool eqReady: false
    property bool eqOn: false
    property string notice: ""
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"
    readonly property var all: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: all.filter(n => n.isSink && !n.isStream)
    readonly property var sources: all.filter(n => !n.isSink && !n.isStream && !(n.name || "").includes(".monitor"))
    readonly property var streams: all.filter(n => n.isStream && n.isSink)
    readonly property var out: Pipewire.defaultAudioSink
    readonly property var input: Pipewire.defaultAudioSource
    readonly property var labels: ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    PwObjectTracker { objects: sp.all }
    PwNodePeakMonitor { id: outputPeak; node: sp.out; enabled: sp.active }
    PwNodePeakMonitor { id: inputPeak; node: sp.input; enabled: sp.active }

    function deviceName(n) { return n ? (n.nickname || n.description || n.name || "Dispositivo") : "Nenhum dispositivo" }
    function appName(n) {
        const p = n.properties || {}
        return p["application.name"] || n.nickname || n.description || n.name
    }
    function appIcon(n) {
        const p = n.properties || {}
        const name = p["application.icon-name"] || p["application.process.binary"] || p["application.name"] || ""
        return Quickshell.iconPath(String(name).toLowerCase(), true) || Quickshell.iconPath("audio-volume-high", true) || ""
    }
    function routeInfo(node, direction) {
        if (!node) return null
        return (direction === "output" ? routes.outputs : routes.inputs).find(r => r.name === node.name) || null
    }
    function availability(v) {
        return v === "yes" ? "DETECTADO" : v === "no" ? "NÃO CONECTADO" : "ESTADO DESCONHECIDO"
    }
    function refreshData() {
        if (!inventoryProc.running) inventoryProc.running = true
        if (!eqStatusProc.running) eqStatusProc.running = true
    }
    function runAudio(args) {
        if (audioAction.running) return
        audioAction.command = [az, "audio"].concat(args)
        audioAction.running = true
    }
    function setBand(i, v) {
        const next = eqBands.slice()
        next[i] = Math.max(-12, Math.min(12, Math.round(v * 2) / 2))
        eqBands = next
    }
    function showAction(raw) {
        if (!raw || !raw.trim()) return
        try {
            const r = JSON.parse(raw)
            notice = r.message || (r.ok ? "" : "Não foi possível aplicar a alteração.")
            if (r.gains && r.gains.length === 10) eqBands = r.gains
            if (r.enabled !== undefined) eqOn = r.enabled
            if (r.outputs && r.inputs) routes = r
        } catch (e) { notice = raw.trim() }
        if (notice) feedback.restart()
        refreshSoon.restart()
    }

    Process {
        id: inventoryProc
        command: [sp.az, "audio", "inventory", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(this.text); if (r.ok) sp.routes = r }
                catch (e) {}
            }
        }
    }
    Process {
        id: eqStatusProc
        command: [sp.az, "audio", "eq", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(this.text)
                    sp.eqInstalled = !!r.installed; sp.eqReady = !!r.ready; sp.eqOn = !!r.enabled
                    if (r.gains && r.gains.length === 10) sp.eqBands = r.gains
                } catch (e) { sp.eqInstalled = false; sp.eqReady = false }
            }
        }
    }
    Process { id: audioAction; stdout: StdioCollector { onStreamFinished: sp.showAction(this.text) } }
    Timer { id: periodic; interval: 2200; repeat: true; running: sp.active; onTriggered: sp.refreshData() }
    Timer { id: refreshSoon; interval: 350; onTriggered: sp.refreshData() }
    Timer { id: feedback; interval: 2800; onTriggered: sp.notice = "" }
    onActiveChanged: if (active) refreshData()

    component Device: Rectangle {
        id: dv
        property var node: null
        property bool isDefault: false
        property string kind: "output"
        signal choose
        width: parent ? parent.width : 0; height: 72; radius: 10
        color: isDefault ? Qt.alpha(Colors.primary, 0.09) : (dm.containsMouse ? Qt.alpha(Colors.primary, 0.045) : "transparent")
        border.width: isDefault ? 1.2 : 1
        border.color: isDefault ? Qt.alpha(Colors.primary, 0.58) : Qt.alpha(Colors.fg, 0.1)
        MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dv.choose() }
        Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 23; height: 23; name: dv.kind === "output" ? "som" : "mente"; color: dv.isDefault ? Colors.primary : Qt.alpha(Colors.fg, 0.52); stroke: 1.8 }
        Column {
            x: 50; anchors.verticalCenter: parent.verticalCenter
            width: Math.max(105, parent.width - 50 - controls.width - 20); spacing: 1
            Text { width: parent.width; elide: Text.ElideRight; text: sp.deviceName(dv.node); font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: dv.isDefault ? Colors.primary : Colors.fg }
            Text { width: parent.width; elide: Text.ElideRight; text: dv.isDefault ? "EM USO · clique para alternar" : "disponível para selecionar"; font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(Colors.fg, 0.5) }
        }
        Row {
            id: controls
            anchors.right: parent.right; anchors.rightMargin: 9; anchors.verticalCenter: parent.verticalCenter; spacing: 6
            UiSlider {
                anchors.verticalCenter: parent.verticalCenter; width: Math.min(112, Math.max(68, dv.width * 0.14)); maximum: 1.5
                value: dv.node && dv.node.audio ? dv.node.audio.volume : 0
                tint: dv.node && dv.node.audio && dv.node.audio.muted ? Qt.alpha(Colors.fg, 0.3) : Colors.primary
                onMoved: v => { if (dv.node && dv.node.audio) dv.node.audio.volume = v }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; width: 34; horizontalAlignment: Text.AlignRight; text: dv.node && dv.node.audio ? Math.round(dv.node.audio.volume * 100) + "%" : "—"; font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold; color: Colors.fg }
            UiButton { anchors.verticalCenter: parent.verticalCenter; width: 29; glyph: "fantasma"; tint: dv.node && dv.node.audio && dv.node.audio.muted ? Colors.danger : Qt.alpha(Colors.fg, 0.58); onClicked: if (dv.node && dv.node.audio) dv.node.audio.muted = !dv.node.audio.muted }
        }
    }

    component Port: Rectangle {
        id: pr
        property var port: null
        property string direction: "output"
        property string nodeName: ""
        property bool selected: false
        readonly property bool unavailable: port && port.availability === "no"
        signal choose
        width: parent ? parent.width : 0; height: 40; radius: 8
        color: selected ? Qt.alpha(Colors.primary, 0.11) : (pm.containsMouse ? Qt.alpha(Colors.primary, 0.05) : "transparent")
        border.width: selected ? 1 : 0; border.color: Qt.alpha(Colors.primary, 0.42)
        Row {
            anchors.left: parent.left; anchors.leftMargin: 11; anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter; spacing: 8
            Glyph { anchors.verticalCenter: parent.verticalCenter; width: 15; height: 15; name: pr.direction === "output" ? "som" : "mente"; color: pr.selected ? Colors.primary : Qt.alpha(Colors.fg, 0.45); stroke: 1.5 }
            Text {
                anchors.verticalCenter: parent.verticalCenter; width: Math.max(80, parent.width - 148); elide: Text.ElideRight
                text: pr.port ? pr.port.description : ""; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14
                color: pr.unavailable ? Qt.alpha(Colors.fg, 0.42) : (pr.selected ? Colors.primary : Colors.fg)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter; width: 120; horizontalAlignment: Text.AlignRight
                text: pr.selected ? "ROTA ATIVA" : (pr.port ? sp.availability(pr.port.availability) : "")
                font.family: "Orbitron"; font.pixelSize: 8; font.weight: Font.Bold
                color: pr.unavailable ? Qt.alpha(Colors.fg, 0.3) : (pr.selected ? Colors.primary : Qt.alpha(Colors.fg, 0.48))
            }
        }
        MouseArea {
            id: pm; anchors.fill: parent; hoverEnabled: true; enabled: !pr.unavailable && !pr.selected
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: pr.choose()
        }
    }

    component EqBand: Item {
        id: band
        property int bandIndex: 0
        property string label: ""
        property real value: 0
        signal adjusted(real value)
        width: 58; height: 132
        Text { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; text: band.label; font.family: "Orbitron"; font.pixelSize: 9; font.weight: Font.Bold; color: Qt.alpha(Colors.fg, 0.68) }
        Item {
            id: track; anchors.top: parent.top; anchors.topMargin: 18; anchors.horizontalCenter: parent.horizontalCenter; width: 32; height: 82
            readonly property real knobY: (12 - band.value) / 24 * (height - 12)
            Rectangle { x: 14; y: 2; width: 4; height: track.height - 4; radius: 2; color: Qt.alpha(Colors.fg, 0.16) }
            Rectangle { x: 14; width: 4; radius: 2; y: band.value >= 0 ? track.height / 2 - (band.value / 12) * (track.height / 2 - 6) : track.height / 2; height: Math.abs(band.value) / 12 * (track.height / 2 - 6); color: Qt.alpha(Colors.primary, 0.8) }
            Rectangle { x: 7; y: track.height / 2 - 1; width: 18; height: 2; color: Qt.alpha(Colors.fg, 0.35) }
            Rectangle { x: 7; y: track.knobY; width: 18; height: 12; radius: 6; color: Colors.bg; border.width: 2; border.color: Colors.primary }
            MouseArea {
                anchors.fill: parent; enabled: sp.eqReady && sp.eqOn; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                function setValue(y) { const p = 1 - Math.max(0, Math.min(track.height, y)) / track.height; band.adjusted(Math.round((p * 24 - 12) * 2) / 2) }
                onPressed: mouse => setValue(mouse.y)
                onPositionChanged: mouse => { if (pressed) setValue(mouse.y) }
                onWheel: wheel => band.adjusted(Math.max(-12, Math.min(12, band.value + (wheel.angleDelta.y > 0 ? 0.5 : -0.5))))
            }
        }
        Text { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; text: (band.value > 0 ? "+" : "") + band.value.toFixed(1); font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9; color: sp.eqOn ? Colors.fg : Qt.alpha(Colors.fg, 0.38) }
        Process {
            id: gainProc
            stdout: StdioCollector {
                onStreamFinished: {
                    try { const r = JSON.parse(this.text); if (!r.ok) { sp.notice = r.message; feedback.restart() } }
                    catch (e) {}
                }
            }
        }
        Timer {
            id: writeDelay; interval: 130
            onTriggered: {
                if (gainProc.running) { restart(); return }
                gainProc.command = [sp.az, "audio", "eq", "gain", String(band.bandIndex), band.value.toFixed(1)]
                gainProc.running = true
            }
        }
        Connections { target: band; function onAdjusted(v) { sp.setBand(band.bandIndex, v); writeDelay.restart() } }
    }

    Flickable {
        anchors.fill: parent; contentHeight: col.implicitHeight + 20; clip: true; boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col; width: Math.min(parent.width, 840); spacing: 9
            Row {
                spacing: 8
                UiButton { text: "DISPOSITIVOS"; glyph: "som"; filled: sp.page === 0; onClicked: sp.page = 0 }
                UiButton { text: "EQUALIZADOR"; glyph: "visao"; filled: sp.page === 1; onClicked: sp.page = 1 }
                Item { width: Math.max(0, col.width - 350); height: 1 }
                UiButton { text: "ATUALIZAR"; glyph: "tempo"; tint: Qt.alpha(Colors.fg, 0.65); onClicked: sp.refreshData() }
            }
            Rectangle {
                width: col.width; height: 88; radius: 12; color: Qt.alpha(Colors.primary, 0.055); border.width: 1; border.color: Qt.alpha(Colors.primary, 0.27)
                Row {
                    anchors.fill: parent; anchors.margins: 13; spacing: 18
                    Item {
                        width: (parent.width - 18) / 2; height: parent.height
                        Glyph { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 23; height: 23; name: "som"; color: Colors.primary; stroke: 1.8 }
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 34; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 75; spacing: 1
                            Text { text: "SAÍDA ATIVA"; font.family: "Orbitron"; font.pixelSize: 9; font.letterSpacing: 1.4; color: Qt.alpha(Colors.fg, 0.5) }
                            Text { width: parent.width; elide: Text.ElideRight; text: sp.deviceName(sp.out); font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: Colors.primary }
                            Text { text: sp.out && sp.out.audio ? (sp.out.audio.muted ? "MUDO" : Math.round(sp.out.audio.volume * 100) + "% · saída") : "sem saída"; font.family: "Rajdhani"; font.pixelSize: 12; color: Qt.alpha(Colors.fg, 0.62) }
                        }
                        Row {
                            anchors.right: parent.right; anchors.bottom: parent.bottom; spacing: 2; height: 21
                            Repeater {
                                model: 12
                                Rectangle {
                                    required property int index
                                    anchors.bottom: parent.bottom; width: 4; radius: 2
                                    readonly property real shape: 0.4 + 0.6 * Math.abs(Math.sin(index * 0.82 + phase.t))
                                    height: 3 + 18 * Math.min(1, outputPeak.peak * 1.7 * shape); color: Qt.alpha(Colors.primary, 0.3 + 0.7 * shape)
                                    Behavior on height { NumberAnimation { duration: 100 } }
                                }
                            }
                        }
                    }
                    Rectangle { width: 1; height: parent.height; color: Qt.alpha(Colors.primary, 0.16) }
                    Item {
                        width: (parent.width - 18) / 2; height: parent.height
                        Glyph { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: 23; height: 23; name: "mente"; color: inputPeak.peak > 0.01 ? Colors.primary : Qt.alpha(Colors.fg, 0.48); stroke: 1.8 }
                        Column {
                            anchors.left: parent.left; anchors.leftMargin: 34; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 75; spacing: 1
                            Text { text: "MICROFONE ATIVO"; font.family: "Orbitron"; font.pixelSize: 9; font.letterSpacing: 1.4; color: Qt.alpha(Colors.fg, 0.5) }
                            Text { width: parent.width; elide: Text.ElideRight; text: sp.deviceName(sp.input); font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: inputPeak.peak > 0.01 ? Colors.primary : Colors.fg }
                            Text { text: sp.input && sp.input.audio ? (sp.input.audio.muted ? "MUDO" : Math.round(sp.input.audio.volume * 100) + "% · entrada") : "sem microfone"; font.family: "Rajdhani"; font.pixelSize: 12; color: Qt.alpha(Colors.fg, 0.62) }
                        }
                        Row {
                            anchors.right: parent.right; anchors.bottom: parent.bottom; spacing: 2; height: 21
                            Repeater {
                                model: 12
                                Rectangle {
                                    required property int index
                                    anchors.bottom: parent.bottom; width: 4; radius: 2
                                    readonly property real shape: 0.4 + 0.6 * Math.abs(Math.sin(index * 0.82 + phase.t + 1.4))
                                    height: 3 + 18 * Math.min(1, inputPeak.peak * 1.7 * shape); color: Qt.alpha(Colors.primary, 0.3 + 0.7 * shape)
                                    Behavior on height { NumberAnimation { duration: 100 } }
                                }
                            }
                        }
                    }
                }
                QtObject { id: phase; property real t: 0 }
                Timer { interval: 55; repeat: true; running: sp.active; onTriggered: phase.t += 0.32 }
            }
            Text { visible: sp.notice !== ""; width: col.width; wrapMode: Text.WordWrap; text: sp.notice; font.family: "Rajdhani"; font.pixelSize: 14; color: Colors.warn }

            Column {
                width: col.width; spacing: 8; visible: sp.page === 0
                UiSection { text: "SAÍDAS · FONES E ALTO-FALANTES" }
                Repeater {
                    model: sp.sinks
                    Device { required property var modelData; width: col.width; node: modelData; kind: "output"; isDefault: sp.out === modelData; onChoose: Pipewire.preferredDefaultAudioSink = modelData }
                }
                Text { visible: sp.sinks.length === 0; text: "Nenhuma saída detectada."; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.48) }
                UiSection { text: "ROTA FÍSICA DA SAÍDA" }
                Text { visible: !sp.routeInfo(sp.out, "output"); text: "As portas de fone e alto-falante aparecem quando o hardware as publica."; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.5) }
                Repeater {
                    model: sp.routeInfo(sp.out, "output") ? sp.routeInfo(sp.out, "output").ports : []
                    Port {
                        required property var modelData; width: col.width; port: modelData; direction: "output"; nodeName: sp.out ? sp.out.name : ""
                        selected: sp.routeInfo(sp.out, "output") ? sp.routeInfo(sp.out, "output").active_port === modelData.name : false
                        onChoose: sp.runAudio(["route", "output", nodeName, port.name])
                    }
                }
                UiSection { text: "MICROFONES · " + sp.sources.length + " DETECTADO(S)" }
                Repeater {
                    model: sp.sources
                    Device { required property var modelData; width: col.width; node: modelData; kind: "input"; isDefault: sp.input === modelData; onChoose: Pipewire.preferredDefaultAudioSource = modelData }
                }
                Text { visible: sp.sources.length === 0; text: "Nenhum microfone detectado."; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.48) }
                UiSection { text: "ROTA FÍSICA DO MICROFONE" }
                Text { visible: !sp.routeInfo(sp.input, "input"); text: "Entradas de headset aparecem quando o hardware as disponibiliza."; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.5) }
                Repeater {
                    model: sp.routeInfo(sp.input, "input") ? sp.routeInfo(sp.input, "input").ports : []
                    Port {
                        required property var modelData; width: col.width; port: modelData; direction: "input"; nodeName: sp.input ? sp.input.name : ""
                        selected: sp.routeInfo(sp.input, "input") ? sp.routeInfo(sp.input, "input").active_port === modelData.name : false
                        onChoose: sp.runAudio(["route", "input", nodeName, port.name])
                    }
                }
                UiSection { text: "MIXER DE APLICATIVOS · " + sp.streams.length + " FLUXO(S)" }
                Text { visible: sp.streams.length === 0; text: "Os aplicativos aparecem aqui enquanto reproduzem áudio."; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.5) }
                Repeater {
                    model: sp.streams
                    Rectangle {
                        id: streamRow; required property var modelData; width: col.width; height: 52; radius: 8
                        color: sm.containsMouse ? Qt.alpha(Colors.primary, 0.04) : "transparent"
                        IconImage { x: 9; anchors.verticalCenter: parent.verticalCenter; implicitSize: 27; source: sp.appIcon(streamRow.modelData) }
                        Column {
                            x: 47; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 47 - 226
                            Text { width: parent.width; elide: Text.ElideRight; text: sp.appName(streamRow.modelData); font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 15; color: Colors.fg }
                            Text { width: parent.width; elide: Text.ElideRight; text: (streamRow.modelData.properties || {})["media.name"] || "reproduzindo"; font.family: "Rajdhani"; font.pixelSize: 12; color: Qt.alpha(Colors.fg, 0.48) }
                        }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                            UiSlider { anchors.verticalCenter: parent.verticalCenter; width: 112; value: streamRow.modelData.audio ? streamRow.modelData.audio.volume : 0; onMoved: v => { if (streamRow.modelData.audio) streamRow.modelData.audio.volume = v } }
                            Text { anchors.verticalCenter: parent.verticalCenter; width: 34; horizontalAlignment: Text.AlignRight; text: streamRow.modelData.audio ? Math.round(streamRow.modelData.audio.volume * 100) + "%" : "—"; font.family: "Orbitron"; font.pixelSize: 10; color: Colors.fg }
                            UiButton { anchors.verticalCenter: parent.verticalCenter; width: 28; glyph: "fantasma"; tint: streamRow.modelData.audio && streamRow.modelData.audio.muted ? Colors.danger : Qt.alpha(Colors.fg, 0.58); onClicked: if (streamRow.modelData.audio) streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted }
                        }
                        MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    }
                }
            }

            Column {
                width: col.width; spacing: 10; visible: sp.page === 1
                Rectangle {
                    width: col.width; height: 86; radius: 12; color: Qt.alpha(Colors.primary, 0.06); border.width: 1; border.color: Qt.alpha(Colors.primary, 0.28)
                    Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 27; height: 27; name: "som"; color: Colors.primary; stroke: 2 }
                    Column {
                        x: 55; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 224; spacing: 2
                        Text { text: "EQUALIZADOR DO SISTEMA"; font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.3; color: Colors.primary }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap
                            text: !sp.eqInstalled ? "EasyEffects é necessário para equalizar o áudio do sistema."
                                : (!sp.eqReady ? "Conecte o servidor local para liberar os controles."
                                : (sp.eqOn ? "Ativo · 10 bandas · saída atual" : "Conectado e em bypass"))
                            font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.68)
                        }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                        UiButton { visible: !sp.eqOn && sp.eqInstalled; text: "ATIVAR"; glyph: "energia"; filled: true; onClicked: sp.runAudio(["eq", "enable"]) }
                        UiButton { visible: sp.eqOn; text: "PAUSAR"; glyph: "fantasma"; tint: Colors.warn; onClicked: sp.runAudio(["eq", "bypass", "on"]) }
                        UiButton { visible: sp.eqInstalled; text: "AVANÇADO"; glyph: "portal"; tint: Qt.alpha(Colors.fg, 0.72); onClicked: sp.runAudio(["eq", "open"]) }
                    }
                }
                Text { visible: !sp.eqInstalled; width: col.width; wrapMode: Text.WordWrap; text: "No Arch: sudo pacman -S --needed easyeffects. O painel controla o EQ pelo servidor local do EasyEffects."; font.family: "Rajdhani"; font.pixelSize: 14; color: Colors.warn }
                Text { visible: sp.eqInstalled && !sp.eqReady; width: col.width; wrapMode: Text.WordWrap; text: "Se não conectar ao ativar, abra as preferências do EasyEffects e habilite o servidor local. As saídas físicas permanecem como destinos padrão."; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.58) }
                UiSection { visible: sp.eqInstalled; text: "CURVAS INICIAIS" }
                Row {
                    visible: sp.eqInstalled
                    spacing: 7
                    UiButton { text: "PLANA"; glyph: "tempo"; onClicked: sp.runAudio(["eq", "preset", "flat"]) }
                    UiButton { text: "GRAVES"; glyph: "som"; onClicked: sp.runAudio(["eq", "preset", "bass"]) }
                    UiButton { text: "VOZ"; glyph: "mente"; onClicked: sp.runAudio(["eq", "preset", "voice"]) }
                    UiButton { text: "BRILHO"; glyph: "visao"; onClicked: sp.runAudio(["eq", "preset", "treble"]) }
                }
                Rectangle {
                    width: col.width; height: 174; radius: 12; color: Qt.alpha(Colors.bg, 0.28); border.width: 1; border.color: Qt.alpha(Colors.primary, 0.2)
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        Row {
                            spacing: 2
                            Repeater {
                                model: 10
                                EqBand { required property int modelData; bandIndex: modelData; label: sp.labels[modelData]; value: sp.eqBands[modelData] || 0 }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "FREQUÊNCIA · Hz"; font.family: "Orbitron"; font.pixelSize: 8; font.letterSpacing: 1.5; color: Qt.alpha(Colors.fg, 0.42) }
                    }
                }
                Text { width: col.width; wrapMode: Text.WordWrap; text: "Bandas de −12 a +12 dB. As curvas são pontos de partida; o ganho de saída acompanha o maior reforço para reduzir clipping."; font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(Colors.fg, 0.53) }
            }
        }
    }
}
