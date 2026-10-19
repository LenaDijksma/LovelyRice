pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User settings, edited through /settings and saved to ~/.local/state/lovelyrice/settings.json.
Singleton {
    id: root

    // ---- sidebar ----
    property int sidebarWidth: 54
    property int gap: 10
    property string side: "left"       // left | right
    property int radius: 20
    // order of the sidebar modules, top to bottom; "spacer" is the flexible gap that pushes the rest to the bottom
    property var sidebarOrder: ["logo", "workspaces", "spacer", "media", "status", "brightness", "buttons", "recording", "clock"]
    readonly property var sidebarModules: ["logo", "workspaces", "spacer", "media", "status", "brightness", "buttons", "recording", "clock"]
    // ---- what is shown ----
    property bool showLogo: true
    property bool showWorkspaces: true
    property bool showMedia: true
    property bool showStats: true
    property bool showAudio: true
    property bool showBattery: true
    property bool showButtons: true
    property bool showClock: true
    property bool showBrightness: true
    property bool showNotifications: true
    // ---- popouts ----
    property bool osd: true
    property bool mediaPopout: true
    property bool dashboard: true           // hover the sidebar clock: weather, graphs, mini calendar
    property bool weather: false            // opt-in: fetches from wttr.in
    property string weatherUnits: "metric"  // metric | imperial
    // ---- battery ----
    property bool batteryWarning: true
    property int batteryLow: 20
    // ---- connectivity ----
    property bool showNetwork: true
    property bool showBluetooth: true
    // ---- lock and sleep ----
    property bool autoLock: false
    property int lockMinutes: 10
    property bool autoSuspend: false
    property int suspendMinutes: 30
    property bool lockOnSleep: true
    property bool dimBeforeLock: true       // dim the screen for the last 15 s before an auto-lock
    property bool lockOnLid: false          // lock when the lid closes / the machine wakes up
    property bool lockBlur: true            // blurred screenshot behind the lock screen (else the wallpaper)
    property bool lockFingerprint: false    // fprintd fingerprint unlock
    // ---- apps ----
    property string terminal: "auto"
    // ---- palette ----
    property string searchEngine: "duckduckgo"   // for ?text (see Search.qml; "custom" comes from config.json)
    property bool calcAuto: true            // 2+2*3 is calculated without typing =
    property bool rankApps: true            // apps you launch often rise to the top
    // ---- theming ----
    property bool wallpaperTheme: false     // colors follow the wallpaper
    property bool runHooks: true            // run ~/.config/lovelyrice/hooks/* when the theme changes
    property bool syncApps: true            // built-in sync: foot, GTK, fastfetch and logo files follow the theme
    property bool syncGtk: true             //   ... GTK apps (needs `lovelyrice setup gtk` once)
    property bool syncFoot: true            //   ... running foot terminals (and the file new ones read)
    property string animSpeed: "normal"     // off | fast | normal | slow

    readonly property var defaults: ({
        sidebarWidth: 54, gap: 10, side: "left", radius: 20,
        sidebarOrder: ["logo", "workspaces", "spacer", "media", "status", "brightness", "buttons", "recording", "clock"],
        showLogo: true, showWorkspaces: true, showMedia: true, showStats: true,
        showAudio: true, showBattery: true, showButtons: true, showClock: true,
        showBrightness: true, showNotifications: true,
        osd: true, mediaPopout: true, dashboard: true, weather: false, weatherUnits: "metric", batteryWarning: true, batteryLow: 20,
        showNetwork: true, showBluetooth: true,
        autoLock: false, lockMinutes: 10, autoSuspend: false, suspendMinutes: 30, lockOnSleep: true,
        dimBeforeLock: true, lockOnLid: false, lockBlur: true, lockFingerprint: false,
        terminal: "auto", searchEngine: "duckduckgo", calcAuto: true, rankApps: true, wallpaperTheme: false, runHooks: true, syncApps: true, syncGtk: true, syncFoot: true, animSpeed: "normal"
    })
    readonly property var limits: ({
        sidebarWidth: [44, 84], gap: [0, 24], radius: [0, 32], lockMinutes: [1, 60], suspendMinutes: [5, 180],
        batteryLow: [5, 50]
    })

    // keep only known modules, once each; modules missing from the list (added by an update) go back in at their default place
    function cleanOrder(list) {
        const known = sidebarModules, out = []
        if (!Array.isArray(list)) list = []
        for (const m of list) if (known.indexOf(m) >= 0 && out.indexOf(m) < 0) out.push(m)
        for (let i = 0; i < known.length; i++) {
            if (out.indexOf(known[i]) >= 0) continue
            let at = out.length
            for (let j = i + 1; j < known.length; j++) { const k = out.indexOf(known[j]); if (k >= 0) { at = k; break } }
            out.splice(at, 0, known[i])
        }
        return out
    }
    function moveModule(id, dir) {            // dir -1 = up, +1 = down
        const o = sidebarOrder.slice(), i = o.indexOf(id), j = i + dir
        if (i < 0 || j < 0 || j >= o.length) return
        o.splice(i, 1); o.splice(j, 0, id)
        set("sidebarOrder", o)
    }

    function clamp(key, v) {
        const l = limits[key]
        return l ? Math.max(l[0], Math.min(l[1], v)) : v
    }
    function set(key, v) {
        root[key] = clamp(key, v)
        save()
    }
    function reset() {
        for (const k in defaults) root[k] = defaults[k]
        save()
    }
    function apply(obj) {
        for (const k in defaults) {
            if (obj[k] !== undefined && typeof obj[k] === typeof defaults[k])
                root[k] = clamp(k, obj[k])
        }
        if (root.side !== "left" && root.side !== "right") root.side = "left"
        root.sidebarOrder = cleanOrder(root.sidebarOrder)
    }
    function save() { saveTimer.restart() }

    readonly property string dir: Quickshell.env("HOME") + "/.local/state/lovelyrice"

    Timer {
        id: saveTimer
        interval: 400
        onTriggered: {
            const out = {}
            for (const k in root.defaults) out[k] = root[k]
            saver.command = ["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$1/settings.json"',
                             "sh", root.dir, JSON.stringify(out, null, 2)]
            saver.running = true
        }
    }
    Process { id: saver }

    FileView {
        path: root.dir + "/settings.json"
        printErrors: false
        onLoaded: { try { root.apply(JSON.parse(text())) } catch (e) { console.warn("LovelyRice: bad settings.json") } }
    }
}
