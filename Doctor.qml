pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which of the tools LovelyRice can use are installed? Runs scripts/doctor.sh.
//  - `/doctor` in the palette lists every tool, what it enables and how to install it
//  - the first time LovelyRice runs, one notification says how many optional tools are missing
//  - `lovelyrice doctor` prints the same list in a terminal
Singleton {
    id: root

    property var items: []            // { ok, required, cmd, pkg, feature }
    property bool loaded: false
    readonly property var missing: items.filter(i => !i.ok)
    readonly property var missingRequired: missing.filter(i => i.required)
    readonly property var installable: {
        const seen = {}, out = []
        for (const i of missing) if (i.pkg !== "-" && !seen[i.pkg]) { seen[i.pkg] = true; out.push(i.pkg) }
        return out.sort()
    }
    readonly property string installCommand: installable.length > 0 ? "sudo pacman -S --needed " + installable.join(" ") : ""
    readonly property string marker: Quickshell.env("HOME") + "/.local/state/lovelyrice/first-run-done"

    property bool _firstRunCheck: false

    function start() { startTimer.start() }                 // a few seconds after startup, so it never slows the shell down
    function refresh() { if (!proc.running) proc.running = true }

    function name(i) { return i.cmd.replace(/^font:/, "").replace(/\|/g, " or ") }

    // copy text; if wl-clipboard itself is what is missing, show it as a notification instead
    function copy(text) {
        Quickshell.execDetached(["sh", "-c",
            'printf %s "$1" | wl-copy 2>/dev/null || notify-send -a LovelyRice "Install command" "$1" 2>/dev/null',
            "sh", text])
    }

    function parse(text) {
        const out = []
        for (const line of text.split("\n")) {
            const f = line.split("\t")
            if (f.length < 5) continue
            out.push({ ok: f[0] === "ok", required: f[1] === "req", cmd: f[2], pkg: f[3], feature: f[4] })
        }
        // missing first, required before optional
        out.sort((a, b) => (a.ok - b.ok) || (b.required - a.required))
        items = out
        loaded = true
    }

    function firstRun() {
        const req = missingRequired.length, opt = missing.length - req
        if (req > 0)
            Quickshell.execDetached(["notify-send", "-a", "LovelyRice", "-u", "critical", "LovelyRice can't work properly",
                "Missing: " + missingRequired.map(i => root.name(i)).join(", ") + ".\nType /doctor in the palette (or run `lovelyrice doctor`)."])
        else if (opt > 0)
            Quickshell.execDetached(["notify-send", "-a", "LovelyRice", "Welcome to LovelyRice",
                opt + " optional tool" + (opt === 1 ? " is" : "s are") + " not installed, so a few features won't work yet.\nType /doctor in the palette to see which."])
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && : > "$1"', "sh", marker])
    }

    Timer { id: startTimer; interval: 4000; onTriggered: { root._firstRunCheck = true; root.refresh() } }

    Process {
        id: proc
        command: ["sh", Quickshell.shellPath("scripts/doctor.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                root.parse(text)
                if (root._firstRunCheck) { root._firstRunCheck = false; seen.running = true }
            }
        }
    }
    // exit code 0 = this is not the first run
    Process {
        id: seen
        command: ["test", "-e", root.marker]
        onExited: code => { if (code !== 0) root.firstRun() }
    }
}
