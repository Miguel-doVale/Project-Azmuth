// Project Azmuth — métricas do sistema compartilhadas (barra, widgets, dashboard).
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: stats

    property real cpu: 0      // %
    property real ram: 0      // %
    property real temp: 0     // °C (pacote da CPU)
    property real ramUsedGiB: 0
    property real ramTotalGiB: 0
    property var last: null
    property string tempPath: ""

    FileView { id: stat; path: "/proc/stat" }
    FileView { id: meminfo; path: "/proc/meminfo" }
    FileView { id: tempFile; path: stats.tempPath }

    // acha o sensor do pacote da CPU (x86_pkg_temp), senão o primeiro disponível
    Process {
        running: true
        command: ["sh", "-c", "for z in /sys/class/thermal/thermal_zone*; do [ \"$(cat $z/type)\" = x86_pkg_temp ] && echo $z/temp && exit; done; ls /sys/class/thermal/thermal_zone*/temp | head -1"]
        stdout: StdioCollector { onStreamFinished: stats.tempPath = this.text.trim() }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            stat.reload(); meminfo.reload()
            const c = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = c[3] + c[4], total = c.reduce((a, b) => a + b, 0)
            if (!isFinite(total) || total <= 0) return   // leitura vazia: não contamina a próxima
            if (stats.last) stats.cpu = 100 * (1 - (idle - stats.last.idle) / Math.max(1, total - stats.last.total))
            stats.last = { idle: idle, total: total }

            const m = {}
            meminfo.text().split("\n").forEach(l => { const p = l.split(/:\s+/); if (p.length > 1) m[p[0]] = parseInt(p[1]) })
            if (m.MemTotal) {
                stats.ram = 100 * (1 - m.MemAvailable / m.MemTotal)
                stats.ramTotalGiB = m.MemTotal / 1048576
                stats.ramUsedGiB = (m.MemTotal - m.MemAvailable) / 1048576
            }

            if (stats.tempPath) {
                tempFile.reload()
                const t = parseInt(tempFile.text())
                if (!isNaN(t)) stats.temp = t / 1000
            }
        }
    }
}
