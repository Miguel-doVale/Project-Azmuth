// Project Azmuth — widgets da área de trabalho, montados pelo layout do usuário
// (DeskLayout.qml / desktop.json). Abaixo das janelas, acima do wallpaper;
// só decoração (cliques passam). Editar: Central → Área de trabalho → Editar na tela.

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: desk

    required property var theme
    required property ShellScreen modelData
    screen: modelData

    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "azmuth-widgets"
    mask: Region {}

    Repeater {
        model: DeskLayout.editing ? [] : DeskLayout.widgets
        DeskWidget {
            required property var modelData
            type: modelData.type
            src: modelData.src || ""
            theme: desk.theme
            scale: modelData.s || 1
            x: desk.width * modelData.x - width / 2
            y: desk.height * modelData.y - height / 2
            width: implicitWidth; height: implicitHeight
        }
    }
}
