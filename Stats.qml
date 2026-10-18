pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Resource history for the dashboard graphs (CPU, memory, network), sampled every 3 s from /proc, about 2 minutes kept.
// Also holds the hover state shared by the sidebar clock and the Dashboard popout.
Singleton {
    id: root
    readonly property int keep: 40
    property var cpu: []                 // 0..100
    property var mem: []                 // 0..100
    property var net: []                 // bytes/s, download + upload
    property int cpuNow: 0
    property int memNow: 0
    property real rxRate: 0
    property real txRate: 0

    property bool hoverWidget: false
    property bool hoverCard: false
    property real widgetY: -1

    property real prevTotal: 0
    property real prevIdle: 0
    property real prevRx: 0
    property real prevTx: 0
    property double prevTime: 0

    function start() {}
    function push(arr, v) { return arr.concat([v]).slice(-keep) }
    function rate(b) {
        if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/s"
        return Math.round(b / 1024) + " KB/s"
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = p[3] + (p[4] || 0)
            const total = p.reduce((a, b) => a + b, 0)
            if (root.prevTotal > 0 && total > root.prevTotal) {
                root.cpuNow = Math.round(100 * (1 - (idle - root.prevIdle) / (total - root.prevTotal)))
                root.cpu = root.push(root.cpu, root.cpuNow)
            }
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
            root.memNow = Math.round(100 * (1 - avail / total))
            root.mem = root.push(root.mem, root.memNow)
        }
    }
    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0
            for (const line of text().split("\n").slice(2)) {
                const i = line.indexOf(":")
                if (i < 0) continue
                const name = line.slice(0, i).trim()
                if (name === "lo" || /^(veth|docker|br-)/.test(name)) continue
                const f = line.slice(i + 1).trim().split(/\s+/).map(Number)
                rx += f[0] || 0
                tx += f[8] || 0
            }
            const now = Date.now()
            if (root.prevTime > 0 && now > root.prevTime) {
                const dt = (now - root.prevTime) / 1000
                root.rxRate = Math.max(0, (rx - root.prevRx) / dt)
                root.txRate = Math.max(0, (tx - root.prevTx) / dt)
                root.net = root.push(root.net, root.rxRate + root.txRate)
            }
            root.prevRx = rx
            root.prevTx = tx
            root.prevTime = now
        }
    }
    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { stat.reload(); meminfo.reload(); netdev.reload() }
    }
}
