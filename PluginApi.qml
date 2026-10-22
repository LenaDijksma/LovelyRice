import QtQuick
import Quickshell
import Quickshell.Io

// What a plugin gets as its `api` (one per loaded plugin, made by Plugins.qml).
//
// Colors and sizes follow the theme and the utility bar live, so bind to them instead of copying them.
// None of this is a sandbox: a plugin is QML running with your full permissions and could do all of it without the API.
Scope {
    id: api
    required property string name

    // ---- theme (live) ----
    readonly property color bg: Theme.bg
    readonly property color surface: Theme.surface
    readonly property color fg: Theme.fg
    readonly property color dim: Theme.dim
    readonly property color accent: Theme.accent
    readonly property color accent2: Theme.accent2
    readonly property color warn: Theme.warn
    readonly property string font: Theme.font
    readonly property int radius: Theme.radius
    readonly property int radiusSmall: Theme.radiusSmall
    function dur(ms) { return Theme.dur(ms) }             // an animation duration scaled by the user's animation speed

    // ---- the utility bar (live) ----
    readonly property string barPosition: Settings.barPosition    // left | right | top | bottom
    readonly property bool horizontal: Theme.horizontal           // true on a top / bottom bar
    readonly property int barThickness: Theme.barThickness
    readonly property int cell: Theme.cell                        // one widget cell across the bar
    readonly property int iconSize: Theme.iconSize
    function fs(n) { return Theme.fs(n) }                         // a font size that scales with the bar thickness

    // ---- notifications ----
    // urgency: "low" | "normal" (default) | "critical". Shown by the shell's own notification popups.
    function notify(summary, body, urgency) {
        const u = (urgency === "low" || urgency === "critical") ? urgency : "normal"
        Quickshell.execDetached(["notify-send", "-a", api.name, "-u", u, "--", String(summary || ""), String(body || "")])
    }

    // ---- running commands ----
    // A command is an array of strings (no shell) or one string (run with `sh -c`).
    function argv(cmd) {
        if (Array.isArray(cmd)) return cmd.map(s => String(s))
        if (typeof cmd === "string") return ["sh", "-c", cmd]
        return []
    }
    function exec(cmd) { const a = argv(cmd); if (a.length > 0) Quickshell.execDetached(a) }           // fire and forget
    function run(cmd, callback) {                                                                       // callback(exitCode, stdout)
        const a = argv(cmd)
        if (a.length === 0) return
        runnerC.createObject(api, { command: a, done: typeof callback === "function" ? callback : null, running: true })
    }
    Component {
        id: runnerC
        Process {
            id: p
            property var done: null
            property bool outDone: false
            property bool hasExited: false
            property int code: -1
            function finish(force) {
                if (!p.hasExited || !(p.outDone || force)) return
                const cb = p.done
                p.done = null
                if (cb) { try { cb(p.code, out.text) } catch (e) { console.warn("LovelyRice plugin " + api.name + ": callback failed: " + e) } }
                p.destroy()
            }
            stdout: StdioCollector { id: out; onStreamFinished: { p.outDone = true; p.finish(false) } }
            // the output normally ends before the exit is reported; if it does not (the program never started), give up waiting
            property Timer grace: Timer { interval: 400; onTriggered: p.finish(true) }      // Process has no default property, so a child Timer must be a property
            onExited: c => { p.code = c; p.hasExited = true; p.finish(false); p.grace.start() }
        }
    }

    // ---- storage: small JSON values kept per plugin in ~/.local/state/lovelyrice/plugins/<name>.json ----
    // Values load a moment after the plugin starts, so use get() inside bindings: they update when the data arrives.
    property var store: ({})
    readonly property string file: Plugins.stateDir + "/plugins/" + name + ".json"
    function get(key, fallback) {
        const k = String(key)
        return Object.prototype.hasOwnProperty.call(store, k) ? store[k] : fallback
    }
    function set(key, value) {
        const s = Object.assign({}, store)
        s[String(key)] = value
        store = s
        saveTimer.restart()
    }
    function remove(key) {
        const s = Object.assign({}, store)
        delete s[String(key)]
        store = s
        saveTimer.restart()
    }
    FileView {
        path: api.file
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text())
                if (d && typeof d === "object" && !Array.isArray(d)) api.store = Object.assign({}, d, api.store)   // keep what was set before the load finished
            } catch (e) { console.warn("LovelyRice plugin " + api.name + ": bad stored data") }
        }
    }
    Timer {
        id: saveTimer
        interval: 300
        onTriggered: {
            const json = JSON.stringify(api.store)
            if (json.length > 1048576) { console.warn("LovelyRice plugin " + api.name + ": stored data over 1 MB, not saved"); return }
            saver.command = ["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$3.tmp" && mv "$3.tmp" "$3"',
                             "sh", Plugins.stateDir + "/plugins", json, api.file]
            saver.running = true
        }
    }
    Process { id: saver }

    function log(msg) { console.log("[lovelyrice plugin " + api.name + "] " + msg) }
}
