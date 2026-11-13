// Project Azmuth — aba Telas da Central: projetor/monitor externo (src/display.py).
// Modos como o "Projetar" do Windows; a escolha é salva e reaplicada no login e ao plugar o cabo.

import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: dp
    property bool active: false
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"

    property var st: null
    property string notice: ""
    property bool noticeError: false
    readonly property var cfg: st ? st.settings : ({ mode: "mirror", position: "right", scale: 1, resolution: "preferred" })
    readonly property var ext: st ? st.monitors.find(m => !m.internal) || null : null
    readonly property var inner: st ? st.monitors.find(m => m.internal) || null : null
    readonly property bool hasExt: ext !== null
    readonly property var modes: [
        { id: "mirror",   name: "ESPELHAR",       hint: "A mesma imagem no notebook e no projetor", glyph: "visao" },
        { id: "extend",   name: "ESTENDER",       hint: "O projetor vira uma área de trabalho a mais", glyph: "portal" },
        { id: "external", name: "SÓ O PROJETOR",  hint: "A tela do notebook apaga", glyph: "midia" },
        { id: "internal", name: "SÓ O NOTEBOOK",  hint: "O projetor fica sem imagem", glyph: "nucleo" }]

    function refresh() { if (!statusProc.running) statusProc.running = true }
    function run(args) {
        if (actionProc.running) return
        notice = args[0] === "force" ? "Aguardando a senha de administrador…" : "Aplicando…"; noticeError = false
        actionProc.command = [az, "display"].concat(args); actionProc.running = true
    }
    onActiveChanged: if (active) refresh()
    Timer { interval: 3000; repeat: true; running: dp.active; onTriggered: dp.refresh() }

    Process {
        id: statusProc
        command: [dp.az, "display", "status", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { dp.st = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { const r = JSON.parse(text); dp.notice = r.ok ? r.message : r.error; dp.noticeError = !r.ok }
                catch (e) { dp.notice = "O comando não respondeu."; dp.noticeError = true }
                dp.refresh()
            }
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: Math.min(parent.width, 720)
            spacing: 10

            UiSection { text: "TELAS" }

            // ── desenho do arranjo ──
            Rectangle {
                width: parent.width; height: 170; radius: 12
                color: Qt.alpha(Colors.primary, 0.04)
                border.width: 1; border.color: Qt.alpha(Colors.primary, 0.2)
                Item {
                    id: stage
                    anchors.centerIn: parent
                    readonly property string m: dp.cfg.mode
                    readonly property bool side: m === "extend" && (dp.cfg.position === "left" || dp.cfg.position === "right")
                    width: dp.hasExt && m === "extend" ? (side ? 380 : 190) : 190
                    height: dp.hasExt && m === "extend" && !side ? 150 : 110
                    ScreenBox {
                        id: lap
                        title: "NOTEBOOK"; sub: dp.inner ? dp.inner.width + "×" + dp.inner.height : ""
                        off: dp.hasExt && stage.m === "external"
                        x: stage.m === "extend" && dp.cfg.position === "left" ? 200 : (stage.m === "mirror" && dp.hasExt ? -14 : 0)
                        y: stage.m === "extend" && dp.cfg.position === "up" ? 80 : 0
                    }
                    ScreenBox {
                        visible: dp.hasExt
                        title: stage.m === "mirror" ? "PROJETOR · ESPELHO" : "PROJETOR"
                        sub: dp.ext ? dp.ext.width + "×" + dp.ext.height : ""
                        off: stage.m === "internal"
                        accent: true
                        x: stage.m === "extend" ? (dp.cfg.position === "right" ? 200 : (dp.cfg.position === "left" ? 0 : 0)) : 14
                        y: stage.m === "extend" ? (dp.cfg.position === "down" ? 80 : (dp.cfg.position === "up" ? 0 : 0)) : 10
                        z: stage.m === "mirror" ? -1 : 1
                    }
                }
                Text {
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter
                    visible: !dp.hasExt
                    text: dp.st && dp.st.pending.length ? "Cabo detectado em " + dp.st.pending.join(", ") + ", mas sem imagem — use FORÇAR DETECÇÃO"
                                                       : "Nenhum projetor ou monitor conectado"
                    font.family: "Rajdhani"; font.pixelSize: 14; color: dp.st && dp.st.pending.length ? Colors.warn : Qt.alpha(Colors.fg, 0.5)
                }
            }

            // ── modos ──
            Grid {
                width: parent.width; columns: 2; spacing: 10
                Repeater {
                    model: dp.modes
                    Rectangle {
                        id: mc
                        required property var modelData
                        readonly property bool on: dp.cfg.mode === modelData.id
                        width: (col.width - 10) / 2; height: 62; radius: 10
                        color: on ? Qt.alpha(Colors.primary, 0.14) : (mm.containsMouse ? Qt.alpha(Colors.primary, 0.06) : "transparent")
                        border.width: on ? 1.5 : 1; border.color: Qt.alpha(Colors.primary, on ? 0.8 : 0.25)
                        Glyph { x: 16; anchors.verticalCenter: parent.verticalCenter; width: 26; height: 26; name: mc.modelData.glyph; color: mc.on ? Colors.primary : Qt.alpha(Colors.fg, 0.6); stroke: 2 }
                        Column {
                            x: 56; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 66
                            Text { text: mc.modelData.name; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 12; font.letterSpacing: 1; color: mc.on ? Colors.primary : Colors.fg }
                            Text { width: parent.width; elide: Text.ElideRight; text: mc.modelData.hint; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.55) }
                        }
                        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dp.run(["set", "mode", mc.modelData.id]) }
                    }
                }
            }

            // ── posição ao estender ──
            Row {
                visible: dp.cfg.mode === "extend"
                spacing: 8
                Text { anchors.verticalCenter: parent.verticalCenter; text: "PROJETOR À"; font.family: "Orbitron"; font.pixelSize: 10; color: Qt.alpha(Colors.fg, 0.55); rightPadding: 6 }
                Repeater {
                    model: [{ id: "left", t: "ESQUERDA" }, { id: "right", t: "DIREITA" }, { id: "up", t: "ACIMA" }, { id: "down", t: "ABAIXO" }]
                    UiButton { required property var modelData; text: modelData.t; filled: dp.cfg.position === modelData.id; onClicked: dp.run(["set", "position", modelData.id]) }
                }
            }

            // ── resolução e escala do projetor ──
            UiSection { visible: dp.hasExt; text: "PROJETOR · " + (dp.ext ? dp.ext.name + (dp.ext.label !== dp.ext.name ? " · " + dp.ext.label : "") : "") }
            Flow {
                visible: dp.hasExt
                width: parent.width; spacing: 6
                Text { text: "RESOLUÇÃO"; font.family: "Orbitron"; font.pixelSize: 10; color: Qt.alpha(Colors.fg, 0.55); topPadding: 9; rightPadding: 6 }
                UiButton { text: "AUTOMÁTICA"; filled: dp.cfg.resolution === "preferred"; onClicked: dp.run(["set", "resolution", "preferred"]) }
                Repeater {
                    model: dp.ext ? dp.ext.modes.filter((m, i, a) => a.indexOf(m) === i).slice(0, 8) : []
                    UiButton { required property string modelData; text: modelData.replace("@", " · ") + "Hz"; filled: dp.cfg.resolution === modelData; onClicked: dp.run(["set", "resolution", modelData]) }
                }
            }
            Row {
                visible: dp.hasExt && dp.cfg.mode !== "mirror" && dp.cfg.mode !== "internal"
                spacing: 6
                Text { anchors.verticalCenter: parent.verticalCenter; text: "ESCALA"; font.family: "Orbitron"; font.pixelSize: 10; color: Qt.alpha(Colors.fg, 0.55); rightPadding: 6 }
                Repeater {
                    model: [1, 1.25, 1.5, 2]
                    UiButton { required property real modelData; text: Math.round(modelData * 100) + "%"; filled: Math.abs(dp.cfg.scale - modelData) < 0.01; onClicked: dp.run(["set", "scale", String(modelData)]) }
                }
            }

            // ── problemas de cabo ──
            UiSection { text: "PROJETOR NÃO APARECE?" }
            Rectangle {
                width: parent.width; height: fixCol.implicitHeight + 28; radius: 10
                color: Qt.alpha(Colors.warn, 0.06); border.width: 1; border.color: Qt.alpha(Colors.warn, 0.35)
                Column {
                    id: fixCol
                    x: 16; y: 14; width: parent.width - 32 - forceBtn.width - 16
                    spacing: 4
                    Text { width: parent.width; wrapMode: Text.WordWrap; text: "Encaixe o cabo dos dois lados e confira a entrada do projetor. Se a detecção continuar falhando (cabo ou adaptador instável), force a porta: o notebook liga a saída mesmo sem o sinal de conexão. Pede a senha de administrador e vale até reiniciar."; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.75) }
                    Text {
                        text: dp.st ? dp.st.connectors.filter(c => !c.internal).map(c => c.name + ": " + (c.status === "connected" ? "cabo detectado" : "nada detectado")).join(" · ") : ""
                        font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: Qt.alpha(Colors.fg, 0.55)
                    }
                }
                UiButton {
                    id: forceBtn
                    anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                    text: "FORÇAR DETECÇÃO"; glyph: "energia"; tint: Colors.warn
                    onClicked: dp.run(["force"])
                }
            }

            Text {
                visible: dp.notice !== ""
                width: parent.width; wrapMode: Text.WordWrap
                text: dp.notice
                font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 15
                color: dp.noticeError ? Colors.danger : Colors.primary
            }
            Text {
                width: parent.width; wrapMode: Text.WordWrap; topPadding: 4
                text: "A escolha fica salva: volta sozinha ao ligar o notebook e sempre que um cabo for conectado. Pelo terminal: azmuth display set mode mirror|extend|external|internal."
                font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.45)
            }
        }
    }

    // tela desenhada no arranjo
    component ScreenBox: Item {
        id: sb
        property string title: ""
        property string sub: ""
        property bool off: false
        property bool accent: false
        width: 176; height: 100
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.fill: parent; radius: 8
            color: sb.off ? Qt.alpha(Colors.fg, 0.03) : Qt.alpha(Colors.primary, sb.accent ? 0.16 : 0.1)
            border.width: 1.5; border.color: sb.off ? Qt.alpha(Colors.fg, 0.2) : Qt.alpha(Colors.primary, sb.accent ? 0.9 : 0.6)
            Column {
                anchors.centerIn: parent; spacing: 2
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: sb.title; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 10; color: sb.off ? Qt.alpha(Colors.fg, 0.35) : Colors.primary }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: sb.off ? "desligada" : sb.sub; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; color: Qt.alpha(Colors.fg, 0.6) }
            }
        }
    }
}
