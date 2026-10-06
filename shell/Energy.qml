// Project Azmuth — energia do Omnitrix calculada ao vivo (barra, dashboard, widgets).
// A shell alimenta `t` com theme.timer; daqui pra frente a conta é local.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    property var t: ({})
    property real now: Date.now() / 1000
    Timer { interval: 250; running: true; repeat: true; onTriggered: parent.now = Date.now() / 1000 }

    readonly property bool enabled: t.enabled === true
    readonly property real rate: t.rate || 0
    readonly property real min: t.min || 0.2
    readonly property real level: enabled ? Math.max(0, Math.min(1, (t.energy || 0) + rate * (now - (t.ts || now)))) : 1
    readonly property int percent: Math.round(level * 100)
    readonly property bool draining: enabled && rate < 0
    readonly property bool charging: enabled && rate > 0 && level < 1
    readonly property bool locked: enabled && rate > 0 && level < min        // não deixa transformar
    readonly property real secondsLeft: draining ? level / -rate : 0         // até 0%
    readonly property real secondsToFull: charging ? (1 - level) / rate : 0  // até 100%
    readonly property real secondsToMin: locked ? (min - level) / rate : 0   // até poder transformar
    readonly property bool critical: draining && secondsLeft <= 60

    function mmss(s) { s = Math.max(0, Math.ceil(s)); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
}
