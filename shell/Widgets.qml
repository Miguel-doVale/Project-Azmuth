// Project Azmuth — widgets da área de trabalho (abaixo das janelas, acima do wallpaper).
// Relógio, card do DNA ativo e player de música (qualquer player MPRIS).

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris

PanelWindow {
    id: desk

    required property var theme
    required property ShellScreen modelData
    screen: modelData

    readonly property color primary: theme.primary
    readonly property color secondary: theme.secondary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"

    anchors { top: true; left: true; bottom: true }
    implicitWidth: 480
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "azmuth-widgets"
    // só os cards recebem clique; o resto da coluna deixa passar para a área de trabalho
    mask: Region {
        Region { item: clockBox }
        Region { item: dnaCard }
        Region { item: player }
    }

    component Glow: MultiEffect {
        shadowEnabled: true
        shadowColor: desk.primary
        shadowBlur: 0.9
        shadowOpacity: 0.55
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
    }

    component Card: Rectangle {
        radius: 10
        color: Qt.alpha(desk.bg, 0.72)
        border.width: 1
        border.color: Qt.alpha(desk.primary, 0.4)
        Behavior on border.color { ColorAnimation { duration: 400 } }
        // canto "galvânico": filete na cor do DNA
        Rectangle {
            x: 0; y: 14
            width: 3; height: 28; radius: 1.5
            color: desk.primary
        }
    }

    component IconButton: Text {
        id: ib
        signal clicked
        font.family: "Font Awesome 7 Free"; font.styleName: "Solid"
        color: ibMouse.containsMouse ? desk.primary : desk.fg
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: ibMouse
            anchors.fill: parent
            anchors.margins: -8
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ib.clicked()
        }
    }

    Column {
        x: 44
        y: 70
        spacing: 22

        // ───────────────────────── relógio ─────────────────────────
        Item {
            id: clockBox
            width: 400
            height: clockCol.implicitHeight
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clockBox.now = new Date() }

            Column {
                id: clockCol
                spacing: 2
                Text {
                    id: time
                    text: Qt.formatTime(clockBox.now, "HH:mm")
                    font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 96
                    color: desk.primary
                    Behavior on color { ColorAnimation { duration: 400 } }
                    layer.enabled: true
                    layer.effect: Glow {}
                }
                // segundos: filete que enche em 60 s
                Rectangle {
                    width: time.width; height: 3; radius: 1.5
                    color: Qt.alpha(desk.primary, 0.15)
                    Rectangle {
                        width: parent.width * clockBox.now.getSeconds() / 59
                        height: parent.height; radius: 1.5
                        color: desk.primary
                        Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    topPadding: 8
                    text: Qt.locale("pt_BR").toString(clockBox.now, "dddd, d 'de' MMMM")
                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 26
                    color: desk.fg
                }
            }
        }

        // ───────────────────────── DNA ativo ─────────────────────────
        Card {
            id: dnaCard
            width: 400; height: 118

            Rectangle {   // mini Omnitrix
                id: badge
                x: 20; anchors.verticalCenter: parent.verticalCenter
                width: 64; height: 64; radius: 32
                color: "#101316"
                border.width: 3
                border.color: desk.primary
                Shape {
                    id: g
                    anchors.fill: parent
                    anchors.margins: 15
                    ShapePath {
                        strokeWidth: 0; fillColor: desk.primary
                        startX: 0; startY: 0
                        PathLine { x: g.width; y: 0 }
                        PathLine { x: g.width / 2; y: g.height / 2 - 1 }
                        PathLine { x: 0; y: 0 }
                    }
                    ShapePath {
                        strokeWidth: 0; fillColor: desk.primary
                        startX: 0; startY: g.height
                        PathLine { x: g.width; y: g.height }
                        PathLine { x: g.width / 2; y: g.height / 2 + 1 }
                        PathLine { x: 0; y: g.height }
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached([desk.az, "hud", "toggle"])
                }
            }

            Column {
                anchors.left: badge.right; anchors.leftMargin: 18
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    text: "DNA ATIVO"
                    font.family: "Orbitron"; font.pixelSize: 10; font.letterSpacing: 2
                    color: Qt.alpha(desk.fg, 0.55)
                }
                Text {
                    text: (desk.theme.name || "").toUpperCase()
                    font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 22
                    color: desk.primary
                }
                Text {
                    width: parent.width
                    text: desk.theme.description || ""
                    elide: Text.ElideRight
                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15
                    color: desk.fg
                }
                Row {
                    topPadding: 4
                    spacing: 8
                    Rectangle {   // Master Control on/off
                        height: 22; width: mcText.implicitWidth + 18; radius: 11
                        color: desk.theme.master ? desk.primary : "transparent"
                        border.width: 1; border.color: desk.primary
                        Text {
                            id: mcText
                            anchors.centerIn: parent
                            text: "MASTER " + (desk.theme.master ? "ON" : "OFF")
                            font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold
                            color: desk.theme.master ? desk.bg : desk.primary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([desk.az, "master", "toggle"])
                        }
                    }
                    Rectangle {   // Randomizer
                        height: 22; width: rnText.implicitWidth + 18; radius: 11
                        color: "transparent"
                        border.width: 1; border.color: Qt.alpha(desk.primary, 0.5)
                        Text {
                            id: rnText
                            anchors.centerIn: parent
                            text: "RANDOMIZER"
                            font.family: "Orbitron"; font.pixelSize: 10; font.weight: Font.Bold
                            color: desk.primary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([desk.az, "random"])
                        }
                    }
                }
            }
        }

        // ───────────────────────── player de música ─────────────────────────
        Card {
            id: player
            readonly property var p: {
                const ps = Mpris.players.values
                return ps.find(x => x.isPlaying) || ps[0] || null
            }
            visible: p !== null
            width: 400; height: 132

            Timer {   // a posição do MPRIS não se atualiza sozinha
                interval: 1000; repeat: true
                running: player.p !== null && player.p.isPlaying
                onTriggered: player.p.positionChanged()
            }

            ClippingRectangle {
                id: art
                x: 18; anchors.verticalCenter: parent.verticalCenter
                width: 96; height: 96; radius: 8
                color: Qt.alpha(desk.primary, 0.12)
                Image {
                    anchors.fill: parent
                    source: player.p ? player.p.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !player.p || !player.p.trackArtUrl
                    text: ""
                    font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 30
                    color: desk.primary
                }
            }

            Column {
                anchors.left: art.right; anchors.leftMargin: 16
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    width: parent.width
                    text: player.p ? (player.p.trackTitle || player.p.identity) : ""
                    elide: Text.ElideRight
                    font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 18
                    color: desk.fg
                }
                Text {
                    width: parent.width
                    text: player.p ? (player.p.trackArtist || player.p.identity) : ""
                    elide: Text.ElideRight
                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15
                    color: Qt.alpha(desk.fg, 0.6)
                }
                Rectangle {   // progresso (clique para buscar)
                    width: parent.width; height: 4; radius: 2
                    color: Qt.alpha(desk.primary, 0.18)
                    visible: player.p && player.p.lengthSupported && player.p.length > 0
                    Rectangle {
                        height: parent.height; radius: 2
                        color: desk.primary
                        width: player.p && player.p.length > 0 ? parent.width * Math.min(1, player.p.position / player.p.length) : 0
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        enabled: player.p && player.p.canSeek
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => player.p.position = player.p.length * mouse.x / width
                    }
                }
                Row {
                    topPadding: 6
                    spacing: 26
                    IconButton {
                        text: ""; font.pixelSize: 16
                        onClicked: if (player.p && player.p.canGoPrevious) player.p.previous()
                    }
                    IconButton {
                        text: player.p && player.p.isPlaying ? "" : ""; font.pixelSize: 18
                        color: desk.primary
                        onClicked: if (player.p && player.p.canTogglePlaying) player.p.togglePlaying()
                    }
                    IconButton {
                        text: ""; font.pixelSize: 16
                        onClicked: if (player.p && player.p.canGoNext) player.p.next()
                    }
                }
            }
        }
    }
}
