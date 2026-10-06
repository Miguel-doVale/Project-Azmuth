// Project Azmuth — tema de login do SDDM (Qt6).
// Mesma linguagem visual do Omnitrix HUD e do hyprlock: disco do Omnitrix com
// o logo do Arch no core (estado Neutral). Teste sem instalar:
//   sddm-greeter-qt6 --test-mode --theme sddm/azmuth

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: background

    readonly property color primary: config.stringValue("primary") || "#38bdf8"
    readonly property color secondary: config.stringValue("secondary") || "#89b4fa"
    readonly property color background: config.stringValue("background") || "#0b0f19"
    readonly property color foreground: config.stringValue("foreground") || "#cdd6f4"
    readonly property color danger: "#ff5a5a"
    readonly property string archPath: "M11.39.605C10.376 3.092 9.764 4.72 8.635 7.132c.693.734 1.543 1.589 2.923 2.554-1.484-.61-2.496-1.224-3.252-1.86C6.86 10.842 4.596 15.138 0 23.395c3.612-2.085 6.412-3.37 9.021-3.862a6.61 6.61 0 01-.171-1.547l.003-.115c.058-2.315 1.261-4.095 2.687-3.973 1.426.12 2.534 2.096 2.478 4.409a6.52 6.52 0 01-.146 1.243c2.58.505 5.352 1.787 8.914 3.844-.702-1.293-1.33-2.459-1.929-3.57-.943-.73-1.926-1.682-3.933-2.713 1.38.359 2.367.772 3.137 1.234-6.09-11.334-6.582-12.84-8.67-17.74z"

    property int userIndex: Math.max(0, userModel.lastIndex)
    property int sessionIndex: Math.max(0, sessionModel.lastIndex)
    property bool busy: false
    property bool failed: false
    property color accent: failed ? danger : primary
    Behavior on accent { ColorAnimation { duration: 250 } }

    function login() {
        if (busy) return
        busy = true
        failed = false
        sddm.login(root.currentUser ? root.currentUser.uname : "", password.text, sessionIndex)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false
            root.failed = true
            password.text = ""
            shake.restart()
            failTimer.restart()
        }
        function onLoginSucceeded() { wave.restart() }
    }
    Timer { id: failTimer; interval: 2200; onTriggered: root.failed = false }

    // modelos lidos por delegates invisíveis (as roles só existem dentro deles).
    // Repeater cria todos os itens mesmo invisível (ListView de tamanho 0 não cria nenhum).
    Item {
        visible: false
        Repeater {
            id: userRep
            model: userModel
            Item {
                required property string name
                required property string realName
                readonly property string uname: name
                readonly property string display: realName || name
            }
        }
        Repeater {
            id: sessionRep
            model: sessionModel
            Item {
                required property string name
                readonly property string sname: name
            }
        }
    }
    readonly property var currentUser: userRep.count ? userRep.itemAt(Math.min(userIndex, userRep.count - 1)) : null
    readonly property var currentSession: sessionRep.count ? sessionRep.itemAt(Math.min(sessionIndex, sessionRep.count - 1)) : null

    // ───────────────────────── fundo ─────────────────────────
    Image {
        id: wall
        anchors.fill: parent
        source: config.stringValue("wallpaper") || "wallpaper.png"
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 0.8
        blurMax: 48
        brightness: -0.45
        saturation: 0.1
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(root.background, 0.35) }
            GradientStop { position: 1.0; color: Qt.alpha(root.background, 0.85) }
        }
    }

    // ───────────────────────── relógio ─────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.08
        spacing: 2
        Text {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: "Orbitron"
            font.weight: Font.Black
            font.pixelSize: root.height * 0.1
            color: root.primary
            text: Qt.formatTime(new Date(), "HH:mm")
        }
        Text {
            id: date
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: "Rajdhani"
            font.weight: Font.DemiBold
            font.pixelSize: root.height * 0.026
            color: root.foreground
            text: Qt.locale("pt_BR").toString(new Date(), "dddd, d 'de' MMMM")
        }
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: {
                clock.text = Qt.formatTime(new Date(), "HH:mm")
                date.text = Qt.locale("pt_BR").toString(new Date(), "dddd, d 'de' MMMM")
            }
        }
    }

    // ───────────────────────── Omnitrix ─────────────────────────
    Item {
        id: disc
        readonly property real size: root.height * 0.27
        width: size; height: size
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.height * 0.02

        // entrada: o core gira para fora
        scale: 0.6; opacity: 0; rotation: -60
        Component.onCompleted: intro.start()
        ParallelAnimation {
            id: intro
            NumberAnimation { target: disc; property: "scale"; to: 1; duration: 700; easing.type: Easing.OutBack }
            NumberAnimation { target: disc; property: "opacity"; to: 1; duration: 400 }
            NumberAnimation { target: disc; property: "rotation"; to: 0; duration: 800; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: -16; duration: 45 }
            NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: 14; duration: 70 }
            NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: -8; duration: 60 }
            NumberAnimation { target: disc; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
        }

        Rectangle {   // halo
            anchors.centerIn: parent
            width: parent.width * 1.12; height: width; radius: width / 2
            color: "transparent"
            border.width: parent.width * 0.06
            border.color: Qt.alpha(root.accent, 0.16)
        }
        Rectangle {   // bezel
            id: bezel
            anchors.fill: parent
            radius: width / 2
            color: "#15181b"
            border.width: 3
            border.color: Qt.alpha(root.accent, 0.6)
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    readonly property real a: (45 + 90 * index) * Math.PI / 180
                    width: bezel.width * 0.1; height: bezel.width * 0.04; radius: height / 2
                    color: "#2a2f35"
                    x: bezel.width / 2 + Math.cos(a) * bezel.width * 0.455 - width / 2
                    y: bezel.height / 2 + Math.sin(a) * bezel.height * 0.455 - height / 2
                    rotation: 135 + 90 * index
                }
            }
        }
        // anel de ticks — gira enquanto autentica
        Item {
            id: ticks
            anchors.fill: parent
            RotationAnimation on rotation {
                running: root.busy
                loops: Animation.Infinite
                from: 0; to: 360; duration: 1100
            }
            Repeater {
                model: 24
                Rectangle {
                    required property int index
                    readonly property real a: index * 15 * Math.PI / 180
                    width: 3; height: disc.width * (index % 2 ? 0.03 : 0.05); radius: 1.5
                    color: Qt.alpha(root.accent, index % 2 ? 0.35 : 0.8)
                    x: disc.width / 2 + Math.sin(a) * disc.width * 0.39 - width / 2
                    y: disc.height / 2 - Math.cos(a) * disc.width * 0.39 - height / 2
                    rotation: index * 15
                }
            }
        }
        Rectangle {   // face
            id: face
            anchors.centerIn: parent
            width: parent.width * 0.64; height: width; radius: width / 2
            color: "#07090b"
            border.width: 4
            border.color: root.accent
            Shape {
                id: arch
                anchors.centerIn: parent
                width: face.width * 0.56; height: width
                ShapePath {
                    strokeWidth: 0
                    fillColor: root.accent
                    scale: Qt.size(arch.width / 24, arch.height / 24)
                    PathSvg { path: root.archPath }
                }
            }
        }
    }

    // ───────────────────────── usuário + senha ─────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: disc.bottom
        anchors.topMargin: root.height * 0.045
        spacing: root.height * 0.018

        Text {   // clique troca de usuário (se houver mais de um)
            anchors.horizontalCenter: parent.horizontalCenter
            font.family: "Orbitron"
            font.weight: Font.Bold
            font.pixelSize: root.height * 0.024
            font.letterSpacing: 3
            color: root.foreground
            text: root.currentUser ? root.currentUser.display.toUpperCase() : ""
            MouseArea {
                anchors.fill: parent
                enabled: userModel.count > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.userIndex = (root.userIndex + 1) % userModel.count
            }
        }

        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.height * 0.36; height: root.height * 0.058
            radius: 6
            color: Qt.alpha(root.background, 0.85)
            border.width: password.activeFocus ? 3 : 2
            border.color: root.accent

            TextInput {
                id: password
                anchors.fill: parent
                anchors.leftMargin: 18; anchors.rightMargin: 18
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                font.family: "Rajdhani"
                font.pixelSize: root.height * 0.026
                font.letterSpacing: 4
                color: root.foreground
                selectionColor: root.primary
                focus: true
                enabled: !root.busy
                Keys.onReturnPressed: root.login()
                Keys.onEnterPressed: root.login()
            }
            Text {
                anchors.centerIn: parent
                visible: password.text.length === 0
                text: root.failed ? "DNA REJEITADO" : (root.busy ? "SEQUENCIANDO DNA..." : "OMNITRIX // DNA LOCK")
                font.family: "Orbitron"
                font.weight: root.failed ? Font.Bold : Font.Normal
                font.pixelSize: root.height * 0.015
                font.letterSpacing: 2
                color: root.failed ? root.danger : Qt.alpha(root.foreground, 0.5)
            }
        }
    }

    // ───────────────────────── rodapé: sessão e energia ─────────────────────────
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: root.height * 0.035
        spacing: 10
        Text {
            text: ""
            font.family: "Font Awesome 7 Free"; font.styleName: "Solid"
            font.pixelSize: root.height * 0.02
            color: root.primary
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.currentSession ? root.currentSession.sname : ""
            font.family: "Rajdhani"; font.weight: Font.DemiBold
            font.pixelSize: root.height * 0.022
            color: root.foreground
            anchors.verticalCenter: parent.verticalCenter
            MouseArea {   // clique alterna entre as sessões instaladas
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.height * 0.035
        spacing: root.height * 0.02
        Repeater {
            model: [
                { icon: "", tip: "Suspender", act: () => sddm.suspend(), ok: sddm.canSuspend },
                { icon: "", tip: "Reiniciar", act: () => sddm.reboot(), ok: sddm.canReboot },
                { icon: "", tip: "Desligar", act: () => sddm.powerOff(), ok: sddm.canPowerOff }
            ]
            Rectangle {
                required property var modelData
                opacity: modelData.ok ? 1 : 0.4
                width: root.height * 0.05; height: width; radius: width / 2
                color: hover.containsMouse ? Qt.alpha(root.primary, 0.2) : Qt.alpha(root.background, 0.6)
                border.width: 1.5
                border.color: Qt.alpha(root.primary, hover.containsMouse ? 0.9 : 0.4)
                Text {
                    anchors.centerIn: parent
                    text: modelData.icon
                    font.family: "Font Awesome 7 Free"; font.styleName: "Solid"
                    font.pixelSize: parent.width * 0.38
                    color: root.primary
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.act()
                }
            }
        }
    }

    // ───────────────────── onda de energia no login aceito ─────────────────────
    Rectangle {
        id: ring
        anchors.centerIn: disc
        width: 0; height: width; radius: width / 2
        color: Qt.alpha(root.primary, 0.35)
        border.width: 18
        border.color: root.primary
        opacity: 0
    }
    ParallelAnimation {
        id: wave
        NumberAnimation { target: ring; property: "width"; from: 40; to: Math.hypot(root.width, root.height) * 1.2; duration: 650; easing.type: Easing.OutCubic }
        NumberAnimation { target: ring; property: "opacity"; from: 0.95; to: 0; duration: 650; easing.type: Easing.InQuad }
    }
}
