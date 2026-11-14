// Project Azmuth — folha de atalhos (Super+F1, botão "Atalhos" do painel da ilha, `azmuth atalhos menu`).
// Os dados vêm de `azmuth atalhos --json` (src/shortcuts.py), a mesma lista do terminal.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: sheet
    required property var theme
    property bool open: false
    property var sections: []
    // mural: cada seção vai para a coluna com menos linhas (as 3 colunas terminam quase juntas)
    readonly property var columns: {
        const cols = [[], [], []], load = [0, 0, 0]
        for (const sec of sections) {
            const i = load.indexOf(Math.min(...load))
            cols[i].push(sec); load[i] += sec.items.length + 1.5
        }
        return cols
    }

    readonly property color primary: theme.primary || "#38bdf8"
    readonly property color bg: theme.background || "#0b0f19"
    readonly property color fg: theme.foreground || "#cdd6f4"

    function toggle() { open = !open; if (open) loader.running = true }

    visible: open
    anchors { top: true; bottom: true; left: true; right: true }
    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.namespace: "azmuth-shortcuts"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Process {
        id: loader
        command: [Quickshell.env("HOME") + "/.local/bin/azmuth", "atalhos", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { sheet.sections = JSON.parse(text) } catch (e) { console.warn("atalhos:", e) } } }
    }

    Rectangle {   // fundo escurecido; clique fora fecha
        anchors.fill: parent
        color: Qt.alpha("#000000", 0.55)
        MouseArea { anchors.fill: parent; onClicked: sheet.open = false }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1180)
        height: Math.min(parent.height - 80, body.implicitHeight + 92)
        radius: 26
        color: Qt.alpha(sheet.bg, 0.97)
        border.width: 1; border.color: Qt.alpha(sheet.primary, 0.45)
        MouseArea { anchors.fill: parent }   // clique dentro não fecha

        Item { focus: sheet.open; Keys.onEscapePressed: sheet.open = false; Keys.onReturnPressed: sheet.open = false }

        Row {
            x: 28; y: 22; spacing: 12
            OmnitrixMark { anchors.verticalCenter: parent.verticalCenter; size: 30; glow: false; status: false; color: sheet.primary; bg: sheet.bg }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "ATALHOS"; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 20; font.letterSpacing: 3; color: sheet.primary }
        }
        Text {
            anchors.right: parent.right; anchors.rightMargin: 28; y: 30
            text: "Esc fecha · também no terminal: azmuth atalhos"
            font.family: "Rajdhani"; font.pixelSize: 13; color: Qt.alpha(sheet.fg, 0.5)
        }

        Flickable {
            x: 24; y: 70; width: parent.width - 48; height: parent.height - 92
            contentHeight: body.implicitHeight; clip: true
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: body
                width: parent.width
                spacing: 14
                Repeater {
                    model: sheet.columns
                    Column {
                    id: colOfCards
                    required property var modelData
                    width: (body.width - 2 * 14) / 3
                    spacing: 14
                    Repeater {
                    model: colOfCards.modelData
                    Rectangle {   // uma seção por cartão
                        id: sec
                        required property var modelData
                        width: colOfCards.width
                        height: secCol.implicitHeight + 26
                        radius: 18
                        color: "#131c2e"; border.width: 1; border.color: Qt.alpha(sheet.primary, 0.16)
                        Column {
                            id: secCol
                            x: 16; y: 13; width: parent.width - 32
                            spacing: 7
                            Text { text: sec.modelData.section.toUpperCase(); font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 11; font.letterSpacing: 1.8; color: sheet.primary; bottomPadding: 3 }
                            Repeater {
                                model: sec.modelData.items
                                Row {   // teclas à esquerda, o que faz à direita (uma linha por atalho)
                                    id: line
                                    required property var modelData
                                    width: secCol.width
                                    spacing: 10
                                    // as teclas como keycaps; "·" separa alternativas, "+" junta teclas
                                    Flow {
                                        id: caps
                                        width: secCol.width * 0.5; spacing: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        Repeater {
                                            model: line.modelData.keys.split(/\s+(·)\s+|\s+\+\s+/).filter(k => k !== undefined && k !== "")
                                            Item {
                                                required property string modelData
                                                readonly property bool sep: modelData === "·"
                                                width: sep ? 10 : cap.width; height: 22
                                                Text { visible: parent.sep; anchors.centerIn: parent; text: "/"; color: Qt.alpha(sheet.fg, 0.4); font.pixelSize: 12 }
                                                Rectangle {
                                                    id: cap
                                                    visible: !parent.sep
                                                    width: capText.implicitWidth + 12; height: 21; radius: 6
                                                    color: Qt.alpha(sheet.primary, 0.1); border.width: 1; border.color: Qt.alpha(sheet.primary, 0.4)
                                                    Text { id: capText; anchors.centerIn: parent; text: parent.parent.modelData
                                                           font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 12; color: sheet.fg }
                                                }
                                            }
                                        }
                                    }
                                    Text { width: secCol.width - caps.width - 10; anchors.verticalCenter: parent.verticalCenter
                                           wrapMode: Text.WordWrap; text: line.modelData.what
                                           font.family: "Rajdhani"; font.weight: Font.Medium; font.pixelSize: 14; color: Qt.alpha(sheet.fg, 0.75) }
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
