// Project Azmuth — widgets da área de trabalho, montados pelo layout do usuário
// (DeskLayout.qml / desktop.json). Abaixo das janelas, acima do wallpaper. O clique passa
// direto, exceto nos calendários (clicar num dia cria um evento rápido).
// Editar: Super + Alt + E, ou Central → Área de trabalho → Editar na tela.

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: desk

    required property var theme
    property var shell: null
    required property ShellScreen modelData
    screen: modelData

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "azmuth-widgets"

    // só os widgets interativos (calendário) recebem clique
    property list<Region> clickable
    mask: Region { regions: desk.clickable }
    Component { id: regionC; Region {} }
    function rebuildMask() {
        const out = []
        for (let i = 0; i < rep.count; i++) {
            const it = rep.itemAt(i)
            if (it && it.kind === "calendario") out.push(regionC.createObject(desk, { item: it }))
        }
        clickable = out
    }

    Repeater {
        id: rep
        model: DeskLayout.editing ? [] : DeskLayout.widgets
        onItemAdded: Qt.callLater(desk.rebuildMask)
        onItemRemoved: Qt.callLater(desk.rebuildMask)
        Item {   // invólucro com o tamanho já escalado (área de clique = o que se vê)
            required property var modelData
            readonly property string kind: modelData.type
            readonly property real s: modelData.s || 1
            width: w.implicitWidth * s; height: w.implicitHeight * s
            x: desk.width * modelData.x - width / 2
            y: desk.height * modelData.y - height / 2
            DeskWidget {
                id: w
                anchors.centerIn: parent
                width: implicitWidth; height: implicitHeight
                scale: parent.s
                type: parent.modelData.type
                src: parent.modelData.src || ""
                theme: desk.theme
                onDayClicked: d => { if (desk.shell) desk.shell.quickEvent(d) }
            }
        }
    }
}
