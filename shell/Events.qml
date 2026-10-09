pragma Singleton
// Project Azmuth — eventos do calendário (Central → Calendário, widgets, lembretes).
// ~/.local/state/azmuth/events.json: [{ id, date: "AAAA-MM-DD", time: "HH:MM" | "", title, color, remind }]
// remind = minutos de antecedência do lembrete (-1 = sem lembrete). O Context Engine dispara.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: ev
    readonly property string path: Quickshell.env("HOME") + "/.local/state/azmuth/events.json"
    property var list: []

    function key(d) { return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0") }
    function sorted(a) { return a.slice().sort((x, y) => (x.date + (x.time || "99:99")).localeCompare(y.date + (y.time || "99:99"))) }
    function forDay(d) { const k = typeof d === "string" ? d : key(d); return sorted(list.filter(e => e.date === k)) }
    function hasDay(d) { const k = key(d); return list.some(e => e.date === k) }
    function colorsOn(d) { const k = key(d); return list.filter(e => e.date === k).slice(0, 3).map(e => e.color) }
    function upcoming(n) {
        const now = new Date(), today = key(now), hm = String(now.getHours()).padStart(2, "0") + ":" + String(now.getMinutes()).padStart(2, "0")
        return sorted(list.filter(e => e.date > today || (e.date === today && (!e.time || e.time >= hm)))).slice(0, n)
    }

    function commit(next) {
        list = next
        Quickshell.execDetached(["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\"", "sh", path, JSON.stringify(next, null, 1)])
    }
    function add(e) { commit(list.concat([Object.assign({ id: "e" + Date.now().toString(36), time: "", color: String(Colors.primary), remind: 10 }, e)])) }
    function update(id, patch) { commit(list.map(e => e.id === id ? Object.assign({}, e, patch) : e)) }
    function remove(id) { commit(list.filter(e => e.id !== id)) }

    FileView {
        path: ev.path
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { ev.list = JSON.parse(text()) || [] } catch (e) { ev.list = [] } }
        onLoadFailed: ev.list = []
    }
}
