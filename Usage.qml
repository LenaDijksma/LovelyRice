pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Remembers how often each app is launched so favourites float to the top.
Singleton {
    id: root
    property var counts: ({})
    readonly property string dir: Quickshell.env("HOME") + "/.local/state/lovelyrice"

    function bump(id) {
        const c = Object.assign({}, counts)
        c[id] = (c[id] || 0) + 1
        counts = c
        saver.command = ["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$1/launches.json"',
                         "sh", dir, JSON.stringify(c)]
        saver.running = true
    }

    function clear() {
        counts = ({})
        saver.command = ["sh", "-c", 'mkdir -p "$1" && printf %s "{}" > "$1/launches.json"', "sh", dir]
        saver.running = true
    }

    FileView {
        path: root.dir + "/launches.json"
        printErrors: false
        onLoaded: { try { root.counts = JSON.parse(text()) } catch (e) {} }
    }
    Process { id: saver }
}
