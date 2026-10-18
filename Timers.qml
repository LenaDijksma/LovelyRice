pragma Singleton
import QtQuick
import Quickshell

// Countdown timers started from the palette: /timer 10m tea. They notify when done.
// (Timers are kept in memory, so a shell reload clears them.)
Singleton {
    id: root
    property var timers: []      // [{ id, label, end }]
    property int seq: 0

    function start() {}          // shell.qml touches this once so the ticker exists from startup

    function parse(text) {
        const s = (text || "").toLowerCase().trim()
        if (/^\d+(\.\d+)?$/.test(s)) return parseFloat(s) * 60000          // bare number = minutes
        let ms = 0, matched = false
        const rest = s.replace(/(\d+(?:\.\d+)?)\s*(h|m|s)/g, (all, n, u) => {
            matched = true
            ms += parseFloat(n) * (u === "h" ? 3600000 : (u === "m" ? 60000 : 1000))
            return ""
        })
        return matched && rest.trim() === "" ? ms : 0
    }
    function format(ms) {
        const t = Math.round(ms / 1000)
        const h = Math.floor(t / 3600), m = Math.floor((t % 3600) / 60), s = t % 60
        return (h ? h + "h " : "") + (m ? m + "m " : "") + (s || (!h && !m) ? s + "s" : "")
    }
    function add(label, ms) {
        timers = timers.concat([{ id: ++seq, label: label || "", end: Date.now() + ms }])
    }
    function cancel(id) { timers = timers.filter(t => t.id !== id) }

    Timer {
        interval: 1000; repeat: true; running: root.timers.length > 0
        onTriggered: {
            const now = Date.now()
            const due = root.timers.filter(t => t.end <= now)
            if (due.length === 0) return
            root.timers = root.timers.filter(t => t.end > now)
            for (const t of due)
                Quickshell.execDetached(["notify-send", "-a", "Timer", "-u", "critical", "Timer finished", t.label || "Time's up"])
        }
    }
}
