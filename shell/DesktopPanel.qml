// Project Azmuth — aba Área de trabalho da Central: widgets do "desktop canvas".
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

Item {
    id: dp
    property var settings: null          // preferências (azmuth settings)
    property bool active: false          // aba aberta (a Central abre/fecha sem mudar a visibilidade)
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

    // ── FUNDO: galeria de cenas ASCII vivo ──
    // Estado local por cena (liga/desliga dos efeitos, cor, tempo do carrossel): as escolhas valem na hora na
    // tela e a gravação sai uma vez só, 300 ms depois do último clique (cliques rápidos não se atropelam).
    readonly property string az: Quickshell.env("HOME") + "/.local/bin/azmuth"
    property var scenes: []
    property string picked: ""                       // cena escolhida agora (antes do settings chegar)
    property var fxLocal: ({})
    property var monoLocal: ({})
    property var everyLocal: ({})
    property var pendingFx: ({})
    property bool touched: false
    readonly property var desk: settings && settings.desktop ? settings.desktop : ({})
    readonly property string activeId: picked !== "" ? picked : (desk.scene || "circuitos")
    readonly property var activeScene: scenes.find(sc => sc.id === activeId) || null
    readonly property var everyChoices: [4, 6, 9, 15, 30, 60]

    onActiveChanged: if (active) { fxLocal = ({}); monoLocal = ({}); everyLocal = ({}); picked = ""; touched = false; scenesProc.running = true }
    onSettingsChanged: if (!touched) { fxLocal = ({}); monoLocal = ({}); everyLocal = ({}); picked = "" }   // ainda não mexeu: pega o que chegou

    // o mesmo critério da LiveDesktop/AsciiScene: salvo, senão o padrão da cena
    function fxFor(sc) {
        if (!sc) return []
        if (fxLocal[sc.id]) return fxLocal[sc.id]
        const saved = (desk.effects || {})[sc.id]
        return sc.effects.map((e, k) => saved && saved[k] !== undefined ? !!saved[k] : e.on)
    }
    function monoFor(sc) {
        if (!sc) return false
        if (monoLocal[sc.id] !== undefined) return monoLocal[sc.id]
        const saved = (desk.color || {})[sc.id]
        return saved !== undefined ? saved === "dna" : !!sc.mono
    }
    function everyFor(sc) {
        if (!sc) return 6
        if (everyLocal[sc.id] !== undefined) return everyLocal[sc.id]
        return (desk.every || {})[sc.id] || sc.every || 6
    }
    function pick(id) { touched = true; picked = id; setPref("desktop.scene", id) }
    function setEffect(sc, k, v) {
        const list = fxFor(sc).slice(); list[k] = v
        const l = Object.assign({}, fxLocal); l[sc.id] = list; fxLocal = l
        const q = Object.assign({}, pendingFx); q[sc.id] = list; pendingFx = q
        touched = true; writeTimer.restart()
    }
    function setMono(sc, v) {
        const m = Object.assign({}, monoLocal); m[sc.id] = v; monoLocal = m
        touched = true; setPref("desktop.color." + sc.id, v ? "dna" : "foto")
    }
    function setEvery(sc, n) {
        const m = Object.assign({}, everyLocal); m[sc.id] = n; everyLocal = m
        touched = true; setPref("desktop.every." + sc.id, n)
    }
    Timer {
        id: writeTimer
        interval: 300
        onTriggered: { for (const id in dp.pendingFx) dp.setPref("desktop.effects." + id, dp.pendingFx[id]); dp.pendingFx = ({}) }
    }
    Process {
        id: scenesProc
        command: [dp.az, "fundo", "--json"]
        stdout: StdioCollector { onStreamFinished: { try { dp.scenes = JSON.parse(text) } catch (e) { console.warn("fundo:", e) } } }
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

            UiSection { text: "ÁREA DE TRABALHO" }
            UiToggle {
                label: "Área de trabalho viva"
                hint: "Omnitrix animado no centro e circuitos com energia (desligado = wallpaper parado)"
                checked: dp.settings ? dp.settings.live_desktop : true
                onToggled: v => dp.setPref("live_desktop", v)
            }
            UiToggle {
                label: "Ilha solta"
                hint: "A ilha do Omnitrix flutua a alguns pixels do topo (desligado = colada no teto da tela)"
                checked: dp.settings && dp.settings.island ? dp.settings.island.detached : true
                onToggled: v => dp.setPref("island.detached", v)
            }

            // ───────────── FUNDO ─────────────
            UiSection { text: "FUNDO" }
            Text {
                visible: dp.scenes.length === 0
                text: "Carregando as cenas…"
                font.family: "Rajdhani"; font.pixelSize: 15; color: Qt.alpha(Colors.fg, 0.5)
            }
            Column {   // a cena de agora: efeitos, cor e (no carrossel) o tempo
                visible: dp.activeScene !== null
                width: parent.width
                spacing: 2
                Text {
                    text: dp.activeScene ? dp.activeScene.title.toUpperCase() : ""
                    font.family: "Orbitron"; font.weight: Font.Black; font.pixelSize: 13; color: Colors.primary
                    bottomPadding: 4
                }
                Text {
                    visible: dp.activeScene !== null && dp.activeScene.id === "circuitos"
                    width: parent.width; wrapMode: Text.WordWrap
                    text: "O fundo original: circuitos com energia correndo. Escolha uma cena abaixo para trocar."
                    font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.55)
                }
                Flow {   // efeitos e cor: pílulas acesas = ligadas
                    visible: dp.activeScene !== null && dp.activeScene.id !== "circuitos"
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: dp.activeScene ? dp.activeScene.effects : []
                        UiButton {
                            required property var modelData
                            required property int index
                            text: modelData.nome.toUpperCase()
                            filled: dp.fxFor(dp.activeScene)[index] === true
                            onClicked: dp.setEffect(dp.activeScene, index, !filled)
                        }
                    }
                    UiButton {
                        text: dp.monoFor(dp.activeScene) ? "BRANCO + COR DO DNA" : "CORES DA FOTO"
                        glyph: "midia"
                        onClicked: dp.setMono(dp.activeScene, !dp.monoFor(dp.activeScene))
                    }
                }
                Row {   // carrossel: tempo entre as trocas
                    visible: dp.activeScene !== null && dp.activeScene.carousel !== null
                    spacing: 6
                    topPadding: 4
                    height: visible ? 38 : 0
                    Text { anchors.verticalCenter: parent.verticalCenter; rightPadding: 6; text: "Troca a cada"; font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 17; color: Colors.fg }
                    Repeater {
                        model: dp.everyChoices
                        UiButton { required property int modelData; anchors.verticalCenter: parent.verticalCenter; text: modelData + " S"; filled: dp.everyFor(dp.activeScene) === modelData; onClicked: dp.setEvery(dp.activeScene, modelData) }
                    }
                }
            }
            Grid {   // as cenas
                id: gallery
                width: parent.width
                columns: 4
                spacing: 8
                readonly property real tileW: (width - spacing * (columns - 1)) / columns
                Repeater {
                    model: dp.scenes
                    Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool on: modelData.id === dp.activeId
                        width: gallery.tileW; height: gallery.tileW * 9 / 16 + 24; radius: 10
                        color: Qt.alpha(Colors.primary, tm.containsMouse ? 0.12 : 0.05)
                        border.width: on ? 2 : 1; border.color: on ? Colors.primary : Qt.alpha(Colors.fg, tm.containsMouse ? 0.35 : 0.14)
                        Rectangle {   // miniatura (cache desligado: as cenas são regeradas e o Qt guarda por endereço)
                            x: 4; y: 4; width: parent.width - 8; height: (parent.width - 8) * 9 / 16; radius: 7; clip: true
                            color: "#050607"
                            Image {
                                anchors.fill: parent
                                visible: tile.modelData.preview !== ""
                                source: tile.modelData.preview ? "file://" + tile.modelData.preview : ""
                                sourceSize.width: 260; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
                            }
                            Glyph { visible: tile.modelData.preview === ""; anchors.centerIn: parent; width: 26; height: 26; name: "nucleo"; color: Colors.primary; stroke: 1.8 }
                        }
                        Text {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 8; anchors.rightMargin: 8
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 4
                            text: tile.modelData.title; elide: Text.ElideRight
                            font.family: "Rajdhani"; font.weight: Font.Bold; font.pixelSize: 13
                            color: tile.on ? Colors.primary : Colors.fg
                        }
                        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dp.pick(tile.modelData.id) }
                    }
                }
            }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: "Os efeitos pausam sozinhos quando há janela aberta no monitor. As cenas ficam só neste PC (~/.local/share/azmuth/scenes). Pelo terminal: azmuth fundo."
                font.family: "Rajdhani"; font.pixelSize: 14; color: Qt.alpha(Colors.fg, 0.5)
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
