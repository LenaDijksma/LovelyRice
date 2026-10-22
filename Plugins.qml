pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Plugins: QML-level extensions in ~/.config/lovelyrice/plugins/<name>/ (plugin.json + Main.qml). See PLUGINS.md.
//
// TRUST. A plugin is arbitrary QML running inside the shell with the user's full permissions. The manifest's `provides`
// list is documentation, not a sandbox. So nothing loads until the user explicitly allows it (`lovelyrice plugin allow <name>`
// or the Allow row in /settings -> Plugins); installing alone never loads anything, and a plugin whose git commit changed since
// it was allowed stops loading until it is allowed again. The bookkeeping lives in scripts/plugins.sh; this file reads its
// `scan` output and loads what is allowed.
//
// Extension points (all optional, defined on the plugin's root Scope):
//   barModule        Component          -> a utility bar module, id "plugin:<name>" in Settings.barOrder
//   paletteCommands  [{name, run, ...}] -> /<name> in the command palette
//   dropdownCard     Component          -> a tab in the dropdown panel, id "plugin:<name>" in Settings.dropdownOrder
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/lovelyrice/plugins"
    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/lovelyrice"
    readonly property string script: Quickshell.shellPath("scripts/plugins.sh")

    // what is on disk: [{ name, version, description, provides, entry, allowed, enabled, trust, sig, error }]
    property var list: []
    // what is running: name -> { name, sig, obj, api, comp }
    property var instances: ({})
    // runtime load errors: name -> text
    property var errors: ({})
    property var failed: ({})            // name -> the sig that failed to load, so a broken plugin is not retried on every poll
    property int seq: 0
    property bool started: false

    // ---- scanning ----
    function start() {
        started = true
        if (Settings.loaded) scan()
        else startTimer.start()          // settings.json should load within milliseconds; do not wait for it forever
    }
    function scan() { scanner.running ? retry.restart() : (scanner.running = true) }
    function reload() { failed = ({}); scan() }
    Timer { id: retry; interval: 150; onTriggered: root.scan() }
    Timer { id: startTimer; interval: 4000; onTriggered: root.scan() }
    // development: look for changed files every two seconds
    Timer { interval: 2000; repeat: true; running: Settings.pluginHotReload && root.started; onTriggered: root.scan() }
    Connections {
        target: Settings
        function onLoadedChanged() {
            if (!Settings.loaded || !root.started) return
            startTimer.stop()
            root.scan()
        }
    }
    Process {
        id: scanner
        command: ["sh", root.script, "scan"]
        stdout: StdioCollector { onStreamFinished: root.scanned(text) }
    }

    function describe(f) {
        const p = { name: f[0], allowed: f[1] === "1", enabled: f[2] === "1", trust: f[3], sig: f[4],
                    version: "", description: "", provides: [], entry: "Main.qml", error: "" }
        let m = null
        try { m = JSON.parse(f.slice(5).join("\t")) } catch (e) { p.error = "plugin.json is not valid JSON"; return p }
        if (!m || typeof m !== "object" || Array.isArray(m)) { p.error = "plugin.json must be a JSON object"; return p }
        if (m.name !== p.name) p.error = "\"name\" in plugin.json must match the folder name (" + p.name + ")"
        if (typeof m.version === "string") p.version = m.version
        if (typeof m.description === "string") p.description = m.description
        if (Array.isArray(m.provides)) p.provides = m.provides.filter(s => typeof s === "string")
        if (m.entry !== undefined) {
            if (typeof m.entry === "string" && m.entry.indexOf("..") < 0 && /^[A-Za-z0-9_][A-Za-z0-9_.\/-]*\.qml$/.test(m.entry)) p.entry = m.entry
            else if (p.error === "") p.error = "\"entry\" must be a relative .qml path inside the plugin folder"
        }
        return p
    }

    function scanned(text) {
        const lines = text.split("\n").filter(l => l.length > 0)
        // the script ends its output with #ok; anything else means it did not finish, so change nothing
        if (lines.length === 0 || lines[lines.length - 1] !== "#ok") { console.warn("LovelyRice: plugin scan failed"); return }
        const out = []
        for (const line of lines) {
            if (line === "#ok") continue
            const f = line.split("\t")
            if (f.length >= 6) out.push(describe(f))
        }
        if (JSON.stringify(out) !== JSON.stringify(list)) list = out      // keep the settings page steady while nothing changed
        reconcile()
        prune()
    }

    function wants(p) { return p.allowed && p.enabled && p.trust === "ok" && p.error === "" }
    function reconcile() {
        const have = {}
        for (const p of list) {
            have[p.name] = true
            const cur = instances[p.name]
            if (!wants(p)) {
                if (cur) unload(p.name)
                setError(p.name, "")
                delete failed[p.name]
                continue
            }
            if (cur && cur.sig === p.sig) continue
            if (!cur && failed[p.name] === p.sig) continue
            load(p)
        }
        for (const n in instances) if (!have[n]) unload(n)
    }

    // ---- loading ----
    function fileUrl(path) { return "file://" + path.split("/").map(encodeURIComponent).join("/") }

    function load(p) {
        unload(p.name)
        // ?r= makes Qt read Main.qml again after an edit (other .qml files of the plugin stay cached until `lovelyrice reload`)
        const comp = Qt.createComponent(fileUrl(dir + "/" + p.name + "/" + p.entry) + "?r=" + (++seq))
        if (comp.status === Component.Loading) comp.statusChanged.connect(() => root.finish(p, comp))
        else finish(p, comp)
    }
    function finish(p, comp) {
        if (comp.status === Component.Loading) return
        if (comp.status !== Component.Ready) { fail(p, comp.errorString()); return }
        const api = apiC.createObject(root, { name: p.name })
        if (!api) { fail(p, "could not create the plugin API"); return }
        const obj = comp.createObject(root, { api: api })      // the root of Main.qml must declare `property var api`
        if (!obj) {
            api.destroy()
            fail(p, comp.errorString() || "could not create the plugin. Is the root a Scope with `property var api`?")
            return
        }
        const next = Object.assign({}, instances)
        next[p.name] = { name: p.name, sig: p.sig, obj: obj, api: api, comp: comp }
        instances = next
        delete failed[p.name]
        setError(p.name, "")
        console.log("LovelyRice: plugin " + p.name + " loaded")
        listOne(p.name)
    }
    function fail(p, msg) {
        failed[p.name] = p.sig
        setError(p.name, msg)
        console.warn("LovelyRice: plugin " + p.name + " failed to load: " + msg)
    }
    function unload(name) {
        const cur = instances[name]
        if (!cur) return
        const next = Object.assign({}, instances)
        delete next[name]
        instances = next                       // the bar and dropdown drop their loaders first ...
        Qt.callLater(() => { try { cur.obj.destroy(); cur.api.destroy() } catch (e) {} })   // ... then the code goes away
    }
    function setError(name, msg) {
        const next = Object.assign({}, errors)
        if (msg === "") { if (!(name in next)) return; delete next[name] } else next[name] = msg
        errors = next
    }
    Component { id: apiC; PluginApi {} }

    // ---- where a plugin's module / tab sits ----
    // A new bar module goes in front of the clock and a new dropdown tab at the end; the user moves them in /settings.
    // Nothing is written before settings.json has been read (that would save the defaults over it).
    function listOne(name) {
        const cur = instances[name]
        if (!cur || !Settings.loaded) return
        const id = "plugin:" + name
        if (cur.obj.barModule && Settings.barOrder.indexOf(id) < 0) {
            const o = Settings.barOrder.slice()
            const at = o.indexOf("clock")
            o.splice(at < 0 ? o.length : at, 0, id)
            Settings.set("barOrder", o)
        }
        if (cur.obj.dropdownCard && Settings.dropdownOrder.indexOf(id) < 0)
            Settings.set("dropdownOrder", Settings.dropdownOrder.concat([id]))
    }
    function listAll() { for (const n in instances) listOne(n) }
    Connections { target: Settings; function onLoadedChanged() { if (Settings.loaded) root.listAll() } }

    // a plugin that was removed leaves nothing behind in the module lists
    function prune() {
        if (!Settings.loaded) return
        const have = {}
        for (const p of list) have[p.name] = true
        const keep = id => id.indexOf("plugin:") !== 0 || have[id.slice(7)] === true
        if (!Settings.barOrder.every(keep)) Settings.set("barOrder", Settings.barOrder.filter(keep))
        if (!Settings.dropdownOrder.every(keep)) Settings.set("dropdownOrder", Settings.dropdownOrder.filter(keep))
    }

    // ---- what the rest of the shell asks for ----
    function barComponent(name) { const i = instances[name]; return i && i.obj.barModule ? i.obj.barModule : null }
    function cardComponent(name) { const i = instances[name]; return i && i.obj.dropdownCard ? i.obj.dropdownCard : null }
    function cardTitle(name) { const i = instances[name]; return i && i.obj.dropdownTitle ? String(i.obj.dropdownTitle) : name }
    function known(name) { for (const p of list) if (p.name === name) return true; return false }

    // palette commands as palette rows (see CommandPalette.qml)
    function paletteCommands() {
        const out = []
        for (const name in instances) {
            const cmds = instances[name].obj.paletteCommands
            if (!Array.isArray(cmds)) continue
            for (const c of cmds) {
                if (!c || typeof c.name !== "string" || !/^[a-z0-9][a-z0-9-]*$/.test(c.name) || typeof c.run !== "function") continue
                out.push({
                    kind: "cmd", id: "plugin:" + name + ":" + c.name, special: "plugin", plugin: name,
                    name: c.name, icon: c.icon ? String(c.icon) : "✦",
                    desc: (c.desc ? String(c.desc) : "") + "  · plugin " + name,
                    keywords: c.keywords ? String(c.keywords) : "", takesArgs: c.takesArgs === true, run: c.run
                })
            }
        }
        return out
    }
    function runCommand(item, args) {
        try { item.run(args === undefined ? "" : String(args)) }
        catch (e) {
            console.warn("LovelyRice: plugin " + item.plugin + " /" + item.name + " failed: " + e)
            Quickshell.execDetached(["notify-send", "-a", "LovelyRice", "Plugin error", item.plugin + " /" + item.name + ": " + e])
        }
    }

    // ---- /settings and the CLI ----
    function stateText(p) {
        if (p.error !== "") return "invalid: " + p.error
        if (p.trust === "changed") return "changed since you allowed it"
        if (!p.allowed) return "not allowed"
        if (!p.enabled) return "off"
        if (errors[p.name]) return "failed to load"
        return instances[p.name] ? "on" : "loading"
    }
    function status() {
        if (list.length === 0) return "no plugins in " + dir
        return list.map(p => p.name + (p.version ? " " + p.version : "") + ": " + stateText(p)
                             + (errors[p.name] ? "\n    " + errors[p.name].split("\n").join("\n    ") : "")).join("\n")
    }
    // allow | enable | disable | revoke, through the same script the CLI uses; then look again
    function act(sub, name) {
        Quickshell.execDetached(["sh", root.script, sub, name])
        afterAct.restart()
    }
    Timer { id: afterAct; interval: 500; onTriggered: root.reload() }
}
