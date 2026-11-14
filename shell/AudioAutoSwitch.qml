// Project Azmuth — aparelho de som conectado (fone com fio, USB, Bluetooth) vira a saída padrão na hora.
// Só aparelhos de verdade (alsa_output.* / bluez_output.*), nunca a saída virtual do EasyEffects: com o
// equalizador ligado, o EasyEffects segue a saída padrão e leva o EQ junto para o aparelho novo.
// Desliga com `azmuth set audio_auto_switch false`.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: sw
    property bool enabled: true
    property var known: ({})
    property bool seeded: false
    readonly property var hardware: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && /^(alsa_output|bluez_output)/.test(n.name || ""))

    onHardwareChanged: check()
    // os aparelhos que já existem quando a shell sobe não contam como "conectados agora"
    Timer { interval: 4000; running: true; onTriggered: { sw.known = sw.snapshot(); sw.seeded = true } }

    function snapshot() { const k = {}; for (const n of hardware) k[n.name] = true; return k }
    function check() {
        if (!seeded) return
        let fresh = null
        for (const n of hardware) if (!known[n.name]) fresh = n
        known = snapshot()              // quem saiu é esquecido: reconectar troca de novo
        if (!fresh || !enabled || Pipewire.defaultAudioSink === fresh) return
        Pipewire.preferredDefaultAudioSink = fresh
        Quickshell.execDetached(["notify-send", "-a", "Azmuth", "-u", "low", "-h", "string:x-canonical-private-synchronous:azmuth-audio",
                                 "Saída de som", fresh.nickname || fresh.description || fresh.name])
    }
}
