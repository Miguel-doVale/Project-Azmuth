// Project Azmuth — trava de sessão (ext-session-lock) com o desbloqueio pelo Omnitrix.
// `lock()` trava de verdade; `preview()` mostra a mesma tela numa camada comum
// (para testar o visual sem trancar a sessão — a prévia nunca autentica).

import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: lk

    required property var theme
    property var screen: null

    function lock() { if (!sessionLock.locked) sessionLock.locked = true }
    function preview() { previewWin.visible = !previewWin.visible }

    WlSessionLock {
        id: sessionLock
        WlSessionLockSurface {
            color: "#000000"
            LockFace {
                anchors.fill: parent
                theme: lk.theme
                onUnlocked: sessionLock.locked = false
            }
        }
    }

    PanelWindow {
        id: previewWin
        visible: false
        screen: lk.screen
        anchors { top: true; left: true; right: true; bottom: true }
        exclusionMode: ExclusionMode.Ignore
        color: "#000000"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "azmuth-lock-preview"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        Loader {
            anchors.fill: parent
            active: previewWin.visible
            sourceComponent: LockFace {
                theme: lk.theme
                preview: true
                onDismissed: previewWin.visible = false
                onUnlocked: previewWin.visible = false
            }
        }
    }
}
