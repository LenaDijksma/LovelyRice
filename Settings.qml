pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User settings, edited through /settings and saved to ~/.local/state/lovelyrice/settings.json.
Singleton {
    id: root

    // ---- utility bar (this was the sidebar) ----
    // Old settings.json files keep working: sidebarWidth, side and sidebarOrder are read as barThickness,
    // barPosition and barOrder (see apply()). Only the new names are written.
    property int barThickness: 54
    property int gap: 10
    property string barPosition: "right"    // left | right | top | bottom
    property int radius: 20
    // order of the bar modules (top to bottom on a left/right bar, left to right on a top/bottom bar);
    // "spacer" is the flexible gap that pushes the rest to the far end
    property var barOrder: ["logo", "workspaces", "spacer", "media", "status", "brightness", "buttons", "recording", "clock"]
    readonly property var barModules: ["logo", "workspaces", "spacer", "media", "status", "brightness", "buttons", "recording", "clock"]
    readonly property var barPositions: ["left", "right", "top", "bottom"]

    // ---- bar look (Style tab) ----
    property string barStyle: "solid"           // solid | glass | transparent  (what the bar itself is made of)
    property int barOpacity: 100                // % of the theme's own bar opacity (0 = see-through, 100 = as the theme says)
    property int barRadius: 20                  // corner radius of the bar itself (popouts and panels use `radius`)
    property int barBorder: 1                   // border width in px, 0 = none
    property string barBorderColor: "accent"    // accent | accent2 | text | dim
    property int barBorderOpacity: 25           // %
    property int barShadow: 100                 // % of the theme's shadow, 0 = no shadow
    property string barShadowColor: "black"     // black | accent | accent2  (a coloured shadow is a glow)
    property int barLength: 100                 // % of the screen edge the bar covers
    property string barAlign: "center"          // start | center | end   (where a shorter bar sits on its edge)
    property int barPadding: 6                  // bar edge -> pill, px
    property int moduleSpacing: 8               // gap between modules, px
    // ---- module pills ----
    property string pillStyle: "filled"         // filled | outline | glass | none
    property int pillRadius: 16                 // corner radius of the module pills
    property int pillOpacity: 80                // % opacity of a filled pill
    property int pillPadding: 5                 // pill edge -> content, px
    // ---- glass (barStyle / pillStyle "glass") ----
    property int glassBlur: 55                  // 0-100
    property int glassRefraction: 60            // 0-100  how far the rim bends what is behind it (needs the shader, see README)
    property int glassLight: 55                 // 0-100  the bright rim highlight
    property int glassTint: 25                  // 0-100  how much of the theme color is mixed in
    property bool glassFringe: true             // faint color fringing at the bent rim
    // ---- visibility ----
    property string barVisibility: "always"     // always | autohide | hidden
    property bool barReserveSpace: false        // auto-hide: keep room for the bar so windows never sit under it
    property int barHideDelay: 700              // ms the pointer may be away before an auto-hide bar slides out
    // ---- Hyprland integration (off until you switch it on: it changes the compositor's own settings while the shell runs) ----
    property bool hyprSync: false
    property bool hyprBorders: true             // window border colors come from the theme
    property string hyprBorderStyle: "gradient" // gradient (accent -> accent 2) | solid (accent)
    property bool hyprShape: true               // border width, rounding, gaps
    property int hyprBorderSize: 2
    property bool hyprRoundFollow: true         // window rounding follows the bar's corner radius
    property int hyprRounding: 12
    property bool hyprGapsFollow: false         // outer gap = the bar's edge gap, inner gap = half of it
    property int hyprGapsIn: 4
    property int hyprGapsOut: 10
    property bool hyprBlur: false
    property int hyprBlurSize: 6
    property int hyprBlurPasses: 2
    property bool hyprShadow: false
    property int hyprShadowRange: 16
    property bool hyprShadowGlow: true          // the window shadow takes the accent color
    property bool hyprOpacity: false
    property int hyprActiveOpacity: 100         // %
    property int hyprInactiveOpacity: 92        // %
    // ---- split bar: a second bar with its own edge and its own modules ----
    property bool barSplit: false
    property string bar2Position: "top"
    property var bar2Modules: ["logo", "workspaces", "clock"]   // the modules that live on bar 2 (the rest stay on bar 1; the flexible gap is on both)

    // ---- dropdown panel ----
    // A tabbed panel attached to a screen edge. If that edge is the bar's, it sits beyond the bar instead of under it.
    property string dropdownPosition: "top"     // top | bottom | left | right
    property bool dropdownHotEdge: false        // push the pointer against that edge to open it
    property var dropdownOrder: ["dashboard", "control", "media", "notifications"]
    readonly property var dropdownModules: ["dashboard", "control", "media", "notifications"]
    readonly property var dropdownPositions: ["top", "bottom", "left", "right"]
    property bool dropdownDashboard: true       // which tabs are shown
    property bool dropdownControl: true
    property bool dropdownMedia: true
    property bool dropdownNotifications: true
    // ---- plugins (see PLUGINS.md; which plugins are allowed lives in plugins.state, not here) ----
    property bool pluginHotReload: false        // development: reload a plugin when its files change
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
    property bool dashboard: true           // hover the bar clock: weather, graphs, mini calendar
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
    property bool wallpaperAnimate: true    // play animated wallpapers (gif / webp / video); off = a still frame
    property bool runHooks: true            // run ~/.config/lovelyrice/hooks/* when the theme changes
    property bool syncApps: true            // built-in sync: foot, GTK, fastfetch and logo files follow the theme
    property bool syncGtk: true             //   ... GTK apps (needs `lovelyrice setup gtk` once)
    property bool syncFoot: true            //   ... running foot terminals (and the file new ones read)
    property string animSpeed: "normal"     // off | fast | normal | slow

    // true once settings.json has been read (or turned out not to exist). Code that changes settings at startup waits for it,
    // because saving before the read would write the defaults over the file.
    property bool loaded: false

    readonly property var defaults: ({
        barThickness: 54, gap: 10, barPosition: "right", radius: 20,
        barStyle: "solid", barOpacity: 100, barRadius: 20, barBorder: 1, barBorderColor: "accent", barBorderOpacity: 25,
        barShadow: 100, barShadowColor: "black", barLength: 100, barAlign: "center", barPadding: 6, moduleSpacing: 8,
        pillStyle: "filled", pillRadius: 16, pillOpacity: 80, pillPadding: 5,
        glassBlur: 55, glassRefraction: 60, glassLight: 55, glassTint: 25, glassFringe: true,
        barVisibility: "always", barReserveSpace: false, barHideDelay: 700,
        barSplit: false, bar2Position: "top", bar2Modules: ["logo", "workspaces", "clock"],
        hyprSync: false, hyprBorders: true, hyprBorderStyle: "gradient", hyprShape: true, hyprBorderSize: 2, hyprRoundFollow: true,
        hyprRounding: 12, hyprGapsFollow: false, hyprGapsIn: 4, hyprGapsOut: 10, hyprBlur: false, hyprBlurSize: 6, hyprBlurPasses: 2,
        hyprShadow: false, hyprShadowRange: 16, hyprShadowGlow: true, hyprOpacity: false, hyprActiveOpacity: 100, hyprInactiveOpacity: 92,
        barOrder: ["logo", "workspaces", "spacer", "media", "status", "brightness", "buttons", "recording", "clock"],
        dropdownPosition: "top", dropdownHotEdge: false, dropdownOrder: ["dashboard", "control", "media", "notifications"],
        dropdownDashboard: true, dropdownControl: true, dropdownMedia: true, dropdownNotifications: true,
        pluginHotReload: false,
        showLogo: true, showWorkspaces: true, showMedia: true, showStats: true,
        showAudio: true, showBattery: true, showButtons: true, showClock: true,
        showBrightness: true, showNotifications: true,
        osd: true, mediaPopout: true, dashboard: true, weather: false, weatherUnits: "metric", batteryWarning: true, batteryLow: 20,
        showNetwork: true, showBluetooth: true,
        autoLock: false, lockMinutes: 10, autoSuspend: false, suspendMinutes: 30, lockOnSleep: true,
        dimBeforeLock: true, lockOnLid: false, lockBlur: true, lockFingerprint: false,
        terminal: "auto", searchEngine: "duckduckgo", calcAuto: true, rankApps: true, wallpaperTheme: false, wallpaperAnimate: true, runHooks: true, syncApps: true, syncGtk: true, syncFoot: true, animSpeed: "normal"
    })
    readonly property var limits: ({
        barThickness: [44, 84], gap: [0, 24], radius: [0, 32], lockMinutes: [1, 60], suspendMinutes: [5, 180],
        batteryLow: [5, 50],
        barOpacity: [0, 100], barRadius: [0, 40], barBorder: [0, 4], barBorderOpacity: [0, 100], barShadow: [0, 100],
        barLength: [30, 100], barPadding: [0, 14], moduleSpacing: [0, 20],
        pillRadius: [0, 28], pillOpacity: [0, 100], pillPadding: [0, 12],
        glassBlur: [0, 100], glassRefraction: [0, 100], glassLight: [0, 100], glassTint: [0, 100],
        barHideDelay: [200, 2000],
        hyprBorderSize: [0, 8], hyprRounding: [0, 30], hyprGapsIn: [0, 20], hyprGapsOut: [0, 40], hyprBlurSize: [1, 20], hyprBlurPasses: [1, 6],
        hyprShadowRange: [1, 40], hyprActiveOpacity: [50, 100], hyprInactiveOpacity: [50, 100]
    })

    // keep only known modules, once each; modules missing from the list (added by an update) go back in at their default place.
    // "plugin:<name>" entries are kept as they are: plugins load after the settings do, so they cannot be checked here
    // (Plugins.prune() drops the ones whose plugin is gone).
    function isPluginId(m) { return typeof m === "string" && /^plugin:[a-z0-9_-]+$/.test(m) }
    function cleanOrder(list, known) {
        known = known || barModules
        const out = []
        if (!Array.isArray(list)) list = []
        for (const m of list) if ((known.indexOf(m) >= 0 || isPluginId(m)) && out.indexOf(m) < 0) out.push(m)
        for (let i = 0; i < known.length; i++) {
            if (out.indexOf(known[i]) >= 0) continue
            let at = out.length
            for (let j = i + 1; j < known.length; j++) { const k = out.indexOf(known[j]); if (k >= 0) { at = k; break } }
            out.splice(at, 0, known[i])
        }
        return out
    }
    function moveModule(id, dir, key) {       // dir -1 = up / left, +1 = down / right; key = which list ("barOrder" by default)
        key = key || "barOrder"
        const o = root[key].slice(), i = o.indexOf(id), j = i + dir
        if (i < 0 || j < 0 || j >= o.length) return
        o.splice(i, 1); o.splice(j, 0, id)
        set(key, o)
    }

    // ---- choices, for validation and the Style tab ----
    readonly property var enums: ({
        barStyle: ["solid", "glass", "transparent"],
        barBorderColor: ["accent", "accent2", "text", "dim"],
        barShadowColor: ["black", "accent", "accent2"],
        barAlign: ["start", "center", "end"],
        pillStyle: ["filled", "outline", "glass", "none"],
        barVisibility: ["always", "autohide", "hidden"],
        hyprBorderStyle: ["gradient", "solid"]
    })

    // ---- split bar ----
    // Which modules a bar shows, in the order of `barOrder`. With the split off, bar 1 has everything and bar 2 nothing.
    // The flexible gap ("spacer") is on both bars, so each one can push its own modules to its far end.
    function modulesFor(index) {
        if (!barSplit) return index === 1 ? barOrder : []
        const out = []
        for (const m of barOrder) {
            if (m === "spacer") { out.push(m); continue }
            if ((bar2Modules.indexOf(m) >= 0) === (index === 2)) out.push(m)
        }
        return out
    }
    function positionOf(index) { return index === 2 ? bar2Position : barPosition }
    // a bar exists when it is bar 1, or bar 2 with the split on and something on it
    function barExists(index) {
        if (index === 1) return true
        return barSplit && modulesFor(2).filter(m => m !== "spacer").length > 0
    }
    function toggleBar2(id) {
        const l = bar2Modules.slice(), i = l.indexOf(id)
        if (i >= 0) l.splice(i, 1); else l.push(id)
        set("bar2Modules", l)
    }
    // two bars on one edge would sit on top of each other: bar 2 moves to the first edge across from bar 1
    function fixPositions() {
        if (bar2Position !== barPosition && barPositions.indexOf(bar2Position) >= 0) return
        const horiz = barPosition === "top" || barPosition === "bottom"
        const c = horiz ? ["right", "left", "top", "bottom"] : ["top", "bottom", "left", "right"]
        for (const p of c) if (p !== barPosition) { bar2Position = p; return }
    }

    // ---- looks: a preset changes the look keys only (never position, modules, the split or your colors) ----
    readonly property var styleKeys: ["barStyle", "barOpacity", "barRadius", "barBorder", "barBorderColor", "barBorderOpacity", "barShadow",
        "barShadowColor", "barLength", "barAlign", "barPadding", "moduleSpacing", "pillStyle", "pillRadius", "pillOpacity", "pillPadding",
        "glassBlur", "glassRefraction", "glassLight", "glassTint", "glassFringe", "barVisibility", "gap", "barThickness"]
    readonly property var presetNames: ["classic", "glass", "islands", "minimal", "flat", "neon", "dock", "stealth"]
    readonly property var presetInfo: ({
        classic: "Classic: the original solid floating bar",
        glass:   "Glass: frosted, refracting bar and pills",
        islands: "Islands: no bar, every module floats on its own",
        minimal: "Minimal: bare icons, no backgrounds at all",
        flat:    "Flat: a square strip flush with the screen edge",
        neon:    "Neon: outlined pills and a glowing accent border",
        dock:    "Dock: a short, very round bar in the middle of the edge",
        stealth: "Stealth: transparent, slides away until you push the edge"
    })
    readonly property var presets: ({
        classic: {},
        glass:   { barStyle: "glass", pillStyle: "glass", barBorder: 1, barBorderColor: "text", barBorderOpacity: 28, barShadow: 55, barRadius: 26,
                   pillRadius: 18, glassBlur: 60, glassRefraction: 65, glassLight: 60, glassTint: 22 },
        islands: { barStyle: "transparent", barBorder: 0, barShadow: 0, barPadding: 0, moduleSpacing: 10, pillOpacity: 92, pillRadius: 18, pillPadding: 5 },
        minimal: { barStyle: "transparent", pillStyle: "none", barBorder: 0, barShadow: 0, barPadding: 0, moduleSpacing: 14 },
        flat:    { gap: 0, barRadius: 0, pillRadius: 6, barBorder: 0, barShadow: 0, moduleSpacing: 6 },
        neon:    { barOpacity: 80, barBorder: 2, barBorderColor: "accent", barBorderOpacity: 90, barShadowColor: "accent", barShadow: 100,
                   pillStyle: "outline", pillRadius: 14 },
        dock:    { barLength: 50, barAlign: "center", barRadius: 30, pillRadius: 22, barPadding: 8, moduleSpacing: 6 },
        stealth: { barStyle: "transparent", barBorder: 0, barShadow: 0, pillOpacity: 70, barVisibility: "autohide" }
    })
    function applyPreset(name) {
        if (!presets[name]) return
        for (const k of styleKeys) root[k] = defaults[k]
        const p = presets[name]
        for (const k in p) root[k] = clamp(k, p[k])
        save()
    }
    // the layout that is asked for most: workspaces on a bar along the top, everything else on the side bar
    function presetSplitLayout() {
        barSplit = true
        barPosition = "right"
        bar2Position = "top"
        bar2Modules = ["logo", "workspaces", "clock"]
        save()
    }

    function clamp(key, v) {
        const l = limits[key]
        return l ? Math.max(l[0], Math.min(l[1], v)) : v
    }
    function set(key, v) {
        root[key] = clamp(key, v)
        if (key === "barPosition" || key === "bar2Position" || key === "barSplit") fixPositions()
        save()
    }
    function reset() {
        for (const k in defaults) root[k] = Array.isArray(defaults[k]) ? defaults[k].slice() : defaults[k]
        save()
    }
    // settings.json written by an older version: the sidebar keys are now bar keys. A new name wins if both are there.
    readonly property var legacyKeys: ({ sidebarWidth: "barThickness", side: "barPosition", sidebarOrder: "barOrder" })
    function apply(obj) {
        for (const old in legacyKeys)
            if (obj[old] !== undefined && obj[legacyKeys[old]] === undefined) obj[legacyKeys[old]] = obj[old]
        for (const k in defaults) {
            if (obj[k] !== undefined && typeof obj[k] === typeof defaults[k])
                root[k] = clamp(k, obj[k])
        }
        // a settings.json from before the Style tab: the bar and pills keep the rounding they had (they followed `radius`)
        if (obj.barRadius === undefined && obj.radius !== undefined) root.barRadius = clamp("barRadius", root.radius)
        if (obj.pillRadius === undefined && obj.radius !== undefined) root.pillRadius = clamp("pillRadius", Math.round(root.radius * 0.6) + 4)
        for (const k in enums) if (enums[k].indexOf(root[k]) < 0) root[k] = defaults[k]
        if (barPositions.indexOf(root.barPosition) < 0) root.barPosition = defaults.barPosition
        if (barPositions.indexOf(root.bar2Position) < 0) root.bar2Position = defaults.bar2Position
        if (!Array.isArray(root.bar2Modules)) root.bar2Modules = defaults.bar2Modules.slice()
        root.bar2Modules = root.bar2Modules.filter((m, i, a) => m !== "spacer" && (barModules.indexOf(m) >= 0 || isPluginId(m)) && a.indexOf(m) === i)
        fixPositions()
        root.barOrder = cleanOrder(root.barOrder)
        if (dropdownPositions.indexOf(root.dropdownPosition) < 0) root.dropdownPosition = defaults.dropdownPosition
        root.dropdownOrder = cleanOrder(root.dropdownOrder, dropdownModules)
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
        onLoaded: { try { root.apply(JSON.parse(text())) } catch (e) { console.warn("LovelyRice: bad settings.json") } root.loaded = true }
        onLoadFailed: root.loaded = true       // no settings.json yet: the defaults stand
    }
}
