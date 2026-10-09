// Project Azmuth — aba Wi-Fi da Central (Quickshell.Networking / NetworkManager).
// Conecta com senha pelo D-Bus (connectWithPsk) — a senha nunca passa por linha de comando.

import QtQuick
import Quickshell
import Quickshell.Networking

Item {
    id: wp
    property bool active: false     // aba visível: liga a varredura de redes

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var nets: wifi ? wifi.networks.values.slice()
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || ((b.signalStrength || 0) - (a.signalStrength || 0))) : []
    readonly property var current: nets.find(n => n.connected) || null
    property string expanded: ""     // rede com o campo de senha aberto
    property string error: ""
    property string errorNet: ""

    onActiveChanged: if (wifi) wifi.scannerEnabled = active
    Component.onCompleted: if (wifi) wifi.scannerEnabled = active

    function secured(n) { return n.security !== undefined && String(n.security) !== "0" && n.security !== WifiSecurityType.None }
    function bars(n) { const s = n.signalStrength || 0; const v = s <= 1 ? s * 100 : s; return v > 75 ? 4 : v > 50 ? 3 : v > 25 ? 2 : 1 }
    function pct(n) { const s = n.signalStrength || 0; return Math.round(s <= 1 ? s * 100 : s) }
    function connect(n) {
        error = ""; errorNet = ""
        if (n.known || !secured(n)) { n.connect(); expanded = "" }
        else expanded = expanded === n.name ? "" : n.name
    }
    function failText(r) {
        switch (r) {
        case ConnectionFailReason.NoSecrets: return "Senha errada ou não informada"
        case ConnectionFailReason.WifiAuthTimeout: return "Tempo esgotado na autenticação — confira a senha"
        case ConnectionFailReason.WifiNetworkLost: return "A rede sumiu (sinal fraco?)"
        case ConnectionFailReason.WifiClientDisconnected: return "O roteador desconectou"
        default: return "Não foi possível conectar"
        }
    }

    // falhas de conexão de qualquer rede da lista
    Repeater {
        model: wp.nets
        Item {
            required property var modelData
            Connections {
                target: modelData
                function onConnectionFailed(reason) { wp.error = wp.failText(reason); wp.errorNet = modelData.name }
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
            width: Math.min(parent.width, 700)
            spacing: 8

            UiSection { text: "WI-FI" }
            UiToggle {
                label: "Wi-Fi ligado"
                hint: !Networking.wifiHardwareEnabled ? "Bloqueado no hardware (tecla de avião?)" : (wp.wifi ? wp.wifi.name : "Nenhuma placa Wi-Fi encontrada")
                checked: Networking.wifiEnabled
                onToggled: v => Networking.wifiEnabled = v
            }

            // rede atual
            Rectangle {
                width: parent.width; height: 76; radius: 12
                visible: wp.current !== null
                color: Qt.alpha(Colors.primary, 0.08)
                border.width: 1.5; border.color: Qt.alpha(Colors.primary, 0.6)
                Glyph { x: 18; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; name: "rede"; color: Colors.primary; stroke: 2.2 }
                Column {
                    x: 66; anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: "CONECTADO"; font.family: "Orbitron"; font.pixelSize: 10; font.letterSpacing: 2; color: Qt.alpha(Colors.fg, 0.55) }
                    Text { text: wp.current ? wp.current.name : ""; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 18; color: Colors.primary }
                    Text {
                        text: (wp.current ? "sinal " + wp.pct(wp.current) + "% · " : "")
                              + ({ [NetworkConnectivity.Full]: "internet ok", [NetworkConnectivity.Limited]: "internet limitada",
                                   [NetworkConnectivity.Portal]: "precisa fazer login (portal)", [NetworkConnectivity.None]: "sem internet" }[Networking.connectivity] || "verificando internet…")
                        font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15; color: Colors.fg
                    }
                }
                UiButton { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: "DESCONECTAR"; tint: Colors.danger; onClicked: wp.current.disconnect() }
            }

            Item {
                width: parent.width; height: 30
                UiSection { anchors.verticalCenter: parent.verticalCenter; text: "REDES DISPONÍVEIS · " + wp.nets.length; topPadding: 0 }
                UiButton { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "AVANÇADO"; glyph: "sistema"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
            }
            Text {
                visible: Networking.wifiEnabled && wp.nets.length === 0
                text: "Procurando redes…"
                font.family: "Rajdhani"; font.pixelSize: 15; color: Qt.alpha(Colors.fg, 0.5)
            }

            Repeater {
                model: wp.nets
                Rectangle {
                    id: row
                    required property var modelData
                    readonly property var n: modelData
                    readonly property bool open: wp.expanded === n.name
                    readonly property bool busy: n.stateChanging || n.state === ConnectionState.Connecting
                    width: col.width
                    height: open ? 112 : 54
                    radius: 10
                    color: n.connected ? Qt.alpha(Colors.primary, 0.1) : (rm.containsMouse || open ? Qt.alpha(Colors.primary, 0.05) : "transparent")
                    border.width: open ? 1 : 0; border.color: Qt.alpha(Colors.primary, 0.4)
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    clip: true

                    MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (!row.n.connected) wp.connect(row.n) }

                    // barras de sinal
                    Row {
                        x: 16; y: 15
                        spacing: 3
                        Repeater {
                            model: 4
                            Rectangle {
                                required property int index
                                anchors.bottom: parent.bottom
                                width: 5; height: 6 + index * 4; radius: 1.5
                                color: index < wp.bars(row.n) ? Colors.primary : Qt.alpha(Colors.fg, 0.15)
                            }
                        }
                        height: 18
                    }
                    Column {
                        x: 56; y: 9
                        width: row.width - 56 - right_.width - 20
                        Text { width: parent.width; elide: Text.ElideRight; text: row.n.name; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; color: row.n.connected ? Colors.primary : Colors.fg }
                        Text {
                            text: (row.busy ? "conectando…" : row.n.connected ? "conectado" : row.n.known ? "salva" : (wp.secured(row.n) ? "protegida" : "aberta"))
                                  + " · " + wp.pct(row.n) + "%"
                            font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.55)
                        }
                    }
                    Row {
                        id: right_
                        anchors.right: parent.right; anchors.rightMargin: 12; y: 12
                        spacing: 8
                        Glyph { visible: wp.secured(row.n); anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; name: "chave"; color: Qt.alpha(Colors.fg, 0.5); stroke: 1.5 }
                        UiButton { visible: row.n.known && !row.n.connected; text: "ESQUECER"; tint: Colors.danger; onClicked: row.n.forget() }
                        UiButton { visible: !row.n.connected; text: row.busy ? "…" : "CONECTAR"; filled: true; onClicked: wp.connect(row.n) }
                    }

                    // senha (rede nova protegida)
                    Row {
                        visible: row.open
                        x: 56; y: 60
                        spacing: 10
                        Rectangle {
                            width: row.width - 56 - 140; height: 38; radius: 8
                            color: Qt.alpha(Colors.primary, 0.06)
                            border.width: psk.activeFocus ? 2 : 1; border.color: Qt.alpha(Colors.primary, psk.activeFocus ? 0.9 : 0.35)
                            TextInput {
                                id: psk
                                anchors.fill: parent; anchors.margins: 10
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: show.checked ? TextInput.Normal : TextInput.Password
                                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; color: Colors.fg
                                selectionColor: Colors.primary
                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
                                Keys.onReturnPressed: go.clicked()
                                Keys.onEnterPressed: go.clicked()
                                Text { anchors.verticalCenter: parent.verticalCenter; visible: psk.text === ""; text: "senha da rede"; font.family: "Rajdhani"; font.pixelSize: 15; color: Qt.alpha(Colors.fg, 0.35) }
                            }
                            Text {
                                id: show
                                property bool checked: false
                                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                text: checked ? "ocultar" : "mostrar"
                                font.family: "Rajdhani"; font.pixelSize: 13; color: Colors.primary
                                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: show.checked = !show.checked }
                            }
                        }
                        UiButton {
                            id: go
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ENTRAR"; filled: true
                            onClicked: { if (psk.text.length >= 8) { wp.error = ""; row.n.connectWithPsk(psk.text); wp.expanded = "" } else { wp.error = "Senhas Wi-Fi têm pelo menos 8 caracteres"; wp.errorNet = row.n.name } }
                        }
                    }
                    Text {
                        visible: wp.error !== "" && wp.errorNet === row.n.name
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                        text: wp.error
                        font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 13; color: Colors.danger
                    }
                }
            }
        }
    }
}
