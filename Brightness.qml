pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen backlight (laptop panels). Reads /sys/class/backlight and sets the level with brightnessctl
// (`sudo pacman -S brightnessctl`; it goes through logind, so no root is needed).
//  - value:     0..1, or -1 until the first read
//  - set(f):    set the level (never below 2% so the screen can't go black)
//  - external:  emitted when something else changed it (brightness keys...), which is what the popout listens to
// External monitors (DDC) aren't supported.
Singleton {
    id: root

    property string blPath: ""
    readonly property string blName: blPath.split("/").pop()
    property real value: -1
    readonly property bool available: blPath !== "" && value >= 0
    property bool dragging: false            // the sidebar slider is being dragged
    property real pending: -1                // a level waiting for the previous brightnessctl call to finish
    property double holdUntil: 0             // while we are driving the level, ignore what the file says
    signal external(real v)

    function set(frac) {
        if (!available) return
        const f = Math.max(0.02, Math.min(1, frac))
        value = f
        pending = f
        holdUntil = Date.now() + 1000
        flush()
    }
    function step(delta) { set(value + delta) }
    function flush() {
        if (writer.running || pending < 0) return
        const pct = Math.round(pending * 100)
        pending = -1
        writer.command = ["brightnessctl", "-q", "-d", blName, "set", pct + "%"]
        writer.running = true
    }

    Process {
        id: writer
        onExited: { if (root.pending >= 0) root.flush() }
    }

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/* 2>/dev/null | head -n1"]
        stdout: StdioCollector { onStreamFinished: root.blPath = text.trim() }
    }
    FileView {
        id: blNow
        path: root.blPath !== "" ? root.blPath + "/brightness" : ""
        printErrors: false
        onLoaded: root.read()
    }
    FileView {
        id: blMax
        path: root.blPath !== "" ? root.blPath + "/max_brightness" : ""
        printErrors: false
    }
    Timer {
        interval: 400; repeat: true; running: root.blPath !== ""
        onTriggered: blNow.reload()
    }

    function read() {
        const max = parseFloat(blMax.text())
        const cur = parseFloat(blNow.text())
        if (!(max > 0) || isNaN(cur)) return
        const v = cur / max
        if (dragging || writer.running || pending >= 0 || Date.now() < holdUntil) return   // we are driving it
        if (value < 0) { value = v; return }                                               // first read
        if (Math.abs(v - value) <= 0.0005) return
        // Just after our own change the file can differ by rounding only; adopt it silently.
        const own = Date.now() < holdUntil + 3000 && Math.abs(v - value) < 0.02
        value = v
        if (!own) external(v)
    }
}
