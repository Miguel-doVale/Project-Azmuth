// Project Azmuth — tela de bloqueio: desbloqueio pelo Omnitrix.
//
// O relógio fica parado (como o da área de trabalho). ← e → dão um "tranco" no
// aro, que volta ao lugar; ↑ aperta o core. A senha é a sequência de movimentos
// (ex.: ← ← → ↑ → ←). Acertou o último movimento → desbloqueia na hora (sem Enter);
// errou ao completar o tamanho da sequência → rejeita e zera. Backspace desfaz · Esc limpa.
// Tab alterna para a senha do sistema (PAM). 3 sequências erradas → só a senha.
// Configurar: `azmuth lockseq set L L R U R L ...` (L = ←, R = →, U = ↑).

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Item {
    id: face

    required property var theme
    property bool preview: false
    signal unlocked
    signal dismissed

    readonly property color primary: failed ? "#ff5a5a" : theme.primary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property bool neutral: theme.id === "neutral"
    readonly property string home: Quickshell.env("HOME")

    property var entered: []
    property int attempts: 0
    property bool passwordMode: false
    property bool failed: false
    property bool busy: false
    property string note: ""              // aviso temporário (ex.: prévia não verifica senha)
    Timer { id: noteTimer; interval: 2600; onTriggered: face.note = "" }
    property var seq: null
    readonly property bool hasSeq: seq !== null && seq.length > 0
    readonly property bool seqAllowed: hasSeq && attempts < 3

    function sound(n) { Quickshell.execDetached(["pw-play", decodeURIComponent(Qt.resolvedUrl("../assets/sounds/" + n + ".wav").toString().replace("file://", ""))]) }
    function reset() { entered = []; failed = false; passwordMode = !seqAllowed; pass.text = ""; focusInput() }
    function focusInput() { if (passwordMode) pass.forceActiveFocus(); else keys.forceActiveFocus() }

    FileView {
        path: face.home + "/.local/state/azmuth/lockseq.json"
        onLoaded: { try { face.seq = JSON.parse(text()) } catch (e) { face.seq = null }; face.reset() }
        onLoadFailed: { face.seq = null; face.reset() }
    }

    function move(token) {
        if (passwordMode || busy) return
        failed = false
        entered = entered.concat([token])
        if (token === "L") dial.nudge(-1)
        else if (token === "R") dial.nudge(1)
        else press.restart()
        sound(token === "U" ? "beep" : "tick")
        if (hasSeq && entered.length >= seq.length) check()   // sem Enter: confere ao completar
    }
    function check() {
        if (passwordMode || busy || !entered.length || !hasSeq) return
        if (Qt.md5(seq.salt + ":" + entered.join(",")) === seq.hash) return success()
        attempts++
        fail()
        entered = []
        if (!seqAllowed) passwordMode = true
        focusInput()
    }
    function success() { busy = true; sound("transform"); flash.restart(); unlockLater.restart() }
    function fail() { failed = true; sound("error"); dial.shake() }
    Timer { id: unlockLater; interval: 650; onTriggered: { face.busy = false; face.unlocked() } }

    PamContext {
        id: pam
        config: "hyprlock"
        onPamMessage: { if (pam.responseRequired) pam.respond(pass.text) }
        onCompleted: result => {
            face.busy = false
            if (result === PamResult.Success) face.success()
            else { pass.text = ""; face.fail() }
        }
        onError: { face.busy = false; face.fail() }
    }
    function submitPassword() {
        if (busy || !pass.text) return
        if (preview) {   // a prévia nunca autentica (e não gasta tentativas do faillock)
            pass.text = ""
            note = "PRÉVIA — a senha não é verificada aqui. No bloqueio real (Super+M) ela funciona."
            noteTimer.restart()
            return
        }
        busy = true
        pam.start()
    }

    // ───────────────────────── fundo ─────────────────────────
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

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            const k = event.key
            if (k === Qt.Key_Tab && face.hasSeq && face.attempts < 3) { face.passwordMode = !face.passwordMode; face.entered = []; face.focusInput() }
            else if (k === Qt.Key_Escape && face.preview) face.dismissed()
            else if (k === Qt.Key_Escape) { face.entered = []; face.failed = false }
            else if (k === Qt.Key_Left) face.move("L")
            else if (k === Qt.Key_Right) face.move("R")
            else if (k === Qt.Key_Up) face.move("U")
            else if (k === Qt.Key_Backspace) face.entered = face.entered.slice(0, -1)
            else return
            event.accepted = true
        }
    }
    MouseArea { anchors.fill: parent; onClicked: face.focusInput() }

    // relógio
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.06
        property date now: new Date()
        Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.now = new Date() }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(parent.now, "HH:mm")
            font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: face.height * 0.085
            color: face.primary
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("pt_BR").toString(parent.now, "dddd · d 'de' MMMM").toUpperCase()
            font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: face.height * 0.022; font.letterSpacing: 3
            color: Qt.alpha(face.fg, 0.8)
        }
    }

    // o Omnitrix parado
    OmnitrixDial {
        id: dial
        size: face.height * 0.44
        anchors.centerIn: parent
        anchors.verticalCenterOffset: face.height * 0.03
        showSlots: false
        accent: face.primary
        opacity: face.passwordMode ? 0.35 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }

        SequentialAnimation {   // ↑: aperta o core
            id: press
            NumberAnimation { target: dial; property: "scale"; to: 0.93; duration: 70; easing.type: Easing.OutQuad }
            NumberAnimation { target: dial; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBack }
        }

        // marcações do aro (como no Omnitrix da área de trabalho)
        Repeater {
            model: 36
            Rectangle {
                required property int index
                readonly property real a: index * 10 * Math.PI / 180
                readonly property real r: dial.size * 0.43
                parent: dial
                width: index % 3 ? 2 : 3; height: dial.size * (index % 3 ? 0.018 : 0.032); radius: 1
                color: Qt.alpha(dial.accent, index % 3 ? 0.35 : 0.8)
                x: dial.size / 2 + Math.sin(a + dial.kick * Math.PI / 180) * r - width / 2
                y: dial.size / 2 - Math.cos(a + dial.kick * Math.PI / 180) * r - height / 2
                rotation: index * 10 + dial.kick
            }
        }

        Shape {   // ampulheta (DNA)
            id: hg
            visible: !face.neutral
            anchors.fill: parent
            readonly property real f: dial.faceSize
            ShapePath {
                strokeWidth: 0; fillColor: dial.accent
                startX: hg.f * 0.22; startY: hg.f * 0.12
                PathLine { x: hg.f * 0.78; y: hg.f * 0.12 }
                PathLine { x: hg.f * 0.84; y: hg.f * 0.17 }
                PathLine { x: hg.f * 0.5; y: hg.f * 0.485 }
                PathLine { x: hg.f * 0.16; y: hg.f * 0.17 }
                PathLine { x: hg.f * 0.22; y: hg.f * 0.12 }
            }
            ShapePath {
                strokeWidth: 0; fillColor: dial.accent
                startX: hg.f * 0.22; startY: hg.f * 0.88
                PathLine { x: hg.f * 0.78; y: hg.f * 0.88 }
                PathLine { x: hg.f * 0.84; y: hg.f * 0.83 }
                PathLine { x: hg.f * 0.5; y: hg.f * 0.515 }
                PathLine { x: hg.f * 0.16; y: hg.f * 0.83 }
                PathLine { x: hg.f * 0.22; y: hg.f * 0.88 }
            }
        }
        Shape {   // core Arch (Neutral)
            id: arch
            visible: face.neutral
            anchors.centerIn: parent
            width: dial.faceSize * 0.56; height: width
            ShapePath {
                strokeWidth: 0; fillColor: dial.accent
                scale: Qt.size(arch.width / 24, arch.height / 24)
                PathSvg { path: "M11.39.605C10.376 3.092 9.764 4.72 8.635 7.132c.693.734 1.543 1.589 2.923 2.554-1.484-.61-2.496-1.224-3.252-1.86C6.86 10.842 4.596 15.138 0 23.395c3.612-2.085 6.412-3.37 9.021-3.862a6.61 6.61 0 01-.171-1.547l.003-.115c.058-2.315 1.261-4.095 2.687-3.973 1.426.12 2.534 2.096 2.478 4.409a6.52 6.52 0 01-.146 1.243c2.58.505 5.352 1.787 8.914 3.844-.702-1.293-1.33-2.459-1.929-3.57-.943-.73-1.926-1.682-3.933-2.713 1.38.359 2.367.772 3.137 1.234-6.09-11.334-6.582-12.84-8.67-17.74z" }
            }
        }
    }

    // movimentos feitos (só a quantidade — não revela o tamanho da senha)
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dial.bottom; anchors.topMargin: face.height * 0.035
        spacing: 10
        visible: face.hasSeq && !face.passwordMode
        height: 12
        Repeater {
            model: Math.min(face.entered.length, 24)
            Rectangle {
                width: 10; height: 10; radius: 5
                color: face.primary
                Component.onCompleted: { scale = 0.2; popIn.start() }
                NumberAnimation on scale { id: popIn; running: false; to: 1; duration: 200; easing.type: Easing.OutBack }
            }
        }
    }

    // senha
    Rectangle {
        visible: face.passwordMode
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dial.bottom; anchors.topMargin: face.height * 0.03
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

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: face.height * 0.06
        spacing: 6
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: face.note ? face.note
                  : face.failed ? (face.attempts >= 3 ? "DNA REJEITADO · use a senha" : "DNA REJEITADO")
                  : (face.passwordMode ? "OMNITRIX // DNA LOCK" : "ATIVE O OMNITRIX")
            font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: face.height * 0.018; font.letterSpacing: 3
            color: face.note ? "#ffd76a" : face.primary
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: face.passwordMode
                  ? (face.hasSeq && face.attempts < 3 ? "ENTER desbloqueia · TAB volta para o Omnitrix" : "ENTER desbloqueia")
                  : "← → girar · ↑ apertar · BACKSPACE desfazer · TAB senha"
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

    Rectangle {
        id: ring
        anchors.centerIn: dial
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
