// Project Azmuth — o assistente Azmuth (Super + A). Conversa via `azmuth ask` (Claude Code em
// modo não interativo). Ele só age pelos comandos `azmuth`. Enter envia · Esc fecha.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: ai

    property bool open: false
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: ai.open ? 300 : 160; easing.type: Easing.OutCubic } }
    readonly property color galvan: "#4dff8a"
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"

    property var messages: []        // [{ from: "eu"|"azmuth", text, error }]
    property bool thinking: false
    property bool fresh: true        // próxima pergunta começa conversa nova
    readonly property var quips: [
        "Consultando cinco galáxias de conhecimento…", "Calculando. Obviamente.", "Sequenciando a resposta…",
        "Paciência é uma virtude Galvan. Você não tem.", "Recalibrando os circuitos do Omnitrix…", "Analisando seu DNA de dúvida…"
    ]
    property int quip: 0

    function toggle() {
        open = !open
        if (open) { input.forceActiveFocus(); if (!messages.length) greet() }
    }
    function greet() {
        messages = [{ from: "azmuth", text: "Azmuth na escuta. Peça para transformar, abrir apps, marcar eventos ou pergunte qualquer coisa. Seja breve." }]
    }
    function send() {
        const t = input.text.trim()
        if (!t || thinking) return
        input.text = ""
        messages = messages.concat([{ from: "eu", text: t }])
        thinking = true
        quip = Math.floor(Math.random() * quips.length)
        askProc.command = [az, "ask", "--json"].concat(fresh ? ["--new"] : []).concat([t])
        fresh = false
        askProc.running = true
        Quickshell.execDetached(["pw-play", decodeURIComponent(Qt.resolvedUrl("../assets/sounds/hud_open.wav").toString().replace("file://", ""))])
    }
    function reset() { fresh = true; greet() }

    Process {
        id: askProc
        stdout: StdioCollector {
            onStreamFinished: {
                let r
                try { r = JSON.parse(this.text) } catch (e) { r = { ok: false, reply: "Resposta corrompida do núcleo. Trabalho patético." } }
                ai.messages = ai.messages.concat([{ from: "azmuth", text: r.reply, error: !r.ok }])
                ai.thinking = false
                list.positionViewAtEnd()
            }
        }
    }
    Timer { interval: 2200; repeat: true; running: ai.thinking; onTriggered: ai.quip = (ai.quip + 1) % ai.quips.length }

    visible: open || reveal > 0.01
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-assistant"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.55 * ai.reveal; MouseArea { anchors.fill: parent; onClicked: ai.open = false } }

    Item {
        id: card
        width: Math.min(parent.width * 0.6, 780)
        height: Math.min(parent.height * 0.78, 720)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - ai.reveal) * 40
        opacity: ai.reveal
        MouseArea { anchors.fill: parent }

        Shape {   // placa chanfrada
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Qt.alpha(Colors.bg, 0.97); strokeColor: Qt.alpha(ai.galvan, 0.6); strokeWidth: 1.5
                startX: 22; startY: 0
                PathLine { x: card.width - 22; y: 0 } PathLine { x: card.width; y: 22 } PathLine { x: card.width; y: card.height - 22 }
                PathLine { x: card.width - 22; y: card.height } PathLine { x: 22; y: card.height } PathLine { x: 0; y: card.height - 22 }
                PathLine { x: 0; y: 22 } PathLine { x: 22; y: 0 }
            }
        }

        // cabeçalho com o orbe
        Item {
            id: head
            x: 24; y: 20; width: card.width - 48; height: 76
            Item {
                id: orb
                width: 64; height: 64; anchors.verticalCenter: parent.verticalCenter
                Rectangle {   // pulso enquanto pensa
                    anchors.centerIn: parent; width: 64; height: 64; radius: 32
                    color: "transparent"; border.width: 2; border.color: ai.galvan
                    SequentialAnimation on scale {
                        running: ai.thinking; loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 1.3; duration: 700; easing.type: Easing.OutQuad }
                        NumberAnimation { from: 1.3; to: 1; duration: 0 }
                    }
                    SequentialAnimation on opacity {
                        running: ai.thinking; loops: Animation.Infinite
                        NumberAnimation { from: 0.9; to: 0; duration: 700 }
                        NumberAnimation { from: 0; to: 0.9; duration: 0 }
                    }
                }
                Rectangle {
                    anchors.centerIn: parent; width: 56; height: 56; radius: 28
                    color: "#0a0f0b"; border.width: 3; border.color: ai.galvan
                    Glyph {
                        id: orbGlyph
                        anchors.centerIn: parent; width: 30; height: 30; name: "mente"; color: ai.galvan; stroke: 2.2
                        RotationAnimation on rotation { id: orbSpin; running: ai.thinking; loops: Animation.Infinite; from: 0; to: 360; duration: 2400 }
                        // terminou de pensar: volta a runa para a posição certa
                        Connections { target: ai; function onThinkingChanged() { if (!ai.thinking) { orbSpin.stop(); orbGlyph.rotation = 0 } } }
                    }
                }
            }
            Column {
                anchors.left: orb.right; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter
                Text { text: "AZMUTH"; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 22; font.letterSpacing: 4; color: ai.galvan }
                Text {
                    text: ai.thinking ? ai.quips[ai.quip] : "Primeiro Pensador · conectado ao Omnitrix"
                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15; color: Qt.alpha(Colors.fg, 0.7)
                }
            }
            UiButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "NOVA CONVERSA"; glyph: "nucleo"; tint: ai.galvan; onClicked: ai.reset() }
        }

        // conversa
        ListView {
            id: list
            anchors { top: head.bottom; topMargin: 14; left: parent.left; leftMargin: 24; right: parent.right; rightMargin: 24; bottom: inputBox.top; bottomMargin: 14 }
            clip: true
            spacing: 10
            model: ai.messages
            boundsBehavior: Flickable.StopAtBounds
            onCountChanged: Qt.callLater(positionViewAtEnd)
            delegate: Item {
                required property var modelData
                readonly property bool mine: modelData.from === "eu"
                width: list.width
                height: bubble.height
                Rectangle {
                    id: bubble
                    anchors.right: parent.mine ? parent.right : undefined
                    anchors.left: parent.mine ? undefined : parent.left
                    width: Math.min(list.width * 0.82, msg.implicitWidth + 32)
                    height: msg.implicitHeight + 22
                    radius: 12
                    color: parent.mine ? Qt.alpha(Colors.primary, 0.16) : Qt.alpha(parent.modelData.error ? Colors.danger : ai.galvan, 0.08)
                    border.width: 1; border.color: Qt.alpha(parent.mine ? Colors.primary : (parent.modelData.error ? Colors.danger : ai.galvan), 0.45)
                    Text {
                        id: msg
                        x: 16; y: 11
                        width: Math.min(list.width * 0.82 - 32, implicitWidth)
                        text: parent.parent.modelData.text
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 16
                        color: Colors.fg
                    }
                }
            }
        }

        // entrada
        Rectangle {
            id: inputBox
            anchors { left: parent.left; leftMargin: 24; right: parent.right; rightMargin: 24; bottom: parent.bottom; bottomMargin: 22 }
            height: 50; radius: 25
            color: Qt.alpha(ai.galvan, 0.05)
            border.width: input.activeFocus ? 2 : 1; border.color: Qt.alpha(ai.galvan, input.activeFocus ? 0.9 : 0.35)
            TextInput {
                id: input
                anchors.fill: parent; anchors.leftMargin: 22; anchors.rightMargin: 60
                clip: true   // texto longo rola dentro da caixa em vez de vazar
                verticalAlignment: TextInput.AlignVCenter
                font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 17; color: Colors.fg
                selectionColor: ai.galvan
                enabled: !ai.thinking
                Keys.onReturnPressed: ai.send()
                Keys.onEnterPressed: ai.send()
                Keys.onEscapePressed: ai.open = false
                Text { anchors.verticalCenter: parent.verticalCenter; visible: input.text === ""; text: ai.thinking ? "Azmuth está pensando…" : "Fale com o Azmuth… (ex.: me transforma no Massa Cinzenta)"; font: input.font; color: Qt.alpha(Colors.fg, 0.35) }
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter
                width: 38; height: 38; radius: 19
                color: sm.containsMouse ? ai.galvan : Qt.alpha(ai.galvan, 0.2)
                Glyph { anchors.centerIn: parent; width: 18; height: 18; name: "velocidade"; color: sm.containsMouse ? Colors.bg : ai.galvan; stroke: 2 }
                MouseArea { id: sm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ai.send() }
            }
        }
    }
}
