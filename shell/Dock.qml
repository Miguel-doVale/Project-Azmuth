// Project Azmuth — dock central, sempre recolhida. Fechada: só o risquinho de workspaces (um
// segmento por workspace ocupado). Encostou no risquinho → sobe a faixa de workspaces (número +
// ícones do que está aberto) e a dock (Omnitrix = roda de apps; apps fixos + abertos). Clique como
// no Windows: fechado abre, aberto foca, em foco minimiza. Referência: docs/design/prototipo-ilha-dock.html.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

PanelWindow {
    id: dock

    required property var theme
    property var shell: null
    property bool shown: false
    // medidas do protótipo em pixels físicos → lógicos (escala fracionada)
    readonly property real k: { const m = Hyprland.monitorFor(screen); const sc = m && m.lastIpcObject ? m.lastIpcObject.scale : 1; return sc > 0 ? 1 / sc : 1 }
    property bool hold: false            // aberta por IPC/atalho: não recolhe sozinha

    readonly property color primary: Colors.mode ? Colors.modeColor : theme.primary
    readonly property color bg: theme.background || "#0b0f19"
    readonly property color fg: theme.foreground || "#cdd6f4"
    property var pinnedOverride: null     // ordem nova já na tela enquanto o settings.json é gravado
    onThemeChanged: pinnedOverride = null
    readonly property var pinned: pinnedOverride || (theme.dock && theme.dock.pinned ? theme.dock.pinned : [])

    visible: theme.bar !== false
    anchors.bottom: true
    implicitWidth: 1100
    implicitHeight: 190
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.namespace: "azmuth-dock"
    WlrLayershell.layer: WlrLayer.Overlay
    // fechada: só o risquinho recebe o mouse; aberta: a faixa inteira da dock até a borda de baixo
    // (sem isso, o mouse encostado na borda ficava fora de tudo e a dock nunca descia)
    mask: Region { item: dock.shown ? dockHit : handle }
    Item {
        id: dockHit
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
        width: Math.max(body.width, wsbar.width) * dock.k + 24
        height: parent.height
        HoverHandler { id: dockHover; onHoveredChanged: hovered ? hideTimer.stop() : dock.hideSoon(450) }
    }

    // ── ícones (mesma lógica da barra antiga: aliases + caminho absoluto) ──
    readonly property var iconAliases: ({ "godot": "godot", "org.godotengine.editor": "godot",
                                          "org.godotengine.projectmanager": "godot", "spotify": "spotify-client" })
    function entryFor(appId) {
        const id = String(appId || ""), low = id.toLowerCase()
        return DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id) || DesktopEntries.heuristicLookup(low)
    }
    function iconFor(appId, entry) {
        const id = String(appId || ""), low = id.toLowerCase()
        const alias = iconAliases[low] || (low.startsWith("org.godotengine.") ? "godot" : "")
        const icon = alias || (entry && entry.icon) || id
        if (icon.startsWith("/")) return "file://" + icon
        return Quickshell.iconPath(icon, true) || Quickshell.iconPath(low, true)
            || Quickshell.iconPath("application-x-executable", true) || Quickshell.iconPath("utilities-terminal", true)
    }
    function appIdOf(t) { return t.wayland ? t.wayland.appId : ((t.lastIpcObject && t.lastIpcObject.class) || "") }
    function keyOf(appId) { const e = entryFor(appId); return e ? e.id : String(appId).toLowerCase() }

    // ── estado das janelas ──
    property int tick: 0
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "activewindow", "activewindowv2",
                 "workspace", "workspacev2", "createworkspace", "destroyworkspace"].includes(ev.name)) refresh.restart()
        }
    }
    Timer { id: refresh; interval: 80; onTriggered: { Hyprland.refreshToplevels(); Hyprland.refreshWorkspaces(); dock.tick++ } }

    readonly property var toplevels: { tick; return Hyprland.toplevels.values.filter(t => t.workspace) }
    // workspaces normais com janela (mais o atual); especiais (minimizados, magic) nunca aparecem
    readonly property var workspaces: {
        tick
        const cur = Hyprland.focusedWorkspace
        return Hyprland.workspaces.values
            .filter(w => w.id > 0 && (w.toplevels.values.length > 0 || w === cur))
            .sort((a, b) => a.id - b.id)
    }
    // fixos na ordem do settings + abertos não fixos no fim (sem separador)
    readonly property var apps: {
        const list = []
        const seen = {}
        for (const id of pinned) {
            const e = entryFor(id)
            const k = e ? e.id : id
            if (seen[k]) continue
            seen[k] = true
            list.push({ key: k, entry: e, appId: id })
        }
        for (const t of toplevels) {
            const id = appIdOf(t)
            if (!id) continue
            const k = keyOf(id)
            if (seen[k]) continue
            seen[k] = true
            list.push({ key: k, entry: entryFor(id), appId: id })
        }
        return list
    }
    function windowsOf(key) { return toplevels.filter(t => keyOf(appIdOf(t)) === key) }

    // ── fixar, desafixar e reordenar (salvo em settings.json → dock.pinned) ──
    property string dragKey: ""
    property real dragDx: 0
    readonly property int slot: 59            // 48 de ícone + 11 de espaço
    function pinnedIndex(key) { return pinned.findIndex(p => { const e = entryFor(p); return (e ? e.id : p) === key }) }
    readonly property int dragFrom: dragKey === "" ? -1 : pinnedIndex(dragKey)
    readonly property int dragTo: dragFrom < 0 ? -1 : Math.max(0, Math.min(pinned.length - 1, dragFrom + Math.round(dragDx / slot)))
    function shiftFor(key) {
        if (dragFrom < 0 || key === dragKey) return 0
        const i = pinnedIndex(key)
        if (i < 0) return 0
        if (dragFrom < dragTo && i > dragFrom && i <= dragTo) return -slot
        if (dragFrom > dragTo && i >= dragTo && i < dragFrom) return slot
        return 0
    }
    function isPinned(key) { return pinned.some(id => { const e = entryFor(id); return (e ? e.id : id) === key }) }
    function savePinned(list) { pinnedOverride = list; Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/azmuth", "set", "dock.pinned", JSON.stringify(list)]) }
    function pinToggle(app) {
        const id = app.entry ? app.entry.id : app.appId
        if (isPinned(app.key)) savePinned(pinned.filter(p => { const e = entryFor(p); return (e ? e.id : p) !== app.key }))
        else savePinned(pinned.concat([id]))
    }
    function moveTo(key, target) {
        const ids = pinned.slice()
        const from = ids.findIndex(p => { const e = entryFor(p); return (e ? e.id : p) === key })
        if (from < 0) return
        const to = Math.max(0, Math.min(ids.length - 1, target))
        if (to === from) return
        const [moved] = ids.splice(from, 1)
        ids.splice(to, 0, moved)
        savePinned(ids)
    }

    function click(app) {
        const wins = windowsOf(app.key)
        if (!wins.length) { if (app.entry) app.entry.execute(); else Quickshell.execDetached(["gtk-launch", app.appId]); hideSoon(); return }
        const active = Hyprland.activeToplevel
        const focused = wins.find(t => t === active && t.workspace && t.workspace.id > 0)
        if (focused) {   // em foco → minimiza (workspace oculto, igual ao Super+N)
            Quickshell.execDetached(["hyprctl", "eval",
                `hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", window = "address:0x${focused.address}", follow = false }))`])
        } else {
            const target = wins[wins.length - 1]
            if (target.wayland) target.wayland.activate()
            else Quickshell.execDetached(["hyprctl", "eval", `hl.dispatch(hl.dsp.focus({ window = "address:0x${target.address}" }))`])
        }
    }

    function hideSoon(ms) { hideTimer.interval = ms || 450; hideTimer.restart() }
    Timer { id: hideTimer; interval: 450; onTriggered: if (!dock.hold && !handleHover.hovered && !dockHover.hovered && !bodyHover.hovered && !wsHover.hovered && !pinMenu.visible && dock.dragKey === "") dock.shown = false }

    // ── risquinho de workspaces (fechada) ──
    Item {
        id: handle
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
        // área de ativação: a largura da dock inteira (o risquinho fica centralizado dentro)
        width: Math.max(body.width, segs.width + 8) + 24; height: 16
        transform: Scale { origin.x: handle.width / 2; origin.y: handle.height; xScale: dock.k; yScale: dock.k }
        opacity: dock.shown ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 250 } }
        // mouse parado na borda conta como "em cima da dock" (senão: sobe, ninguém avisa que o mouse está
        // ali porque ele não se mexeu, desce, o risquinho vê o mouse de novo, sobe… em loop)
        HoverHandler { id: handleHover; onHoveredChanged: if (hovered) { dock.shown = true; dock.hideSoon(1500) } else if (dock.shown) dock.hideSoon(450) }
        Rectangle {   // pílula escura atrás dos tracinhos: não somem sobre janelas claras/terminal
            anchors.centerIn: segs; width: segs.width + 14; height: 11; radius: 6
            color: Qt.alpha(dock.bg, 0.85); border.width: 1; border.color: Qt.alpha(dock.primary, 0.35)
        }
        Row {
            id: segs
            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
            spacing: 5
            Repeater {
                model: dock.workspaces
                Rectangle {
                    required property var modelData
                    readonly property bool cur: modelData === Hyprland.focusedWorkspace
                    anchors.bottom: parent.bottom
                    width: 24; height: cur ? 5 : 4; radius: 2
                    color: dock.primary; opacity: cur ? 1 : 0.7
                }
            }
        }
    }

    // ── faixa de workspaces ──
    Rectangle {
        id: wsbar
        HoverHandler { id: wsHover; onHoveredChanged: if (hovered) hideTimer.stop(); else dock.hideSoon(450) }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: body.top
        anchors.bottomMargin: 10 - body.height * (1 - dock.k)
        width: wsRow.width + 12; height: 38; radius: 15
        color: Qt.alpha(dock.bg, 0.95); border.width: 1; border.color: Qt.alpha(dock.primary, 0.45)
        opacity: dock.shown ? 1 : 0
        transform: [
            Scale { origin.x: wsbar.width / 2; origin.y: wsbar.height; xScale: dock.k; yScale: dock.k },
            Translate { y: dock.shown ? 0 : 120; Behavior on y { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } } }
        ]
        Behavior on opacity { NumberAnimation { duration: 300 } }
        Row {
            id: wsRow
            anchors.centerIn: parent
            spacing: 6
            Repeater {
                model: dock.workspaces
                Rectangle {
                    id: pill
                    required property var modelData
                    readonly property bool cur: modelData === Hyprland.focusedWorkspace
                    readonly property var wins: { dock.tick; return modelData.toplevels.values }
                    width: pillRow.width + 17; height: 26; radius: 10
                    color: cur ? Qt.alpha(dock.primary, 0.18) : (pma.containsMouse ? Qt.alpha(dock.primary, 0.12) : "transparent")
                    border.width: cur ? 1 : 0; border.color: Qt.alpha(dock.primary, 0.55)
                    Row {
                        id: pillRow
                        anchors.centerIn: parent; spacing: 6
                        Text { anchors.verticalCenter: parent.verticalCenter; text: pill.modelData.id; font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 11
                               color: pill.cur ? dock.primary : Qt.alpha(dock.fg, 0.75) }
                        Repeater {
                            model: pill.wins.slice(0, 4)
                            IconImage {
                                required property var modelData
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 18
                                source: { const id = dock.appIdOf(modelData); return dock.iconFor(id, dock.entryFor(id)) }
                            }
                        }
                    }
                    MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pill.modelData.activate() }
                }
            }
        }
    }

    // ── menu do clique direito: fixar / desafixar ──
    Rectangle {
        id: pinMenu
        property var target: null
        function openFor(appData, item) {
            target = appData
            const p = item.mapToItem(dock.contentItem, item.width / 2, 0)
            x = p.x - width / 2; y = p.y - height - 10
            visible = true
        }
        visible: false; z: 20
        width: pinText.implicitWidth + 28; height: 32; radius: 10
        color: "#0e1626"; border.width: 1; border.color: Qt.alpha(dock.primary, 0.6)
        Text {
            id: pinText
            anchors.centerIn: parent
            text: pinMenu.target && dock.isPinned(pinMenu.target.key) ? "Desafixar da dock" : "Fixar na dock"
            font.family: "Rajdhani"; font.weight: Font.DemiBold; font.pixelSize: 14; color: dock.fg
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (pinMenu.target) dock.pinToggle(pinMenu.target); pinMenu.visible = false } }
        HoverHandler { onHoveredChanged: if (!hovered) pinClose.restart(); else pinClose.stop() }
        Timer { id: pinClose; interval: 900; onTriggered: pinMenu.visible = false }
    }
    onShownChanged: if (!shown) pinMenu.visible = false

    // ── a dock ──
    Rectangle {   // neon em volta (cópia embaixo só para o brilho desfocado)
        anchors.horizontalCenter: body.horizontalCenter; anchors.bottom: body.bottom
        width: body.width; height: body.height; radius: body.radius
        color: dock.bg
        opacity: body.opacity
        transform: [
            Scale { origin.x: body.width / 2; origin.y: body.height; xScale: dock.k; yScale: dock.k },
            Translate { y: dock.shown ? 0 : 110; Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } } }
        ]
        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: true
            shadowEnabled: true; shadowColor: dock.primary; shadowOpacity: 0.5
            shadowBlur: 1.0; blurMax: 40; shadowVerticalOffset: 6; shadowHorizontalOffset: 0
        }
    }
    Rectangle {
        id: body
        HoverHandler { id: bodyHover; onHoveredChanged: if (hovered) hideTimer.stop(); else dock.hideSoon(450) }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
        width: appsRow.width + 26; height: 74; radius: 24
        color: Qt.alpha(dock.bg, 0.95); border.width: 1.5; border.color: Qt.alpha(dock.primary, 0.7)
        opacity: dock.shown ? 1 : 0
        transform: [
            Scale { origin.x: body.width / 2; origin.y: body.height; xScale: dock.k; yScale: dock.k },
            Translate { y: dock.shown ? 0 : 110; Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.22, 1, 0.36, 1, 1, 1] } } }
        ]
        Behavior on opacity { NumberAnimation { duration: 350 } }

        Row {
            id: appsRow
            anchors.centerIn: parent; anchors.verticalCenterOffset: -1
            spacing: 11
            Item {   // Omnitrix → roda de apps (Super+D) — centralizado na altura da dock
                width: 48; height: 58
                OmnitrixMark { anchors.centerIn: parent; size: 46; color: dock.primary; bg: dock.bg; master: dock.theme.master === true }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { dock.shown = false; if (dock.shell) dock.shell.openLauncher() } }
            }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 1; height: 32; color: Qt.alpha(dock.primary, 0.3) }
            Repeater {
                model: dock.apps
                Item {
                    id: app
                    required property var modelData
                    readonly property var wins: { dock.tick; return dock.windowsOf(modelData.key) }
                    readonly property bool open: wins.length > 0
                    readonly property bool focused: open && wins.some(t => t === Hyprland.activeToplevel && t.workspace && t.workspace.id > 0)
                    readonly property bool dragging: dock.dragKey === modelData.key
                    width: 48; height: 58
                    z: dragging ? 5 : 0
                    transform: Translate {
                        x: dock.shiftFor(app.modelData.key)
                        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                    Item {
                        id: tile
                        width: 48; height: 48
                        x: app.dragging ? dock.dragDx : 0
                        opacity: app.dragging ? 0.92 : 1
                        y: app.dragging ? -10 : (ama.containsMouse ? -6 : 0)
                        scale: app.dragging ? 1.12 : (ama.containsMouse ? 1.08 : 1)
                        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        Rectangle { anchors.fill: parent; anchors.margins: -3; radius: 15; color: "transparent"
                                    border.width: app.focused ? 2 : 0; border.color: dock.primary }
                        IconImage { id: appIcon; anchors.fill: parent; source: dock.iconFor(app.modelData.appId, app.modelData.entry); asynchronous: true }
                        Rectangle {   // app sem ícone: inicial do nome
                            anchors.fill: parent; radius: 13; visible: appIcon.status !== Image.Ready
                            color: Qt.alpha(dock.primary, 0.18); border.width: 1; border.color: Qt.alpha(dock.primary, 0.4)
                            Text { anchors.centerIn: parent; text: String((app.modelData.entry && app.modelData.entry.name) || app.modelData.appId || "?").charAt(0).toUpperCase()
                                   font.family: "Orbitron"; font.weight: Font.Bold; font.pixelSize: 20; color: dock.fg }
                        }
                    }
                    Rectangle {   // aberto (ponto) · em foco (traço)
                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                        width: app.focused ? 16 : 5; height: 4; radius: 2
                        color: dock.primary; opacity: app.open ? 1 : 0
                        Behavior on width { NumberAnimation { duration: 200 } }
                    }
                    MouseArea {
                        id: ama
                        anchors.fill: parent; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: app.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        property real startX: 0
                        property bool moved: false
                        onPressed: mouse => { startX = mouse.x; moved = false }
                        onPositionChanged: mouse => {
                            if (!pressed || !(pressedButtons & Qt.LeftButton) || !dock.isPinned(app.modelData.key)) return
                            if (!moved && Math.abs(mouse.x - startX) > 8) { moved = true; dock.dragKey = app.modelData.key }
                            if (moved) dock.dragDx = mouse.x - startX
                        }
                        onReleased: mouse => {
                            if (moved) {   // arrastou: solta na nova posição entre os fixos
                                dock.moveTo(app.modelData.key, dock.dragTo)
                                dock.dragKey = ""; dock.dragDx = 0
                            }
                        }
                        onClicked: mouse => {
                            if (moved) return
                            if (mouse.button === Qt.RightButton) pinMenu.openFor(app.modelData, app)
                            else dock.click(app.modelData)
                        }
                    }
                }
            }
        }
    }
}
