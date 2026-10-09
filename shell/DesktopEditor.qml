// Project Azmuth — modo edição da área de trabalho ("desktop canvas").
// Arrastar move · scroll muda o tamanho · × remove · guias puxam para o centro ·
// barra do topo adiciona widgets do catálogo · Esc ou CONCLUIR sai. Tudo salva na hora.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: ed

    required property var theme
    visible: DeskLayout.editing
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-desktop-editor"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool guideX: false
    property bool guideY: false
    readonly property real snap: 18

    // fundo: escurece e mostra uma grade fina
    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.62 }
    Canvas {
        anchors.fill: parent
        onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            ctx.strokeStyle = Qt.alpha(Colors.primary, 0.07); ctx.lineWidth = 1
            for (let x = 0; x < width; x += 40) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke() }
            for (let y = 0; y < height; y += 40) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke() }
        }
    }
    // guias de centro
    Rectangle { visible: ed.guideX; x: ed.width / 2 - 1; width: 2; height: ed.height; color: Colors.primary; opacity: 0.8 }
    Rectangle { visible: ed.guideY; y: ed.height / 2 - 1; height: 2; width: ed.width; color: Colors.primary; opacity: 0.8 }

    Item {
        anchors.fill: parent
        focus: ed.visible
        Keys.onEscapePressed: DeskLayout.editing = false
    }

    Repeater {
        model: DeskLayout.widgets
        Item {
            id: box
            required property var modelData
            readonly property real s: modelData.s || 1
            width: w.implicitWidth * s + 24
            height: w.implicitHeight * s + 24
            x: ed.width * modelData.x - width / 2
            y: ed.height * modelData.y - height / 2

            DeskWidget {
                id: w
                type: box.modelData.type
                theme: ed.theme
                width: implicitWidth; height: implicitHeight
                scale: box.s
                anchors.centerIn: parent
            }
            Shape {   // moldura tracejada
                anchors.fill: parent
                ShapePath {
                    strokeColor: drag.pressed || drag.containsMouse ? Colors.primary : Qt.alpha(Colors.primary, 0.5)
                    strokeWidth: 1.5; fillColor: Qt.alpha(Colors.primary, drag.containsMouse ? 0.06 : 0.02)
                    strokeStyle: ShapePath.DashLine; dashPattern: [4, 3]
                    startX: 0; startY: 0
                    PathLine { x: box.width; y: 0 } PathLine { x: box.width; y: box.height } PathLine { x: 0; y: box.height } PathLine { x: 0; y: 0 }
                }
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                drag.target: box
                drag.threshold: 2
                onPositionChanged: {
                    if (!pressed) return
                    const cx = box.x + box.width / 2, cy = box.y + box.height / 2
                    ed.guideX = Math.abs(cx - ed.width / 2) < ed.snap
                    ed.guideY = Math.abs(cy - ed.height / 2) < ed.snap
                    if (ed.guideX) box.x = ed.width / 2 - box.width / 2
                    if (ed.guideY) box.y = ed.height / 2 - box.height / 2
                }
                onReleased: {
                    ed.guideX = false; ed.guideY = false
                    DeskLayout.update(box.modelData.uid, {
                        x: Math.max(0.02, Math.min(0.98, (box.x + box.width / 2) / ed.width)),
                        y: Math.max(0.03, Math.min(0.97, (box.y + box.height / 2) / ed.height))
                    })
                }
                onWheel: wheel => DeskLayout.update(box.modelData.uid, { s: Math.max(0.5, Math.min(2, Math.round((box.s + (wheel.angleDelta.y > 0 ? 0.1 : -0.1)) * 10) / 10)) })
            }
            // etiqueta
            Rectangle {
                x: 0; y: -30
                height: 24; width: tag.implicitWidth + 20; radius: 12
                color: Colors.bg; border.width: 1; border.color: Colors.primary
                Row {
                    id: tag
                    anchors.centerIn: parent; spacing: 6
                    Glyph { anchors.verticalCenter: parent.verticalCenter; width: 13; height: 13; name: DeskLayout.info(box.modelData.type).glyph; color: Colors.primary; stroke: 1.5 }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: DeskLayout.info(box.modelData.type).name.toUpperCase() + " · " + Math.round(box.s * 100) + "%"; font.family: "Orbitron"; font.pixelSize: 9; font.weight: Font.Bold; color: Colors.primary }
                }
            }
            // remover
            Rectangle {
                x: box.width - 12; y: -12
                width: 26; height: 26; radius: 13
                color: xm.containsMouse ? Colors.danger : Colors.bg
                border.width: 1.5; border.color: Colors.danger
                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 13; font.bold: true; color: xm.containsMouse ? Colors.bg : Colors.danger }
                MouseArea { id: xm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: DeskLayout.remove(box.modelData.uid) }
            }
        }
    }

    // barra de ferramentas
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 60
        width: bar.implicitWidth + 36; height: 56; radius: 28
        color: Qt.alpha(Colors.bg, 0.96)
        border.width: 1.5; border.color: Qt.alpha(Colors.primary, 0.6)
        Row {
            id: bar
            anchors.centerIn: parent
            spacing: 8
            Column {
                anchors.verticalCenter: parent.verticalCenter
                rightPadding: 10
                Text { text: "MODO EDIÇÃO"; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 12; font.letterSpacing: 2; color: Colors.primary }
                Text { text: "arraste · scroll = tamanho · ✕ remove"; font.family: "Rajdhani"; font.pixelSize: 12; color: Qt.alpha(Colors.fg, 0.55) }
            }
            Repeater {
                model: DeskLayout.catalog
                UiButton {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: modelData.glyph
                    text: modelData.name.split(" ")[0].toUpperCase()
                    onClicked: DeskLayout.add(modelData.type)
                }
            }
            Rectangle { width: 1; height: 30; color: Qt.alpha(Colors.primary, 0.3); anchors.verticalCenter: parent.verticalCenter }
            UiButton { anchors.verticalCenter: parent.verticalCenter; text: "RESTAURAR"; tint: Colors.warn; onClicked: DeskLayout.reset() }
            UiButton { anchors.verticalCenter: parent.verticalCenter; text: "CONCLUIR"; filled: true; onClicked: DeskLayout.editing = false }
        }
    }
}
