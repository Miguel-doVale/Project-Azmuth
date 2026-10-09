// Project Azmuth — playlists de apps (dados), compartilhadas pelo lançador e pela
// Central de Configuração. Persistem em ~/.local/state/azmuth/playlists.json.
// Na primeira vez são geradas pelas categorias dos .desktop; depois, só o usuário muda.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: pls

    readonly property string path: Quickshell.env("HOME") + "/.local/state/azmuth/playlists.json"
    property var lists: []          // [{ id, name, glyph, color, apps: [desktopId] }]
    property bool ready: false

    readonly property var apps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    readonly property var orphans: {
        const used = new Set()
        for (const p of lists) for (const id of p.apps) used.add(id)
        return apps.filter(e => !used.has(e.id))
    }

    function app(id) { return DesktopEntries.byId(id) }
    function entriesOf(p) { return p ? p.apps.map(id => DesktopEntries.byId(id)).filter(e => e && !e.noDisplay) : [] }
    function indexOf(id) { return lists.findIndex(p => p.id === id) }
    function has(pid, appId) { const p = lists[indexOf(pid)]; return !!p && p.apps.includes(appId) }

    // ── edição (sempre cria cópias: as bindings do QML percebem a mudança) ──
    function commit(next) {
        lists = next
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"", "sh", path,
                                 JSON.stringify({ version: 1, playlists: next }, null, 1)])
    }
    function clone() { return lists.map(p => Object.assign({}, p, { apps: p.apps.slice() })) }
    function update(pid, fn) { const n = clone(); const i = n.findIndex(p => p.id === pid); if (i >= 0) { fn(n[i]); commit(n) } }

    function create(name) {
        const id = "pl" + Date.now().toString(36)
        commit(clone().concat([{ id: id, name: (name || "NOVA PLAYLIST").toUpperCase(), glyph: "nucleo", color: "#38bdf8", apps: [] }]))
        return id
    }
    function remove(pid) { commit(clone().filter(p => p.id !== pid)) }
    function rename(pid, name) { update(pid, p => p.name = name.toUpperCase()) }
    function setGlyph(pid, g) { update(pid, p => p.glyph = g) }
    function setColor(pid, c) { update(pid, p => p.color = c) }
    function move(pid, d) {
        const n = clone(), i = n.findIndex(p => p.id === pid), j = i + d
        if (i < 0 || j < 0 || j >= n.length) return
        const t = n[i]; n[i] = n[j]; n[j] = t
        commit(n)
    }
    function addApp(pid, appId) { update(pid, p => { if (!p.apps.includes(appId)) p.apps.push(appId) }) }
    function removeApp(pid, appId) { update(pid, p => p.apps = p.apps.filter(x => x !== appId)) }
    function toggleApp(pid, appId) { has(pid, appId) ? removeApp(pid, appId) : addApp(pid, appId) }
    function moveApp(pid, appId, d) {
        update(pid, p => {
            const i = p.apps.indexOf(appId), j = i + d
            if (i < 0 || j < 0 || j >= p.apps.length) return
            const t = p.apps[i]; p.apps[i] = p.apps[j]; p.apps[j] = t
        })
    }

    // ── primeira vez: monta pelas categorias ──
    function seed() {
        const defs = [
            { id: "fav",        name: "FAVORITOS",  glyph: "estrela",  color: "#ffd76a", cats: [] },
            { id: "dev",        name: "DEV",        glyph: "codigo",   color: "#4dff8a", cats: ["Development", "IDE", "TerminalEmulator"] },
            { id: "internet",   name: "INTERNET",   glyph: "rede",     color: "#38bdf8", cats: ["Network", "WebBrowser", "Email", "Chat", "InstantMessaging"] },
            { id: "midia",      name: "MÍDIA",      glyph: "som",      color: "#f472b6", cats: ["AudioVideo", "Audio", "Video", "Graphics", "Photography"] },
            { id: "jogos",      name: "JOGOS",      glyph: "jogo",     color: "#ef4444", cats: ["Game"] },
            { id: "escritorio", name: "ESCRITÓRIO", glyph: "trabalho", color: "#a3e635", cats: ["Office", "TextEditor", "Education", "Science"] },
            { id: "sistema",    name: "SISTEMA",    glyph: "sistema",  color: "#94a3b8", cats: ["System", "Settings", "Utility", "FileManager", "Monitor"] }
        ]
        const catsOf = e => Array.isArray(e.categories) ? e.categories : String(e.categories || "").split(/[;,]/)
        const taken = new Set()
        const out = defs.map(d => {
            const ids = apps.filter(e => !taken.has(e.id) && d.cats.some(c => catsOf(e).includes(c))).map(e => e.id)
            ids.forEach(id => taken.add(id))   // cada app numa playlist só (dá pra adicionar em mais depois)
            return { id: d.id, name: d.name, glyph: d.glyph, color: d.color, apps: ids }
        })
        commit(out)
        ready = true
    }

    FileView {
        id: file
        path: pls.path
        onLoaded: {
            try { const d = JSON.parse(text()); pls.lists = d.playlists || []; pls.ready = true }
            catch (e) { pls.seed() }
        }
        onLoadFailed: seedLater.restart()
    }
    // espera o DesktopEntries popular antes de gerar pela primeira vez
    Timer { id: seedLater; interval: 1500; onTriggered: pls.seed() }
}
