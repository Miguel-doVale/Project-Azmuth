// Project Azmuth — "2º plano" no rodapé do painel: ícones da bandeja (Claude, Docker…).
// Clique abre o menu do app ("Show App", "Quit"…), para baixo, desenhado no estilo do Azmuth — não o menu
// branco padrão do Qt: os itens vêm do próprio app (DBusMenu) via QsMenuOpener. Apps sem menu
// são abertos com o clique. EasyEffects e nm-applet ficam escondidos: o Azmuth já cobre.
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

Rectangle {
    id: strip
    property color primary: Colors.primary
    property color fg: Colors.fg
    property var hidden: ["easyeffects", "nm-applet", "nm_applet"]
    property var openItem: null              // app com o menu aberto
    property Item openSlot: null
    readonly property bool menuOpen: openItem !== null
    property int menusOpen: 0                // compatibilidade (a ilha zera ao fechar)
    onMenusOpenChanged: if (menusOpen === 0) close()
    readonly property var items: SystemTray.items.values.filter(i => !hidden.some(h => (i.id || "").toLowerCase().includes(h)))

    function close() { openItem = null; openSlot = null }
    function toggle(item, slot) {
        if (openItem === item) { close(); return }
        openItem = item; openSlot = slot
    }
    function openMenu(index) {
        const slot = row.children[index + 1]   // [0] é o rótulo
        if (slot && slot.modelData) toggle(slot.modelData, slot)
    }

    visible: items.length > 0
    width: visible ? row.width + 20 : 0; height: 40; radius: 13
    color: "#131c2e"; border.width: 1; border.color: Qt.alpha(primary, menuOpen ? 0.6 : 0.18)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7
        Text { anchors.verticalCenter: parent.verticalCenter; text: "2º plano"; font.family: "Rajdhani"; font.pixelSize: 10; color: Qt.alpha(strip.fg, 0.5); rightPadding: 2 }
        Repeater {
            model: strip.items
            Item {
                id: slot
                required property SystemTrayItem modelData
                width: 22; height: 22
                IconImage { anchors.fill: parent; source: slot.modelData.icon; asynchronous: true }
                Rectangle { anchors.fill: parent; anchors.margins: -3; radius: 7; color: "transparent"
                            border.width: 1; border.color: ma.containsMouse || strip.openItem === slot.modelData ? strip.primary : "transparent" }
                MouseArea {
                    id: ma
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: {
                        if (slot.modelData.hasMenu) strip.toggle(slot.modelData, slot)
                        else slot.modelData.activate()
                    }
                }
            }
        }
    }

    // ── o menu, no estilo do painel: uma janelinha própria presa ao ícone, abrindo para baixo
    //    (dentro do painel ele seria cortado na borda) ──
    readonly property alias popup: pop
    QsMenuOpener { id: opener; menu: strip.openItem ? strip.openItem.menu : null }
    PopupWindow {
        id: pop
        anchor.item: strip.openSlot ? strip.openSlot : strip
        anchor.rect.x: -10
        anchor.rect.y: (strip.openSlot ? strip.openSlot.height : strip.height) + 12
        implicitWidth: box.width
        implicitHeight: box.height
        color: "transparent"
        visible: strip.menuOpen && opener.children.values.length > 0
        Rectangle {
            id: box
            width: Math.max(180, entries.implicitWidth + 12); height: entries.implicitHeight + 12
            radius: 12
            color: "#0e1626"; border.width: 1; border.color: Qt.alpha(strip.primary, 0.55)
            Column {
                id: entries
                x: 6; y: 6
                width: box.width - 12
                Repeater {
                    model: opener.children
                    Item {
                        id: entry
                        required property QsMenuEntry modelData
                        width: entries.width
                        height: modelData.isSeparator ? 9 : 28
                        Rectangle {   // separador
                            visible: entry.modelData.isSeparator
                            anchors.centerIn: parent; width: parent.width - 12; height: 1
                            color: Qt.alpha(strip.primary, 0.2)
                        }
                        Rectangle {
                            visible: !entry.modelData.isSeparator
                            anchors.fill: parent; radius: 8
                            color: ema.containsMouse && entry.modelData.enabled ? Qt.alpha(strip.primary, 0.14) : "transparent"
                            Row {
                                anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                IconImage {
                                    visible: (entry.modelData.icon || "") !== ""
                                    anchors.verticalCenter: parent.verticalCenter
                                    implicitSize: 14; source: entry.modelData.icon || ""
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (entry.modelData.text || "").replace(/_/g, "") + (entry.modelData.hasChildren ? "  ›" : "")
                                    font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14
                                    color: entry.modelData.enabled ? strip.fg : Qt.alpha(strip.fg, 0.35)
                                    rightPadding: 14
                                }
                            }
                            Text {   // marcado (checkbox/rádio do app)
                                visible: entry.modelData.checkState === Qt.Checked
                                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                                text: "✓"; font.pixelSize: 13; color: strip.primary
                            }
                            MouseArea {
                                id: ema
                                anchors.fill: parent; hoverEnabled: true
                                enabled: entry.modelData.enabled
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { entry.modelData.triggered(); strip.close() }
                            }
                        }
                    }
                }
            }
        }
    }
}
