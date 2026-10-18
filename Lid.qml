pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lock when the laptop lid closes (/settings → "Lock when the lid closes").
// The lid state comes from /proc/acpi/button/lid/*/state, or from logind (busctl) when that file doesn't exist.
// If the machine slept without us seeing the lid (the polling stops during suspend), a long gap in the polling
// is treated as "just woke up" and locks too, so you never come back to an open desktop.
Singleton {
    id: root
    property bool closed: false
    property string stateFile: ""
    property double last: Date.now()

    function start() {}
    function setClosed(c) {
        if (c === closed) return
        closed = c
        if (c && Settings.lockOnLid) Session.lock()
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /proc/acpi/button/lid/*/state 2>/dev/null | head -n1"]
        stdout: StdioCollector { onStreamFinished: root.stateFile = text.trim() }
    }
    FileView {
        id: lidFile
        path: root.stateFile
        printErrors: false
        onLoaded: root.setClosed(text().indexOf("closed") >= 0)
    }
    Process {
        id: bus
        command: ["busctl", "get-property", "org.freedesktop.login1", "/org/freedesktop/login1",
                  "org.freedesktop.login1.Manager", "LidClosed"]
        stdout: StdioCollector { onStreamFinished: root.setClosed(text.indexOf("true") >= 0) }
    }
    Timer {
        interval: 1500; repeat: true; running: Settings.lockOnLid
        onTriggered: {
            const now = Date.now()
            if (now - root.last > 30000) Session.lock()      // woke up from sleep
            root.last = now
            if (root.stateFile !== "") lidFile.reload()
            else if (!bus.running) bus.running = true
        }
    }
}
