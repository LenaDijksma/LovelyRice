pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Picks the terminal for "open in terminal" actions (e.g. ldmp):
//   1. the one chosen in /settings   2. $TERMINAL   3. the terminal you currently have open
//   4. the first installed from a preference list (konsole, gnome-terminal and xterm only as a last resort)
Singleton {
    id: root
    property var installed: []
    readonly property var known: ["foot", "kitty", "alacritty", "wezterm", "ghostty", "rio", "tilix", "terminator",
                                  "ptyxis", "xfce4-terminal", "gnome-terminal", "konsole", "xterm", "st", "urxvt"]
    readonly property var lastResort: ["konsole", "gnome-terminal", "xterm", "urxvt", "xfce4-terminal"]

    function resolve() {
        if (Settings.terminal !== "auto" && installed.indexOf(Settings.terminal) >= 0) return Settings.terminal
        const env = (Quickshell.env("TERMINAL") || "").split("/").pop()
        if (env && installed.indexOf(env) >= 0) return env
        const tl = Hyprland.toplevels.values
        for (let i = 0; i < tl.length; i++) {
            const cls = tl[i].lastIpcObject ? String(tl[i].lastIpcObject.class || "").toLowerCase() : ""
            if (cls === "") continue
            for (const t of installed) if (cls.indexOf(t) >= 0) return t
        }
        for (const t of installed) if (lastResort.indexOf(t) < 0) return t
        return installed.length > 0 ? installed[0] : ""
    }
    function argsFor(t, cmd) {
        if (t === "kitty" || t === "foot") return [t].concat(cmd)
        if (t === "wezterm") return [t, "start", "--"].concat(cmd)
        if (t === "gnome-terminal" || t === "ptyxis") return [t, "--"].concat(cmd)
        return [t, "-e"].concat(cmd)
    }
    function run(cmd) {
        const t = resolve()
        if (t === "") { Quickshell.execDetached(["notify-send", "-a", "LovelyRice", "No terminal found", "Install one or pick it in /settings."]); return }
        Quickshell.execDetached(argsFor(t, cmd))
    }

    Process {
        running: true
        command: ["sh", "-c", 'for t in foot kitty alacritty wezterm ghostty rio tilix terminator ptyxis xfce4-terminal gnome-terminal konsole xterm st urxvt; do command -v "$t" >/dev/null 2>&1 && echo "$t"; done']
        stdout: StdioCollector { onStreamFinished: root.installed = text.split("\n").filter(s => s.length > 0) }
    }
}
