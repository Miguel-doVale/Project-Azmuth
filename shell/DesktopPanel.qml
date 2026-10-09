// Project Azmuth — aba Área de trabalho da Central: widgets do "desktop canvas".
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell

Item {
    id: dp
    property var settings: null          // preferências (azmuth settings)
    signal setPref(string path, var value)
    signal editOnScreen
    property bool picking: false
    // o modo edição pede o seletor de imagem: abre e consome o pedido
    Connections {
        target: DeskLayout
        function onPickImageChanged() { if (DeskLayout.pickImage) { dp.picking = true; DeskLayout.pickImage = false } }
    }
    property string folder: Quickshell.env("HOME") + "/Pictures"
    readonly property var folders: [
        { name: "IMAGENS", path: Quickshell.env("HOME") + "/Pictures" },
        { name: "CAPTURAS", path: Quickshell.env("HOME") + "/Pictures/Screenshots" },
        { name: "DOWNLOADS", path: Quickshell.env("HOME") + "/Downloads" },
        { name: "WALLPAPERS AZMUTH", path: Quickshell.env("HOME") + "/Documents/Coding/Project Azmuth/assets/wallpapers" }
    ]

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 20
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
            id: col
            width: Math.min(parent.width, 700)
            spacing: 8

            UiSection { text: "ÁREA DE TRABALHO" }
            UiToggle {
                label: "Área de trabalho viva"
                hint: "Omnitrix animado no centro e circuitos com energia (desligado = wallpaper parado)"
                checked: dp.settings ? dp.settings.live_desktop : true
                onToggled: v => dp.setPref("live_desktop", v)
            }

            // editar na tela
            Rectangle {
                width: parent.width; height: 84; radius: 12
                color: Qt.alpha(Colors.primary, 0.08)
                border.width: 1.5; border.color: Qt.alpha(Colors.primary, 0.6)
                Glyph { x: 20; anchors.verticalCenter: parent.verticalCenter; width: 36; height: 36; name: "midia"; color: Colors.primary; stroke: 2.2 }
                Column {
                    x: 72; anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text { text: "DESKTOP CANVAS"; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 15; color: Colors.primary }
                    Text { text: "Arraste, redimensione e organize os widgets direto na tela."; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 15; color: Colors.fg }
                }
                UiButton { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; text: "EDITAR NA TELA"; glyph: "portal"; filled: true; onClicked: dp.editOnScreen() }
            }

            UiSection { text: "WIDGETS NA TELA · " + DeskLayout.widgets.length }
            Repeater {
                model: DeskLayout.widgets
                Rectangle {
                    required property var modelData
                    readonly property var info: DeskLayout.info(modelData.type)
                    width: col.width; height: 50; radius: 10
                    color: wm.containsMouse ? Qt.alpha(Colors.primary, 0.05) : "transparent"
                    MouseArea { id: wm; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    Glyph { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; name: parent.info.glyph; color: Colors.primary; stroke: 1.8 }
                    Text { x: 50; anchors.verticalCenter: parent.verticalCenter; text: parent.info.name; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 16; color: Colors.fg }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        UiButton { width: 30; text: "−"; onClicked: DeskLayout.update(parent.parent.modelData.uid, { s: Math.max(0.5, Math.round(((parent.parent.modelData.s || 1) - 0.1) * 10) / 10) }) }
                        Text { anchors.verticalCenter: parent.verticalCenter; width: 48; horizontalAlignment: Text.AlignHCenter; text: Math.round((parent.parent.modelData.s || 1) * 100) + "%"; font.family: "Orbitron"; font.pixelSize: 12; font.weight: Font.Bold; color: Colors.primary }
                        UiButton { width: 30; text: "+"; onClicked: DeskLayout.update(parent.parent.modelData.uid, { s: Math.min(2, Math.round(((parent.parent.modelData.s || 1) + 0.1) * 10) / 10) }) }
                        UiButton { width: 30; text: "✕"; tint: Colors.danger; onClicked: DeskLayout.remove(parent.parent.modelData.uid) }
                    }
                }
            }

            UiSection { text: "ADICIONAR" }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: DeskLayout.catalog
                    UiButton {
                        required property var modelData
                        glyph: modelData.glyph; text: modelData.name.toUpperCase()
                        filled: modelData.type === "imagem" && dp.picking
                        onClicked: modelData.type === "imagem" ? (dp.picking = !dp.picking) : DeskLayout.add(modelData.type)
                    }
                }
            }

            // seletor de imagem (sem depender de zenity/kdialog)
            Column {
                visible: dp.picking
                width: parent.width
                spacing: 8
                UiSection { text: "ESCOLHA UMA IMAGEM" }
                Flow {
                    width: parent.width; spacing: 6
                    Repeater {
                        model: dp.folders
                        UiButton { required property var modelData; text: modelData.name; filled: dp.folder === modelData.path; onClicked: dp.folder = modelData.path }
                    }
                }
                FolderListModel {
                    id: pics
                    folder: "file://" + dp.folder
                    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.PNG", "*.JPG"]
                    showDirs: false
                    sortField: FolderListModel.Time
                }
                Text { visible: pics.count === 0; text: "Nenhuma imagem nesta pasta."; font.family: "Rajdhani"; font.pixelSize: 15; color: Qt.alpha(Colors.fg, 0.5) }
                Grid {
                    columns: Math.max(1, Math.floor(parent.width / 132))
                    spacing: 8
                    Repeater {
                        model: pics
                        Rectangle {
                            required property string filePath
                            required property string fileName
                            width: 124; height: 96; radius: 10
                            color: Qt.alpha(Colors.primary, 0.06)
                            border.width: pm.containsMouse ? 2 : 1; border.color: pm.containsMouse ? Colors.primary : Qt.alpha(Colors.fg, 0.15)
                            clip: true
                            Image { anchors.fill: parent; anchors.margins: 4; source: "file://" + parent.filePath; sourceSize.width: 240; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                            MouseArea {
                                id: pm
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { DeskLayout.add("imagem", { src: parent.filePath }); dp.picking = false }
                            }
                        }
                    }
                }
            }
            Item { width: 1; height: 6 }
            UiButton { text: "RESTAURAR PADRÃO"; tint: Colors.warn; onClicked: DeskLayout.reset() }
            Text {
                width: parent.width; wrapMode: Text.WordWrap; topPadding: 6
                text: "Widgets novos aparecem no centro da tela; use EDITAR NA TELA para posicionar. Atalho direto: Super + Alt + E."
                font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.5)
            }
        }
    }
}
