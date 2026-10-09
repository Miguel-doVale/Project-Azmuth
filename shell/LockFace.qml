// Project Azmuth — interface da tela de bloqueio: desbloqueio pelo Omnitrix.
//
//   ←/→ (ou scroll) giram o disco · Enter trava a posição · Backspace desfaz
//   A sequência certa desbloqueia. Tab alterna para a senha do sistema (PAM).
//   3 sequências erradas → só a senha. Sem sequência configurada → só a senha.
//   Configurar: `azmuth lockseq set N 1 4 ...` (N = Neutral, 1–9 e 0 = aliens).

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Item {
    id: face

    required property var theme
    property bool preview: false          // modo prévia: não autentica de verdade
    signal unlocked
    signal dismissed                      // só no modo prévia (Esc)

    readonly property color primary: failed ? "#ff5a5a" : theme.primary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property string home: Quickshell.env("HOME")

    // ── estado ──
    property var roster: []               // [{key, color}]
    property int index: 0
    property var entered: []              // índices travados
    property int attempts: 0
    property bool passwordMode: false
    property bool failed: false
    property bool busy: false
    property var seq: null                // {salt, hash, length} de lockseq.json
    readonly property bool hasSeq: seq !== null && seq.length > 0
    readonly property bool seqAllowed: hasSeq && attempts < 3

    function sound(n) { Quickshell.execDetached(["pw-play", Qt.resolvedUrl("../assets/sounds/" + n + ".wav").toString().replace("file://", "").replace(/%20/g, " ")]) }
    function reset() { entered = []; failed = false; passwordMode = !seqAllowed; pass.text = ""; focusInput() }
    function focusInput() { if (passwordMode) pass.forceActiveFocus(); else keys.forceActiveFocus() }

    FileView {
        path: face.home + "/.local/state/azmuth/lockseq.json"
        onLoaded: { try { face.seq = JSON.parse(text()) } catch (e) { face.seq = null }; face.reset() }
        onLoadFailed: { face.seq = null; face.reset() }
    }
    Process {
        running: true
        command: [face.home + "/.local/bin/azmuth", "roster"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    face.roster = JSON.parse(this.text).map(e => ({ key: e.key === null ? "N" : String(e.key), color: e.color || "#5b6470" }))
                } catch (e) {}
            }
        }
    }

    function rotate(d) {
        if (passwordMode || busy || !roster.length) return
        index = (index + d + roster.length) % roster.length
        failed = false
        sound("tick")
    }
    function lockIn() {
        if (passwordMode || busy || !roster.length) return
        entered = entered.concat([roster[index].key])
        sound("beep")
        if (entered.length >= seq.length) check()
    }
    function check() {
        const ok = Qt.md5(seq.salt + ":" + entered.join(",")) === seq.hash
        if (ok) return success()
        attempts++
        fail()
        entered = []
        if (!seqAllowed) passwordMode = true
        focusInput()
    }
    function success() {
        busy = true
        sound("transform")
        flash.restart()
        unlockLater.restart()
    }
    function fail() {
        failed = true
        sound("error")
        shake.restart()
    }
    Timer { id: unlockLater; interval: 650; onTriggered: { face.busy = false; face.unlocked() } }

    // ── senha (PAM) ──
    PamContext {
        id: pam
        config: "hyprlock"
        onPamMessage: { if (pam.responseRequired) pam.respond(pass.text) }
        onCompleted: result => {
            face.busy = false
            if (result === PamResult.Success) { face.success() }
            else { pass.text = ""; face.fail() }
        }
        onError: { face.busy = false; face.fail() }
    }
    function submitPassword() {
        if (busy || !pass.text) return
        if (preview) { fail(); return }   // a prévia nunca autentica
        busy = true
        pam.start()
    }

    // ───────────────────────── visual ─────────────────────────
    Rectangle { anchors.fill: parent; color: face.bg }
    Image {
        id: wall
        anchors.fill: parent
        source: face.theme.wallpaper ? "file://" + face.theme.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: true; blur: 1.0; blurMax: 64
        brightness: -0.55
    }

    Item {   // teclado
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const k = event.key
            if (k === Qt.Key_Tab && face.hasSeq && face.attempts < 3) { face.passwordMode = !face.passwordMode; face.entered = []; face.focusInput() }
            else if (k === Qt.Key_Escape && face.preview) face.dismissed()
            else if (k === Qt.Key_Escape) { face.entered = []; face.failed = false }
            else if (k === Qt.Key_Left || k === Qt.Key_Up) face.rotate(-1)
            else if (k === Qt.Key_Right || k === Qt.Key_Down) face.rotate(1)
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) face.lockIn()
            else if (k === Qt.Key_Backspace) face.entered = face.entered.slice(0, -1)
            else return
            event.accepted = true
        }
    }
    MouseArea {
        anchors.fill: parent
        onWheel: wheel => face.rotate(wheel.angleDelta.y < 0 ? 1 : -1)
        onClicked: face.focusInput()
    }

    // relógio
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.07
        property date now: new Date()
        Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.now = new Date() }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(parent.now, "HH:mm")
            font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: face.height * 0.09
            color: face.primary
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("pt_BR").toString(parent.now, "dddd · d 'de' MMMM").toUpperCase()
            font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: face.height * 0.022; font.letterSpacing: 3
            color: Qt.alpha(face.fg, 0.8)
        }
    }

    // disco
    Item {
        id: disc
        readonly property real size: face.height * 0.42
        width: size; height: size
        anchors.centerIn: parent
        anchors.verticalCenterOffset: face.height * 0.03
        opacity: face.passwordMode ? 0.35 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: -16; duration: 45 }
            NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: 14; duration: 70 }
            NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: -8; duration: 60 }
            NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
        }

        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: "#15181b"
            border.width: 3; border.color: Qt.alpha(face.primary, 0.55)
        }
        Shape {   // marcador do topo
            anchors.horizontalCenter: parent.horizontalCenter
            y: -disc.size * 0.035
            width: disc.size * 0.06; height: width * 0.7
            ShapePath {
                strokeWidth: 0; fillColor: face.primary
                startX: 0; startY: 0
                PathLine { x: disc.size * 0.06; y: 0 }
                PathLine { x: disc.size * 0.03; y: disc.size * 0.042 }
                PathLine { x: 0; y: 0 }
            }
        }
        Item {   // anel giratório
            id: dial
            anchors.fill: parent
            readonly property real step: face.roster.length ? 360 / face.roster.length : 36
            rotation: -face.index * step
            Behavior on rotation { RotationAnimation { direction: RotationAnimation.Shortest; duration: 240; easing.type: Easing.OutBack } }
            Repeater {
                model: face.roster
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property real a: index * dial.step * Math.PI / 180
                    readonly property bool sel: index === face.index
                    width: disc.size * 0.14; height: width; radius: width / 2
                    x: disc.size / 2 + Math.sin(a) * disc.size * 0.4 - width / 2
                    y: disc.size / 2 - Math.cos(a) * disc.size * 0.4 - height / 2
                    color: sel ? Qt.alpha(modelData.color, 0.25) : "#0d0f11"
                    border.width: sel ? 3 : 1.5
                    border.color: modelData.color
                    scale: sel ? 1.12 : 1
                    Behavior on scale { NumberAnimation { duration: 160 } }
                    Text {
                        anchors.centerIn: parent
                        rotation: -dial.rotation
                        text: parent.modelData.key
                        font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: parent.width * 0.38
                        color: parent.modelData.color
                    }
                }
            }
        }
        Rectangle {   // face com a ampulheta
            anchors.centerIn: parent
            width: disc.size * 0.56; height: width; radius: width / 2
            color: "#07090b"
            border.width: 5; border.color: face.primary
            Shape {
                id: hg
                anchors.fill: parent; anchors.margins: parent.width * 0.16
                ShapePath { strokeWidth: 0; fillColor: face.primary; startX: 0; startY: 0; PathLine { x: hg.width; y: 0 } PathLine { x: hg.width / 2; y: hg.height / 2 - 1 } PathLine { x: 0; y: 0 } }
                ShapePath { strokeWidth: 0; fillColor: face.primary; startX: 0; startY: hg.height; PathLine { x: hg.width; y: hg.height } PathLine { x: hg.width / 2; y: hg.height / 2 + 1 } PathLine { x: 0; y: hg.height } }
            }
        }
    }

    // pips da sequência (só mostra quantas posições foram travadas)
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: disc.bottom; anchors.topMargin: face.height * 0.035
        spacing: 14
        visible: face.hasSeq && !face.passwordMode
        Repeater {
            model: face.seq ? face.seq.length : 0
            Rectangle {
                required property int index
                width: 14; height: 14; radius: 7
                color: index < face.entered.length ? face.primary : "transparent"
                border.width: 2; border.color: Qt.alpha(face.primary, 0.7)
            }
        }
    }

    // senha
    Rectangle {
        id: passBox
        visible: face.passwordMode
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: disc.bottom; anchors.topMargin: face.height * 0.03
        width: face.height * 0.36; height: face.height * 0.058; radius: 6
        color: Qt.alpha(face.bg, 0.85)
        border.width: 2; border.color: face.primary
        TextInput {
            id: pass
            anchors.fill: parent; anchors.margins: 14
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignHCenter
            echoMode: TextInput.Password
            passwordCharacter: "●"
            font.family: "Rajdhani"; font.pixelSize: face.height * 0.026; font.letterSpacing: 4
            color: face.fg
            enabled: !face.busy
            Keys.onReturnPressed: face.submitPassword()
            Keys.onEnterPressed: face.submitPassword()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Tab && face.hasSeq && face.attempts < 3) { face.passwordMode = false; face.focusInput(); event.accepted = true }
                else if (event.key === Qt.Key_Escape && face.preview) { face.dismissed(); event.accepted = true }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: pass.text.length === 0
            text: face.busy ? "SEQUENCIANDO DNA..." : "SENHA"
            font.family: "Orbitron"; font.pixelSize: face.height * 0.014; font.letterSpacing: 2
            color: Qt.alpha(face.fg, 0.45)
        }
    }

    // status + dicas
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: face.height * 0.06
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: face.failed ? (face.attempts >= 3 ? "DNA REJEITADO · use a senha" : "DNA REJEITADO")
                  : (face.passwordMode ? "OMNITRIX // DNA LOCK" : "GIRE O OMNITRIX")
            font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: face.height * 0.018; font.letterSpacing: 3
            color: face.primary
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: face.passwordMode
                  ? (face.hasSeq && face.attempts < 3 ? "ENTER desbloqueia · TAB volta para a sequência" : "ENTER desbloqueia")
                  : "←/→ girar · ENTER travar posição · BACKSPACE desfazer · TAB senha"
            font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: face.height * 0.017; font.letterSpacing: 1
            color: Qt.alpha(face.fg, 0.55)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: face.preview
            text: "PRÉVIA — não autentica · ESC sai"
            font.family: "Orbitron"; font.pixelSize: face.height * 0.012
            color: "#ffd76a"
        }
    }

    // onda de energia no desbloqueio
    Rectangle {
        id: ring
        anchors.centerIn: disc
        width: 0; height: width; radius: width / 2
        color: Qt.alpha(face.theme.primary, 0.35)
        border.width: 18; border.color: face.theme.primary
        opacity: 0
    }
    ParallelAnimation {
        id: flash
        NumberAnimation { target: ring; property: "width"; from: 40; to: Math.hypot(face.width, face.height) * 1.2; duration: 650; easing.type: Easing.OutCubic }
        NumberAnimation { target: ring; property: "opacity"; from: 0.95; to: 0; duration: 650; easing.type: Easing.InQuad }
    }
}
