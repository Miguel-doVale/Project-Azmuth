pragma Singleton
// Project Azmuth — layout dos widgets da área de trabalho ("desktop canvas").
// Cada widget: { uid, type, x, y, s } — x/y = centro em fração da tela (0–1), s = escala.
// Persiste em ~/.local/state/azmuth/desktop.json. Editado pelo DesktopEditor (modo edição)
// e pela Central → Área de trabalho.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: dl

    readonly property string path: Quickshell.env("HOME") + "/.local/state/azmuth/desktop.json"
    property var widgets: []
    property bool editing: false

    // catálogo (nome e runa usados no editor e na Central)
    readonly property var catalog: [
        { type: "relogio",    name: "Relógio",          glyph: "tempo" },
        { type: "aneis",      name: "Anéis do sistema", glyph: "nucleo" },
        { type: "energia",    name: "Energia",          glyph: "energia" },
        { type: "dna",        name: "DNA ativo",        glyph: "mente" },
        { type: "musica",     name: "Música",           glyph: "som" },
        { type: "calendario", name: "Calendário",       glyph: "dados" },
        { type: "sistema",    name: "Barras do sistema",glyph: "sistema" }
    ]
    readonly property var defaults: [
        { uid: "w1", type: "relogio", x: 0.5, y: 0.17, s: 1 },
        { uid: "w2", type: "aneis",   x: 0.5, y: 0.86, s: 1 }
    ]
    function info(type) { return catalog.find(c => c.type === type) || catalog[0] }

    function commit(next) {
        widgets = next
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"", "sh", path,
                                 JSON.stringify({ version: 1, widgets: next })])
    }
    function add(type) {
        const uid = "w" + Date.now().toString(36)
        commit(widgets.concat([{ uid: uid, type: type, x: 0.5, y: 0.5, s: 1 }]))
        return uid
    }
    function remove(uid) { commit(widgets.filter(w => w.uid !== uid)) }
    function update(uid, patch) { commit(widgets.map(w => w.uid === uid ? Object.assign({}, w, patch) : w)) }
    function reset() { commit(defaults.map(w => Object.assign({}, w))) }

    FileView {
        path: dl.path
        onLoaded: { try { dl.widgets = JSON.parse(text()).widgets || [] } catch (e) { dl.reset() } }
        onLoadFailed: dl.reset()
    }
}
