// Project Azmuth — notificações (substitui o dunst).
// Popups saem de baixo da cápsula do Omnitrix na barra. Clique no corpo = ação
// padrão do app (abre/foca), × fecha, botões de ação quando o app oferece.
// Tudo fica no histórico (Dashboard) até ser dispensado. "Não perturbe" no painel.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

Scope {
    id: ns

    required property var theme
    property var screen: null
    readonly property color primary: theme.primary
    readonly property color bg: theme.background
    readonly property color fg: theme.foreground
    readonly property bool dnd: theme.dnd === true
    readonly property alias server: server

    property var popups: []          // notificações visíveis agora (mais nova primeiro)

    function iconFor(n) {
        if (n.image) return n.image
        if (n.appIcon) return n.appIcon.startsWith("/") || n.appIcon.startsWith("file:") ? n.appIcon : Quickshell.iconPath(n.appIcon, true)
        const e = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : DesktopEntries.heuristicLookup(n.appName)
        return e ? Quickshell.iconPath(e.icon, true) : ""
    }
    function hide(n) { popups = popups.filter(p => p !== n) }
    function activate(n) {
        const def = n.actions.find(a => a.identifier === "default")
        if (def) def.invoke()
        else {
            const e = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : DesktopEntries.heuristicLookup(n.appName)
            if (e) e.execute()
        }
        hide(n)
        if (n.tracked && !n.resident) n.dismiss()
    }
    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss()
        popups = []
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        inlineReplySupported: false

        onNotification: n => {
            n.tracked = true                       // entra no histórico
            if (ns.dnd && n.urgency !== NotificationUrgency.Critical) return
            ns.popups = [n].concat(ns.popups.filter(p => p !== n)).slice(0, 4)
            n.closed.connect(() => ns.hide(n))
        }
    }

    PanelWindow {
        id: win
        screen: ns.screen
        visible: ns.popups.length > 0
        anchors { top: true }
        margins.top: 78                            // logo abaixo da cápsula da barra
        implicitWidth: 440
        implicitHeight: Math.max(1, col.implicitHeight + 8)
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "azmuth-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Column {
            id: col
            width: parent.width
            spacing: 8

            Repeater {
                model: ns.popups
                Item {
                    id: card
                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool critical: n.urgency === NotificationUrgency.Critical
                    readonly property color tint: critical ? "#ff5a5a" : ns.primary
                    readonly property int timeout: critical ? 0 : (n.expireTimeout > 0 ? n.expireTimeout : 6500)
                    property real remain: 1
                    width: col.width
                    height: body.implicitHeight + 28

                    // entrada: desliza para baixo saindo da cápsula
                    opacity: 0
                    transform: Translate { id: slide; y: -30 }
                    Component.onCompleted: enter.start()
                    ParallelAnimation {
                        id: enter
                        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 220 }
                        NumberAnimation { target: slide; property: "y"; to: 0; duration: 320; easing.type: Easing.OutBack }
                    }

                    NumberAnimation on remain {   // tempo restante (pausa com o mouse em cima)
                        id: life
                        running: card.timeout > 0 && !hover.containsMouse
                        from: card.remain; to: 0
                        duration: card.timeout * card.remain
                        onFinished: if (card.remain <= 0.001) ns.hide(card.n)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: Qt.alpha(ns.bg, 0.96)
                        border.width: 1.5
                        border.color: Qt.alpha(card.tint, hover.containsMouse ? 0.9 : 0.5)
                        // filete galvânico + barra de tempo
                        Rectangle { x: 0; y: 14; width: 3; height: 26; radius: 1.5; color: card.tint }
                        Rectangle {
                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 1
                            height: 2; radius: 1
                            width: (parent.width - 2) * card.remain
                            color: Qt.alpha(card.tint, 0.7)
                            visible: card.timeout > 0
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) ns.activate(card.n)
                            else { ns.hide(card.n); card.n.dismiss() }   // botão do meio/direito: dispensa
                        }
                    }

                    Row {
                        id: body
                        x: 16; y: 14
                        width: parent.width - 32
                        spacing: 12

                        Item {
                            width: 44; height: 44
                            visible: icon.source != ""
                            ClippingRectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "transparent"
                                IconImage { id: icon; anchors.fill: parent; source: ns.iconFor(card.n); asynchronous: true }
                            }
                        }

                        Column {
                            width: parent.width - (icon.source != "" ? 56 : 0)
                            spacing: 3
                            Item {
                                width: parent.width; height: appName.implicitHeight
                                Text {
                                    id: appName
                                    text: (card.n.appName || "Sistema").toUpperCase()
                                    font.family: "Orbitron"; font.pixelSize: 9; font.weight: Font.Bold; font.letterSpacing: 1.5
                                    color: card.tint
                                }
                                Text {   // fechar
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    text: ""
                                    font.family: "Font Awesome 7 Free"; font.styleName: "Solid"; font.pixelSize: 12
                                    color: x_.containsMouse ? "#ff5a5a" : Qt.alpha(ns.fg, 0.5)
                                    MouseArea {
                                        id: x_
                                        anchors.fill: parent; anchors.margins: -8
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { ns.hide(card.n); card.n.dismiss() }
                                    }
                                }
                            }
                            Text {
                                width: parent.width
                                text: card.n.summary
                                elide: Text.ElideRight
                                font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17
                                color: ns.fg
                            }
                            Text {
                                width: parent.width
                                visible: text !== ""
                                text: card.n.body
                                textFormat: Text.StyledText
                                wrapMode: Text.Wrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                font.family: "Rajdhani"; font.weight: Font.Medium; font.pixelSize: 15
                                color: Qt.alpha(ns.fg, 0.75)
                                linkColor: ns.primary
                                onLinkActivated: link => Qt.openUrlExternally(link)
                            }
                            Flow {   // ações oferecidas pelo app (fora a padrão, que é o clique)
                                width: parent.width
                                spacing: 6
                                topPadding: 4
                                visible: card.n.actions.some(a => a.identifier !== "default")
                                Repeater {
                                    model: card.n.actions.filter(a => a.identifier !== "default")
                                    Rectangle {
                                        required property var modelData
                                        height: 26; width: at.implicitWidth + 22; radius: 13
                                        color: am.containsMouse ? card.tint : "transparent"
                                        border.width: 1; border.color: card.tint
                                        Text {
                                            id: at
                                            anchors.centerIn: parent
                                            text: parent.modelData.text
                                            font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 14
                                            color: am.containsMouse ? ns.bg : card.tint
                                        }
                                        MouseArea {
                                            id: am
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { parent.modelData.invoke(); ns.hide(card.n) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
