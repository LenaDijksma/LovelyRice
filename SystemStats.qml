import QtQuick
import Quickshell.Io

// CPU and memory from /proc, shown as animated rings. No external dependencies.
// Stacked down a left/right bar, side by side on a top/bottom bar.
BarStack {
    id: root
    spacing: 4
    property int cpu: 0
    property int mem: 0
    property real prevTotal: 0
    property real prevIdle: 0

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = p[3] + (p[4] || 0)
            const total = p.reduce((a, b) => a + b, 0)
            if (root.prevTotal > 0 && total > root.prevTotal)
                root.cpu = Math.round(100 * (1 - (idle - root.prevIdle) / (total - root.prevTotal)))
            root.prevTotal = total
            root.prevIdle = idle
        }
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text()
            const total = parseInt(t.match(/MemTotal:\s+(\d+)/)[1])
            const avail = parseInt(t.match(/MemAvailable:\s+(\d+)/)[1])
            root.mem = Math.round(100 * (1 - avail / total))
        }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { stat.reload(); meminfo.reload() }
    }

    Ring { value: root.cpu / 100; label: "cpu"; color: root.cpu > 85 ? Theme.warn : Theme.accent }
    Ring { value: root.mem / 100; label: "mem"; color: root.mem > 90 ? Theme.warn : Theme.accent2 }
}
