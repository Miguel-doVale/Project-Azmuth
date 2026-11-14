// Project Azmuth — música no painel da ilha: widget quadrado de celular (capa de fundo, nome,
// artista, tempo arrastável, anterior · play/pause · próximo). Fonte: MPRIS.
import QtQuick
import Quickshell.Services.Mpris
import Quickshell
import Quickshell.Widgets

ClippingRectangle {   // recorta a capa nos cantos arredondados
    id: card
    property color primary: Colors.primary
    property color fg: Colors.fg
    property bool active: true
    // o que está tocando; senão o Spotify; senão o primeiro player
    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.find(p => p.isPlaying) || players.find(p => (p.identity || "").toLowerCase().includes("spotify")) || players[0] || null
    readonly property bool hasLength: player !== null && player.lengthSupported && player.length > 0
    property real dragPos: -1

    radius: 16
    color: "#0e7490"
    border.width: 1; border.color: Qt.alpha(primary, 0.18)

    signal opened()
    // clique no quadrado (fora dos controles) abre o player — Spotify, Chrome com o YouTube…
    MouseArea {
        anchors.fill: parent; z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (card.player && card.player.canRaise) card.player.raise()
            else Quickshell.execDetached(["gtk-launch", "spotify"])
            card.opened()
        }
    }
    function fmt(s) { s = Math.max(0, Math.floor(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }

    // posição do MPRIS só atualiza quando pedida
    Timer { interval: 1000; repeat: true; running: card.active && card.player !== null && card.player.isPlaying; onTriggered: card.player.positionChanged() }

    Image {
        id: cover
        anchors.fill: parent
        source: card.player ? card.player.trackArtUrl : ""
        fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
        visible: status === Image.Ready
    }
    Rectangle {   // sem capa: degradê do Spotify
        anchors.fill: parent; visible: !cover.visible
        gradient: Gradient {
            GradientStop { position: 0; color: "#1db954" }
            GradientStop { position: 0.55; color: "#0e7490" }
            GradientStop { position: 1; color: "#0b0f19" }
        }
    }
    Rectangle {   // escurece embaixo para o texto
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.25; color: "transparent" }
            GradientStop { position: 0.8; color: Qt.alpha("#0b0f19", 0.93) }
        }
    }

    Text {
        x: 11; y: 9
        text: "♪ " + (card.player ? (card.player.identity || "PLAYER").toUpperCase() : "MÚSICA")
        font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 9; font.letterSpacing: 1.5; color: Qt.alpha("white", 0.85)
    }

    Text {
        visible: card.player === null
        anchors.centerIn: parent
        text: "nada tocando"; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14; color: Qt.alpha("white", 0.6)
    }

    Column {
        visible: card.player !== null
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: 11
        spacing: 4
        Text { width: parent.width; elide: Text.ElideRight; text: card.player ? (card.player.trackTitle || "Sem título") : ""
               font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 14; color: "white" }
        Text { width: parent.width; elide: Text.ElideRight; text: card.player ? (card.player.trackArtist || "") : ""
               font.family: "Rajdhani"; font.weight: Font.Medium; font.pixelSize: 12; color: Qt.alpha("white", 0.7) }

        Row {   // tempo: clicar ou arrastar pula
            visible: card.hasLength
            width: parent.width; spacing: 6
            readonly property real pos: card.dragPos >= 0 ? card.dragPos : (card.player ? card.player.position : 0)
            Text { anchors.verticalCenter: parent.verticalCenter; text: card.fmt(parent.pos); font.family: "Rajdhani"; font.pixelSize: 10; color: Qt.alpha("white", 0.85) }
            Item {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 70; height: 14
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: seek.containsMouse || seek.pressed ? 6 : 3; radius: 3; color: Qt.alpha("white", 0.2) }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; height: seek.containsMouse || seek.pressed ? 6 : 3; radius: 3; color: "white"
                            width: card.hasLength ? parent.width * Math.min(1, track.parent.pos / card.player.length) : 0 }
                MouseArea {
                    id: seek
                    anchors.fill: parent; anchors.margins: -6; hoverEnabled: true
                    enabled: card.player !== null && card.player.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    function at(mx) { return Math.max(0, Math.min(1, (mx - 6) / track.width)) * card.player.length }
                    onPressed: mouse => card.dragPos = at(mouse.x)
                    onPositionChanged: mouse => { if (pressed) card.dragPos = at(mouse.x) }
                    onReleased: { if (card.dragPos >= 0) card.player.position = card.dragPos; card.dragPos = -1 }
                }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: card.hasLength ? card.fmt(card.player.length) : ""; font.family: "Rajdhani"; font.pixelSize: 10; color: Qt.alpha("white", 0.85) }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            Text { anchors.verticalCenter: parent.verticalCenter; text: "⏮"; font.pixelSize: 13; color: Qt.alpha("white", card.player && card.player.canGoPrevious ? 0.9 : 0.3)
                   MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: if (card.player && card.player.canGoPrevious) card.player.previous() } }
            Rectangle {
                width: 32; height: 32; radius: 16; color: "white"
                Text { anchors.centerIn: parent; text: card.player && card.player.isPlaying ? "❚❚" : "▶"; font.pixelSize: 12; color: "#0b0f19" }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (card.player && card.player.canTogglePlaying) card.player.togglePlaying() }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "⏭"; font.pixelSize: 13; color: Qt.alpha("white", card.player && card.player.canGoNext ? 0.9 : 0.3)
                   MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: if (card.player && card.player.canGoNext) card.player.next() } }
        }
    }
}
