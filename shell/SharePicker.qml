// Project Azmuth — seletor de compartilhamento de tela (Discord, Meet, OBS…).
// Aberto por bin/azmuth-share-picker (custom_picker_binary do xdph) via IPC `sharePicker <pedido>`.
// TELAS / JANELAS (prévias ao vivo) / ÁREA (slurp). Enter transmite · Esc cancela · 1 2 3 trocam a aba.

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

PanelWindow {
    id: sp

    property bool open: false
    property real reveal: open ? 1 : 0
    Behavior on reveal { NumberAnimation { duration: sp.open ? 260 : 140; easing.type: Easing.OutCubic } }

    property string requestPath: ""
    property var windows: []          // [{ id, class, title, address, top }]
    property var shots: ({})          // monitor → foto tirada antes de abrir (a prévia ao vivo se filmaria)
    property int tab: 0               // 0 telas · 1 janelas · 2 área
    property int sel: 0
    property bool remember: false

    readonly property var screens: Quickshell.screens
    readonly property int count: tab === 0 ? screens.length : (tab === 1 ? windows.length : 1)
    readonly property color accent: Colors.primary

    function norm(a) { return String(a || "").toLowerCase().replace(/^0x/, "").replace(/^0+/, "") }

    function show(path) {
        if (open) finish({ kind: "cancel" })   // pedido antigo ainda aberto
        requestPath = path
        reqFile.path = ""
        reqFile.path = path
    }
    function build(req) {
        Hyprland.refreshToplevels()
        const tops = Hyprland.toplevels.values
        windows = (req.windows || []).map(w => Object.assign({}, w, {
            top: tops.find(t => sp.norm(t.address) === sp.norm(w.address)) || null
        }))
        remember = req.allowToken === true
        shots = req.shots || ({})
        tab = 0; sel = 0
        open = true
        keys.forceActiveFocus()
        Quickshell.execDetached(["pw-play", decodeURIComponent(Qt.resolvedUrl("../assets/sounds/hud_open.wav").toString().replace("file://", ""))])
    }
    function finish(choice) {
        if (!requestPath) { open = false; return }
        const out = requestPath.replace(/\.request\.json$/, ".result.json")
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" > \"$2.tmp\" && mv \"$2.tmp\" \"$2\"", "sh",
                                 JSON.stringify(Object.assign({ remember: sp.remember }, choice)), out])
        requestPath = ""
        open = false
    }
    function confirm() {
        if (tab === 0 && screens[sel]) finish({ kind: "screen", output: screens[sel].name })
        else if (tab === 1 && windows[sel]) finish({ kind: "window", id: windows[sel].id })
        else if (tab === 2) finish({ kind: "region" })
    }
    function cancel() { finish({ kind: "cancel" }) }
    function setTab(t) { tab = t; sel = 0 }

    FileView {
        id: reqFile
        onLoaded: { try { sp.build(JSON.parse(text())) } catch (e) { console.warn("pedido de transmissão inválido:", e); sp.cancel() } }
    }

    visible: open || reveal > 0.01
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "azmuth-sharepicker"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle { anchors.fill: parent; color: "#000000"; opacity: 0.72 * sp.reveal; MouseArea { anchors.fill: parent; onClicked: sp.cancel() } }

    Item {
        id: keys
        focus: sp.open
        Keys.onPressed: event => {
            const k = event.key
            const cols = Math.max(1, grid.columns)
            if (k === Qt.Key_Escape) sp.cancel()
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) sp.confirm()
            else if (k === Qt.Key_1) sp.setTab(0)
            else if (k === Qt.Key_2) sp.setTab(1)
            else if (k === Qt.Key_3) sp.setTab(2)
            else if (k === Qt.Key_Tab) sp.setTab((sp.tab + 1) % 3)
            else if (k === Qt.Key_Backtab) sp.setTab((sp.tab + 2) % 3)
            else if (k === Qt.Key_Right) sp.sel = Math.min(sp.count - 1, sp.sel + 1)
            else if (k === Qt.Key_Left) sp.sel = Math.max(0, sp.sel - 1)
            else if (k === Qt.Key_Down) sp.sel = Math.min(sp.count - 1, sp.sel + cols)
            else if (k === Qt.Key_Up) sp.sel = Math.max(0, sp.sel - cols)
            else if (k === Qt.Key_L) sp.remember = !sp.remember
            else return
            event.accepted = true
        }
    }

    Item {
        id: card
        width: Math.min(parent.width - 120, 1180)
        height: Math.min(parent.height - 140, 760)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: (1 - sp.reveal) * 36
        opacity: sp.reveal
        MouseArea { anchors.fill: parent }

        Shape {   // placa chanfrada
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Qt.alpha(Colors.bg, 0.97); strokeColor: Qt.alpha(sp.accent, 0.65); strokeWidth: 1.5
                startX: 26; startY: 0
                PathLine { x: card.width - 26; y: 0 } PathLine { x: card.width; y: 26 } PathLine { x: card.width; y: card.height - 26 }
                PathLine { x: card.width - 26; y: card.height } PathLine { x: 26; y: card.height } PathLine { x: 0; y: card.height - 26 }
                PathLine { x: 0; y: 26 } PathLine { x: 26; y: 0 }
            }
        }

        // cabeçalho
        Row {
            id: head
            x: 32; y: 26
            spacing: 16
            Rectangle {
                width: 52; height: 52; radius: 26
                color: Qt.alpha(sp.accent, 0.1); border.width: 2.5; border.color: sp.accent
                Glyph { anchors.centerIn: parent; width: 26; height: 26; name: "visao"; color: sp.accent; stroke: 2.2 }
                SequentialAnimation on scale {
                    running: sp.open; loops: Animation.Infinite
                    NumberAnimation { to: 1.06; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { text: "TRANSMITIR"; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 22; font.letterSpacing: 4; color: sp.accent }
                Text { text: "Escolha o que o aplicativo vai ver. Nada é transmitido até você confirmar."; font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 16; color: Qt.alpha(Colors.fg, 0.7) }
            }
        }

        // abas
        Row {
            id: tabs
            anchors.right: parent.right; anchors.rightMargin: 32
            y: 38
            spacing: 8
            Repeater {
                model: [{ t: "TELAS", g: "midia" }, { t: "JANELAS · " + sp.windows.length, g: "portal" }, { t: "ÁREA", g: "nucleo" }]
                UiButton {
                    required property var modelData
                    required property int index
                    text: (index + 1) + "  " + modelData.t
                    glyph: modelData.g
                    filled: sp.tab === index
                    onClicked: sp.setTab(index)
                }
            }
        }

        Rectangle { id: rule; x: 32; y: 100; width: card.width - 64; height: 1; color: Qt.alpha(sp.accent, 0.25) }

        // conteúdo
        Item {
            id: body
            anchors { top: rule.bottom; topMargin: 20; left: parent.left; leftMargin: 32; right: parent.right; rightMargin: 32; bottom: foot.top; bottomMargin: 16 }

            Flickable {
                anchors.fill: parent
                visible: sp.tab < 2
                contentHeight: grid.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Grid {
                    id: grid
                    width: parent.width
                    columns: sp.tab === 0 ? 2 : 3
                    spacing: 18
                    readonly property real cellW: (width - spacing * (columns - 1)) / columns
                    Repeater {
                        model: sp.open ? (sp.tab === 0 ? sp.screens : sp.windows) : []
                        Item {
                            id: tile
                            required property var modelData
                            required property int index
                            readonly property bool picked: sp.sel === index
                            readonly property string shot: sp.tab === 0 && sp.shots[modelData.name] ? "file://" + sp.shots[modelData.name] : ""
                            readonly property var source: sp.tab === 0 ? (shot ? null : modelData) : (modelData.top && modelData.top.wayland ? modelData.top.wayland : null)
                            width: grid.cellW
                            height: width * 9 / 16 + 54

                            Rectangle {
                                id: frame
                                width: parent.width; height: parent.width * 9 / 16
                                radius: 10
                                color: Qt.alpha(Colors.fg, 0.04)
                                border.width: tile.picked ? 2.5 : 1
                                border.color: tile.picked ? sp.accent : Qt.alpha(sp.accent, tm.containsMouse ? 0.55 : 0.2)
                                clip: true
                                ScreencopyView {
                                    anchors.fill: parent; anchors.margins: frame.border.width
                                    captureSource: sp.open && tile.source ? tile.source : null
                                    live: true
                                    visible: tile.source !== null
                                }
                                Image {
                                    anchors.fill: parent; anchors.margins: frame.border.width
                                    visible: tile.shot !== ""
                                    source: tile.shot
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; cache: false
                                }
                                Column {   // janela sem prévia (outro workspace minimizado etc.)
                                    visible: tile.source === null && tile.shot === ""
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Glyph { anchors.horizontalCenter: parent.horizontalCenter; width: 40; height: 40; name: "portal"; color: Qt.alpha(sp.accent, 0.6); stroke: 2 }
                                    Text { text: "sem prévia"; font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.45) }
                                }
                                Rectangle {   // brilho na seleção
                                    anchors.fill: parent; radius: 10
                                    color: "transparent"
                                    border.width: 6; border.color: Qt.alpha(sp.accent, tile.picked ? 0.18 : 0)
                                }
                            }
                            Column {
                                anchors.top: frame.bottom; anchors.topMargin: 8
                                width: parent.width
                                spacing: 1
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: sp.tab === 0 ? tile.modelData.name : (tile.modelData.title || tile.modelData.class)
                                    font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17
                                    color: tile.picked ? sp.accent : Colors.fg
                                }
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: sp.tab === 0 ? (tile.modelData.width + " × " + tile.modelData.height + (tile.modelData.model ? " · " + tile.modelData.model : ""))
                                                       : tile.modelData.class
                                    font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.5)
                                }
                            }
                            MouseArea {
                                id: tm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: sp.sel = tile.index
                                onDoubleClicked: { sp.sel = tile.index; sp.confirm() }
                            }
                        }
                    }
                }
            }
            Text {
                visible: sp.tab === 1 && sp.windows.length === 0
                anchors.centerIn: parent
                text: "O portal não enviou nenhuma janela para compartilhar."
                font.family: "Rajdhani"; font.pixelSize: 17; color: Qt.alpha(Colors.fg, 0.5)
            }

            // área
            Column {
                visible: sp.tab === 2
                anchors.centerIn: parent
                spacing: 14
                Glyph { anchors.horizontalCenter: parent.horizontalCenter; width: 74; height: 74; name: "nucleo"; color: sp.accent; stroke: 2.4 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "TRANSMITIR UMA ÁREA"; font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 18; font.letterSpacing: 2; color: sp.accent }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 520; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: "Depois de confirmar, arraste para marcar o retângulo que o app vai ver. Esc durante a seleção cancela."
                    font.family: "Rajdhani"; font.pixelSize: 16; color: Qt.alpha(Colors.fg, 0.65)
                }
            }
        }

        // rodapé
        Item {
            id: foot
            anchors { left: parent.left; leftMargin: 32; right: parent.right; rightMargin: 32; bottom: parent.bottom; bottomMargin: 24 }
            height: 48
            UiToggle {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: 380
                label: "Lembrar esta escolha (L)"
                hint: "O app poderá voltar a transmitir isso sem perguntar"
                checked: sp.remember
                onToggled: v => sp.remember = v
            }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "←→↑↓ escolher · ENTER transmitir · ESC cancelar"
                    font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.45)
                    rightPadding: 8
                }
                UiButton { text: "CANCELAR"; onClicked: sp.cancel() }
                UiButton { text: "TRANSMITIR"; glyph: "visao"; filled: true; onClicked: sp.confirm() }
            }
        }
    }
}
