pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "ColorUtil.js" as CU

// Runs after the theme or wallpaper changes (and a few seconds after startup):
//  1. the built-in sync (scripts/theme-sync.sh): foot, GTK, fastfetch and logo files   (/settings -> Sync apps)
//  2. every executable file in ~/.config/lovelyrice/hooks/, in parallel, output discarded  (/settings -> Run theme hooks)
// Both get the colors in their environment (#rrggbb):
//   LR_THEME  LR_WALLPAPER  LR_BG  LR_SURFACE  LR_FG  LR_DIM  LR_ACCENT  LR_ACCENT2  LR_WARN
//   LR_C0 .. LR_C15   the 16 terminal colors made from the theme (ANSI order)      LR_LIGHT   1 for a light theme, else 0
// See hooks-examples/ for a kitty one. `qs -c lovelyrice ipc call rice runHooks` (lovelyrice sync) runs everything now.
Singleton {
    id: root
    readonly property string dir: Quickshell.env("HOME") + "/.config/lovelyrice/hooks"
    readonly property string syncScript: Quickshell.shellPath("scripts/theme-sync.sh")
    property string mode: "auto"          // auto: what /settings allows   forced: both   boot: only the built-in sync

    function hex(c) {
        function t(v) { const n = Math.round(v * 255).toString(16); return n.length < 2 ? "0" + n : n }
        return "#" + t(c.r) + t(c.g) + t(c.b)
    }
    function start() { bootTimer.start() }
    function run() { if (Settings.runHooks || Settings.syncApps) { mode = "auto"; timer.restart() } }
    function runNow() { mode = "forced"; timer.restart() }

    // generated files should exist from the first start, not only after the first theme change
    Timer {
        id: bootTimer
        interval: 3000
        onTriggered: if (Settings.syncApps) { root.mode = "boot"; timer.restart() }
    }

    // wait for the 400 ms color fade, so the hooks see the final colors
    Timer {
        id: timer
        interval: 900
        onTriggered: {
            if (proc.running) { timer.restart(); return }
            const pal = {
                bg: root.hex(Theme.bg), surface: root.hex(Theme.surface), fg: root.hex(Theme.fg), dim: root.hex(Theme.dim),
                accent: root.hex(Theme.accent), accent2: root.hex(Theme.accent2), warn: root.hex(Theme.warn)
            }
            const a = CU.ansi(pal)
            const doSync = root.mode === "forced" || Settings.syncApps
            const doHooks = root.mode === "forced" || (root.mode === "auto" && Settings.runHooks)
            const env = {
                LR_THEME: Theme.name, LR_WALLPAPER: Theme.wallpaper,
                LR_BG: pal.bg, LR_SURFACE: pal.surface, LR_FG: pal.fg, LR_DIM: pal.dim,
                LR_ACCENT: pal.accent, LR_ACCENT2: pal.accent2, LR_WARN: pal.warn,
                LR_LIGHT: a.light ? "1" : "0",
                LR_SYNC: doSync ? "1" : "0", LR_HOOKS: doHooks ? "1" : "0",
                LR_ASSETS: Quickshell.shellPath("assets"),
                LR_SYNC_GTK: Settings.syncGtk ? "1" : "0", LR_SYNC_FOOT: Settings.syncFoot ? "1" : "0"
            }
            for (let i = 0; i < 16; i++) env["LR_C" + i] = a.c[i]
            proc.environment = env
            proc.command = ["sh", "-c",
                'if [ "$LR_SYNC" = 1 ]; then sh "$2" >/dev/null 2>&1; fi; ' +
                'if [ "$LR_HOOKS" = 1 ] && [ -d "$1" ]; then for f in "$1"/*; do [ -f "$f" ] && [ -x "$f" ] && "$f" >/dev/null 2>&1 & done; wait; fi',
                "sh", root.dir, root.syncScript]
            proc.running = true
        }
    }
    Process { id: proc }
}
