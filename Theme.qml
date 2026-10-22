pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Theme engine. Themes are plain JSON files in ./themes — drop one in and it appears.
// Shape (radius, sizes) is the same for every theme; themes only change color/font/shadow.
Singleton {
    id: root

    // ---- current theme values (defaults = "void") ----
    property string name: "void"
    property color bg: "#0b0b0d"
    property color surface: "#18181c"
    property color fg: "#e6e6e6"
    property color dim: "#6b6b73"
    property color accent: "#e5334b"
    property color accent2: "#8b5cf6"
    property color warn: "#f0a030"
    property string font: "JetBrains Mono"
    property real opacity: 0.94
    property real shadowOpacity: 0.6

    // ---- shape: identical across all themes ----
    readonly property int radius: Settings.radius
    readonly property int radiusSmall: Math.round(Settings.radius * 0.6)
    // the bar and its module pills have their own rounding (Style tab); what sits inside a pill follows it, so the corners stay concentric
    readonly property int barRadius: Settings.barRadius
    readonly property int pillRadius: Settings.pillRadius
    readonly property int innerRadius: Math.max(2, Settings.pillRadius - Settings.pillPadding)

    // ---- the bar's look (Style tab) ----
    readonly property bool glassBar: Settings.barStyle === "glass"
    readonly property bool glassPill: Settings.pillStyle === "glass"
    readonly property bool anyGlass: glassBar || glassPill
    // background of a solid bar: the theme's own opacity scaled by the setting; none at all for a transparent or a glass bar
    readonly property real barAlpha: Settings.barStyle === "solid" ? Math.min(1, opacity * Settings.barOpacity / 100) : 0
    readonly property color barBorderTint: {
        const b = Settings.barBorderColor
        const c = b === "accent2" ? accent2 : (b === "text" ? fg : (b === "dim" ? dim : accent))
        return Qt.alpha(c, Settings.barBorder > 0 ? Settings.barBorderOpacity / 100 : 0)
    }
    readonly property color barShadowTint: Settings.barShadowColor === "accent" ? accent : (Settings.barShadowColor === "accent2" ? accent2 : "black")
    // a coloured shadow needs to be seen to be a glow, so it is stronger than a black one
    readonly property real barShadowAmount: Math.min(1, shadowOpacity * (Settings.barShadow / 100) * (Settings.barShadowColor === "black" ? 1 : 1.25))

    Behavior on bg      { ColorAnimation { duration: root.dur(400) } }
    Behavior on surface { ColorAnimation { duration: root.dur(400) } }
    Behavior on fg      { ColorAnimation { duration: root.dur(400) } }
    Behavior on dim     { ColorAnimation { duration: root.dur(400) } }
    Behavior on accent  { ColorAnimation { duration: root.dur(400) } }
    Behavior on accent2 { ColorAnimation { duration: root.dur(400) } }
    Behavior on warn    { ColorAnimation { duration: root.dur(400) } }

    // ---- animation speed (/settings): off | fast | normal | slow ----
    readonly property real animScale: {
        const s = Settings.animSpeed
        return s === "off" ? 0 : (s === "fast" ? 0.5 : (s === "slow" ? 1.6 : 1))
    }
    function dur(ms) { return Math.round(ms * animScale) }

    // ---- layout ----
    readonly property int barThickness: Settings.barThickness   // across the bar: its width on a left/right bar, its height on a top/bottom bar
    readonly property bool horizontal: Settings.barPosition === "top" || Settings.barPosition === "bottom"
    readonly property int gap: Settings.gap
    readonly property int shadowPad: 40
    readonly property int sideMargin: Settings.barPadding      // bar edge -> pill
    readonly property int pillPad: Settings.pillPadding        // pill edge -> content
    readonly property int cell: Math.max(18, barThickness - 2 * sideMargin - 2 * pillPad)   // one widget cell
    readonly property int iconSize: Math.round(cell * 0.62)
    function fs(n) { return Math.max(7, Math.round(n * barThickness / 60)) }  // bar font size

    // ---- wallpapers (drawn by Wallpaper.qml) ----
    property string themeWallpaper: ""
    property string userWallpaper: ""
    readonly property string wallpaper: userWallpaper !== "" ? userWallpaper : themeWallpaper
    readonly property var wallpaperDirs: [
        Quickshell.env("HOME") + "/Pictures/Wallpapers",
        Quickshell.env("HOME") + "/Pictures/wallpapers",
        Quickshell.shellPath("wallpapers")
    ]

    // What the desktop actually shows. Normally the chosen wallpaper; while /wallpaper is open it is the row under
    // the cursor (a preview: nothing is saved until Enter, Esc puts the old one back).
    property bool previewActive: false
    property string previewWallpaper: ""
    readonly property string shownWallpaper: previewActive
        ? (previewWallpaper !== "" ? previewWallpaper : themeWallpaper)
        : wallpaper
    function previewWp(path) { previewWallpaper = path; previewActive = true }
    function clearWpPreview() { previewActive = false; previewWallpaper = "" }
    property bool videoWarned: false

    // still | anim (gif, animated webp: built into Qt) | video (needs qt6-multimedia)
    function wallpaperKind(p) {
        const m = /\.([A-Za-z0-9]+)$/.exec(p || "")
        const e = m ? m[1].toLowerCase() : ""
        if (e === "gif" || e === "webp") return "anim"
        if (["mp4", "webm", "mkv", "mov", "m4v"].indexOf(e) >= 0) return "video"
        return "still"
    }

    // ---- theme discovery ----
    property var available: []
    property var previews: ({})     // name -> { bg, accent, accent2 }
    property var themePaths: ({})   // name -> theme file (your own themes in userDir win over built-in ones)
    readonly property string userDir: Quickshell.env("HOME") + "/.config/lovelyrice/themes"

    readonly property string stateDir: Quickshell.env("HOME") + "/.local/state/lovelyrice"

    function applyData(d) {
        const c = d.colors || {}
        if (c.bg)      bg = c.bg
        if (c.surface) surface = c.surface
        if (c.fg)      fg = c.fg
        if (c.dim)     dim = c.dim
        if (c.accent)  accent = c.accent
        if (c.accent2) accent2 = c.accent2
        if (c.warn)    warn = c.warn
        if (d.font)    font = d.font
        if (d.opacity !== undefined) opacity = d.opacity
        shadowOpacity = d.shadow !== undefined ? d.shadow : 0.6
        themeWallpaper = d.wallpaper
            ? (d.wallpaper.startsWith("/") ? d.wallpaper : Quickshell.shellPath(d.wallpaper))
            : ""
    }

    // Switch theme (live preview; call save() to persist)
    function select(n) {
        if (!n) return
        name = n
        themeFile.path = themePaths[n] || Quickshell.shellPath("themes/" + n + ".json")
    }

    // Choose a wallpaper (empty string = back to the theme's own / generated background).
    function setWallpaper(path) {
        userWallpaper = path
        wpSaver.command = ["sh", "-c",
            'mkdir -p "$1"; if [ -n "$2" ]; then printf %s "$2" > "$1/wallpaper"; else rm -f "$1/wallpaper"; fi',
            "sh", stateDir, path]
        wpSaver.running = true
        Hooks.run()
    }

    function save() {
        saver.command = ["sh", "-c",
            'mkdir -p "$1" && printf %s "$2" > "$1/theme"', "sh", stateDir, name]
        saver.running = true
        Hooks.run()
    }

    function next() {
        if (available.length === 0) return
        const i = available.indexOf(name)
        select(available[(i + 1) % available.length])
        save()
    }

    FileView {
        id: themeFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.applyData(JSON.parse(text())) }
            catch (e) { console.warn("LovelyRice: could not parse theme '" + root.name + "':", e) }
        }
        onLoadFailed: console.warn("LovelyRice: theme not found:", root.name)
    }

    // Restore last-used theme + wallpaper
    FileView {
        path: root.stateDir + "/theme"
        printErrors: false
        onLoaded: root.select(text().trim())
        onLoadFailed: root.select("void")
    }
    FileView {
        path: root.stateDir + "/wallpaper"
        printErrors: false
        onLoaded: root.userWallpaper = text().trim()
    }

    function rescan() { scanner.running = true }
    // Make a just-saved theme selectable before the next rescan finishes.
    function registerUser(n, path) {
        const p = Object.assign({}, themePaths); p[n] = path; themePaths = p
        if (available.indexOf(n) < 0) available = available.concat([n])
    }

    // Scan themes (built-in ./themes and your own in ~/.config/lovelyrice/themes)
    Process {
        id: scanner
        running: true
        command: ["sh", "-c",
            'for d in "$@"; do for f in "$d"/*.json; do [ -f "$f" ] && { printf "%s\\t" "$f"; tr -d "\\n" < "$f"; echo; }; done; done',
            "sh", Quickshell.shellPath("themes"), root.userDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = []
                const prev = {}
                const paths = {}
                for (const line of text.split("\n")) {
                    const t = line.indexOf("\t")
                    if (t < 0) continue
                    const full = line.slice(0, t)
                    const n = full.split("/").pop().replace(".json", "")
                    try {
                        const c = JSON.parse(line.slice(t + 1)).colors || {}
                        prev[n] = { bg: c.bg || "#000", accent: c.accent || "#fff", accent2: c.accent2 || "#888" }
                        paths[n] = full
                        if (names.indexOf(n) < 0) names.push(n)
                    } catch (e) { console.warn("LovelyRice: bad theme file", n) }
                }
                root.previews = prev
                root.themePaths = paths
                // the saved theme may be one of yours, which is only found by this scan (startup race)
                if (paths[root.name] && themeFile.path !== paths[root.name]) themeFile.path = paths[root.name]
                root.available = names
            }
        }
    }

    Process { id: saver }
    Process { id: wpSaver }
}
