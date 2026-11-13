// Project Azmuth — aba Bluetooth da Central (Quickshell.Bluetooth / BlueZ).
// Busca liga sozinha enquanto a aba está aberta. Parear = pair → confiar → conectar;
// códigos de confirmação chegam como notificação do agente (src/bt_agent.py).

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Item {
    id: bp
    property bool active: false            // aba visível: liga a busca
    property bool showUnnamed: false

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter !== null && adapter.enabled
    readonly property var all: Bluetooth.devices.values.slice()
    readonly property var mine: all.filter(d => d.paired || d.bonded || d.connected)
        .sort((a, b) => (b.connected - a.connected) || bp.label(a).localeCompare(bp.label(b)))
    readonly property var nearby: all.filter(d => !(d.paired || d.bonded || d.connected))
        .filter(d => bp.showUnnamed || bp.named(d))
        .sort((a, b) => bp.named(b) - bp.named(a) || bp.label(a).localeCompare(bp.label(b)))
    readonly property int hidden: all.filter(d => !(d.paired || d.bonded || d.connected) && !bp.named(d)).length
    property string failed: ""              // endereço do último pareamento que falhou

    function named(d) { return d.deviceName !== "" && d.deviceName.replace(/[-:]/g, "") !== d.address.replace(/:/g, "") }
    function label(d) { return d.name || d.deviceName || d.address }
    function scan(v) { if (adapter && adapter.enabled && adapter.discovering !== v) adapter.discovering = v }
    onActiveChanged: scan(active)
    onOnChanged: scan(active)
    Component.onDestruction: scan(false)

    // ícone (Font Awesome) a partir do tipo informado pelo BlueZ
    function icon(d) {
        const i = d.icon || ""
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0) return ""
        if (i.indexOf("audio") >= 0) return ""
        if (i.indexOf("keyboard") >= 0) return ""
        if (i.indexOf("mouse") >= 0) return ""
        if (i.indexOf("gaming") >= 0 || i.indexOf("joystick") >= 0) return ""
        if (i.indexOf("phone") >= 0) return ""
        if (i.indexOf("computer") >= 0) return ""
        if (i.indexOf("watch") >= 0) return ""
        return ""
    }
    function stateText(d) {
        if (d.pairing) return "pareando… confira as notificações"
        if (d.state === BluetoothDeviceState.Connecting) return "conectando…"
        if (d.state === BluetoothDeviceState.Disconnecting) return "desconectando…"
        if (d.connected) return "conectado" + (d.batteryAvailable ? " · bateria " + Math.round(d.battery * 100) + "%" : "")
        if (d.paired || d.bonded) return "pareado · desconectado"
        if (bp.failed === d.address) return "o pareamento falhou — coloque o dispositivo em modo de pareamento e tente de novo"
        return "disponível para parear"
    }
    function pair(d) { bp.failed = ""; d.pair() }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: Math.min(parent.width, 700)
            spacing: 8

            UiSection { text: "BLUETOOTH" }

            Text {
                visible: bp.adapter === null
                width: parent.width; wrapMode: Text.WordWrap
                text: "Nenhum adaptador Bluetooth encontrado. Confira se o serviço está ativo: systemctl status bluetooth"
                font.family: "Rajdhani"; font.pixelSize: 15; color: Colors.danger
            }
            UiToggle {
                visible: bp.adapter !== null
                label: "Bluetooth ligado"
                hint: !bp.adapter ? "" : bp.adapter.state === BluetoothAdapterState.Blocked
                      ? "Bloqueado (modo avião ou tecla de rádio)" : bp.adapter.name + " · " + bp.mine.filter(d => d.connected).length + " conectado(s)"
                checked: bp.on
                onToggled: v => { if (bp.adapter) bp.adapter.enabled = v }
            }
            UiToggle {
                visible: bp.on
                label: "Visível para outros dispositivos"
                hint: "Ligue para o celular encontrar o notebook. Desliga sozinho em " + (bp.adapter ? Math.round(bp.adapter.discoverableTimeout / 60) : 3) + " min."
                checked: bp.adapter ? bp.adapter.discoverable : false
                onToggled: v => { if (bp.adapter) { bp.adapter.pairable = v; bp.adapter.discoverable = v } }
            }

            // ── meus dispositivos ──
            UiSection { visible: bp.on; text: "MEUS DISPOSITIVOS · " + bp.mine.length }
            Text {
                visible: bp.on && bp.mine.length === 0
                text: "Nenhum dispositivo pareado ainda. Coloque o fone, mouse ou teclado em modo de pareamento e procure abaixo."
                width: parent.width; wrapMode: Text.WordWrap
                font.family: "Rajdhani"; font.pixelSize: 15; color: Qt.alpha(Colors.fg, 0.5)
            }
            Repeater {
                model: bp.on ? bp.mine : []
                DeviceRow {}
            }

            // ── por perto ──
            Item {
                visible: bp.on
                width: parent.width; height: 30
                UiSection { anchors.verticalCenter: parent.verticalCenter; topPadding: 0; text: "POR PERTO · " + bp.nearby.length }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    UiButton {
                        visible: bp.hidden > 0
                        text: bp.showUnnamed ? "OCULTAR SEM NOME" : "SEM NOME (" + bp.hidden + ")"
                        onClicked: bp.showUnnamed = !bp.showUnnamed
                    }
                    UiButton {
                        text: bp.adapter && bp.adapter.discovering ? "PROCURANDO…" : "PROCURAR"
                        glyph: "visao"; filled: bp.adapter && bp.adapter.discovering
                        onClicked: bp.scan(!(bp.adapter && bp.adapter.discovering))
                    }
                }
            }
            Text {
                visible: bp.on && bp.nearby.length === 0
                text: bp.adapter && bp.adapter.discovering ? "Procurando dispositivos… (deixe o aparelho em modo de pareamento)" : "Aperte PROCURAR para buscar dispositivos."
                font.family: "Rajdhani"; font.pixelSize: 15; color: Qt.alpha(Colors.fg, 0.5)
            }
            Repeater {
                model: bp.on ? bp.nearby : []
                DeviceRow {}
            }

            Text {
                visible: bp.on
                width: parent.width; wrapMode: Text.WordWrap; topPadding: 10
                text: "Fone ou caixa de som conectados viram uma saída na aba SOM. Códigos de pareamento aparecem como notificação com Parear / Recusar."
                font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.45)
            }
        }
    }

    component DeviceRow: Rectangle {
        id: row
        required property var modelData
        readonly property var d: modelData
        readonly property bool known: d.paired || d.bonded
        readonly property bool busy: d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting
        width: col.width; height: 58; radius: 10
        color: d.connected ? Qt.alpha(Colors.primary, 0.1) : (rm.containsMouse ? Qt.alpha(Colors.primary, 0.05) : "transparent")
        border.width: d.connected ? 1 : 0; border.color: Qt.alpha(Colors.primary, 0.45)

        // pareou: confia e conecta; pareamento acabou sem parear = falha
        property bool wasPairing: false
        Connections {
            target: row.d
            function onPairingChanged() {
                if (row.d.pairing) { row.wasPairing = true; return }
                if (row.wasPairing && !row.d.paired && !row.d.bonded) bp.failed = row.d.address
                row.wasPairing = false
            }
            function onPairedChanged() {
                if (row.d.paired) { row.d.trusted = true; row.d.connect() }
            }
        }

        MouseArea { id: rm; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }

        Rectangle {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18
            color: Qt.alpha(row.d.connected ? Colors.primary : Colors.fg, 0.08)
            Text {
                anchors.centerIn: parent
                text: bp.icon(row.d)
                font.family: text === "" ? "Font Awesome 7 Brands" : "Font Awesome 7 Free"
                font.styleName: text === "" ? "Regular" : "Solid"
                font.pixelSize: 16
                color: row.d.connected ? Colors.primary : Qt.alpha(Colors.fg, 0.75)
            }
            SequentialAnimation on opacity {
                running: row.busy; loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 500 }
                NumberAnimation { to: 1; duration: 500 }
                onRunningChanged: if (!running) parent.opacity = 1
            }
        }
        Column {
            x: 60; anchors.verticalCenter: parent.verticalCenter
            width: row.width - 60 - actions.width - 24
            Text { width: parent.width; elide: Text.ElideRight; text: bp.label(row.d); font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; color: row.d.connected ? Colors.primary : Colors.fg }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: bp.stateText(row.d)
                font.family: "Rajdhani"; font.pixelSize: 14
                color: bp.failed === row.d.address && !row.known ? Colors.danger : Qt.alpha(Colors.fg, 0.55)
            }
        }
        // bateria
        Row {
            visible: row.d.batteryAvailable
            anchors.right: actions.left; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 5; height: 14; radius: 1.5
                    color: index < Math.ceil(row.d.battery * 4) ? (row.d.battery <= 0.2 ? Colors.danger : Colors.primary) : Qt.alpha(Colors.fg, 0.15)
                }
            }
        }
        Row {
            id: actions
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            UiButton { visible: row.d.pairing; text: "CANCELAR"; tint: Colors.warn; onClicked: row.d.cancelPair() }
            UiButton { visible: row.known && !row.busy; text: "ESQUECER"; tint: Colors.danger; onClicked: row.d.forget() }
            UiButton {
                visible: !row.d.pairing
                text: row.busy ? "…" : row.d.connected ? "DESCONECTAR" : row.known ? "CONECTAR" : "PAREAR"
                filled: !row.d.connected
                tint: row.d.connected ? Colors.danger : Colors.primary
                onClicked: {
                    if (row.busy) return
                    if (row.d.connected) row.d.disconnect()
                    else if (row.known) row.d.connect()
                    else bp.pair(row.d)
                }
            }
        }
    }
}
