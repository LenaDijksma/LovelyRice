pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Quick task list for /todo, saved to ~/.local/state/lovelyrice/todos.json.
Singleton {
    id: root
    property var items: []       // [{ id, text, done }]
    property int seq: 0
    readonly property string file: Quickshell.env("HOME") + "/.local/state/lovelyrice/todos.json"

    function add(text) {
        const t = (text || "").trim()
        if (!t) return
        items = items.concat([{ id: Date.now() * 10 + (seq++ % 10), text: t, done: false }])
        save()
    }
    function toggle(id) { items = items.map(i => i.id === id ? { id: i.id, text: i.text, done: !i.done } : i); save() }
    function remove(id) { items = items.filter(i => i.id !== id); save() }
    function clearDone() { items = items.filter(i => !i.done); save() }
    function save() { saveTimer.restart() }

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            saver.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"',
                             "sh", root.file, JSON.stringify(root.items)]
            saver.running = true
        }
    }
    Process { id: saver }
    FileView {
        path: root.file
        printErrors: false
        onLoaded: { try { const v = JSON.parse(text()); if (Array.isArray(v)) root.items = v } catch (e) {} }
    }
}
