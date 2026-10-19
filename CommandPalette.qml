import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import "Calc.js" as Calc
import "Fuzzy.js" as Fuzzy
import "Emoji.js" as EmojiData

// Centered launcher + command palette. Tap SUPER to open.
//   (just type)   search and launch apps
//   /             commands: /scheme /scheme-maker /match-wallpaper /sync-apps /wallpaper /clip /control /overview /dashboard /keys /network /bluetooth /music /windows /todo
//                           /emoji /kill /timer /screenshot
//                           /record /calendar /settings /doctor /lock /sleep /logout /reboot /power /reload
//   2+2*3 or =    calculator (Enter copies)      ?text   web search (?w ?aw ?gh ... shortcuts, engine in /settings)      :smile   emoji
// ↑/↓ (or Ctrl+N/P) move · Tab complete · Enter run · Esc back/close
// Dangerous commands (power, reboot, logout) need Enter twice.
PanelWindow {
    id: win

    property bool open: false
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }

    property string mode: "root"          // root | scheme | wallpaper | clip | music | windows | kill | todo | emoji | network | bluetooth | control | keys | doctor
    property string query: ""
    property int index: 0
    // Where the mouse really was at the last hover event (window coordinates). Rows move under a resting
    // cursor when the list scrolls, and Qt then reports a synthetic "move"; comparing positions tells the two apart.
    property point lastMouse: Qt.point(-1, -1)
    property string armed: ""
    property string originalTheme: ""
    property var wallpapers: []
    property var procs: []                // /kill: running processes of this user
    property var clips: []                // clipboard history (cliphist), newest first
    property bool clipOK: false           // cliphist + wl-clipboard are installed
    property bool watch: false            // clipboard watchers may start
    property bool thumbsReady: false      // image thumbnails for /clip are decoded
    readonly property string clipThumbDir: Quickshell.env("XDG_RUNTIME_DIR") + "/lovelyrice-clip"
    signal calendarRequested()
    signal settingsRequested()
    signal lockRequested()
    signal schemeMakerRequested()
    signal overviewRequested()
    signal dashboardRequested()
    property string pendingSsid: ""
    onOpenChanged: Popups.report("palette", open)
    Connections {
        target: Popups
        function onCloseOthers(except) { if (except !== "palette" && win.open) win.dismiss() }
        function onCloseAll() { if (win.open) win.dismiss() }
    }

    readonly property var commands: [
        { kind: "cmd", id: "scheme",    name: "scheme",    icon: "◐", desc: "Change color scheme",  sub: true, keywords: "theme colors" },
        { kind: "cmd", id: "wallpaper", name: "wallpaper", icon: "▣", desc: "Change wallpaper",     sub: true, keywords: "background image" },
        { kind: "cmd", id: "clip",      name: "clip",      icon: "▤", desc: "Clipboard history",    sub: true, keywords: "clipboard paste history copy" },
        { kind: "cmd", id: "music",     name: "music",     icon: "♪", desc: "Now playing and controls (ldmp, Spotify, ...)", sub: true, keywords: "player song ldmp play pause next" },
        { kind: "cmd", id: "windows",   name: "windows",   icon: "❐", desc: "Jump to any open window", sub: true, keywords: "switch window focus alt tab" },
        { kind: "cmd", id: "todo",      name: "todo",      icon: "☐", desc: "Quick task list", sub: true, keywords: "tasks checklist" },
        { kind: "cmd", id: "emoji",     name: "emoji",     icon: "☺", desc: "Emoji picker (or type :)", sub: true, keywords: "emoticon smiley" },
        { kind: "cmd", id: "kill",      name: "kill",      icon: "✕", desc: "End a running process", sub: true, keywords: "process quit terminate task manager" },
        { kind: "cmd", id: "timer",     name: "timer",     icon: "◷", desc: "Countdown, e.g. /timer 10m tea", special: "timerhelp", keywords: "countdown alarm" },
        { kind: "cmd", id: "screenshot", name: "screenshot", icon: "▢", desc: "Select a region; saves, copies and notifies", special: "shot-region", keywords: "capture screen grab" },
        { kind: "cmd", id: "screenshot-full", name: "screenshot-full", icon: "▭", desc: "Screenshot of the whole screen", special: "shot-screen", keywords: "capture screen grab" },
        { kind: "cmd", id: "record",    name: "record",    icon: "●", desc: "Record the screen (wf-recorder)", special: "rec-screen", keywords: "screencast video capture" },
        { kind: "cmd", id: "record-region", name: "record-region", icon: "◍", desc: "Record a selected region", special: "rec-region", keywords: "screencast video capture" },
        { kind: "cmd", id: "calendar",  name: "calendar",  icon: "▦", desc: "Month view and agenda (Google Calendar via iCal)",
          special: "calendar", keywords: "agenda events google date schedule" },
        { kind: "cmd", id: "settings",  name: "settings",  icon: "⚙", desc: "Sidebar contents, size and more",
          special: "settings", keywords: "preferences config options sidebar" },
        { kind: "cmd", id: "overview",  name: "overview",  icon: "▦", desc: "All workspaces with live window previews", special: "overview", keywords: "workspaces windows expose mission tab" },
        { kind: "cmd", id: "dashboard", name: "dashboard", icon: "◫", desc: "Weather, resource graphs and a mini calendar", special: "dashboard", keywords: "weather cpu memory network graphs calendar" },
        { kind: "cmd", id: "keys",      name: "keys",      icon: "⌨", desc: "Cheat sheet of your Hyprland keybinds", sub: true, keywords: "keybinds shortcuts bindings hotkeys help" },
        { kind: "cmd", id: "control",   name: "control",   icon: "☰", desc: "Quick settings: audio devices, mic, do-not-disturb, power profile", sub: true, keywords: "quick settings audio output input microphone mic mute dnd notifications power profile performance sound speaker headphones" },
        { kind: "cmd", id: "network",   name: "network",   icon: "≋", desc: "Wi-Fi networks and connection", sub: true, keywords: "wifi wi-fi internet ethernet wireless" },
        { kind: "cmd", id: "bluetooth", name: "bluetooth", icon: "ᛒ", desc: "Bluetooth devices", sub: true, keywords: "bt headphones speaker pair" },
        { kind: "cmd", id: "doctor",    name: "doctor",    icon: "✚", desc: "Check which optional tools are installed", sub: true, keywords: "check tools dependencies missing install packages health" },
        { kind: "cmd", id: "match-wallpaper", name: "match-wallpaper", icon: "◐", desc: "Make a colour scheme from the current wallpaper", special: "matchwp", keywords: "theme colors palette generate wallpaper accent" },
        { kind: "cmd", id: "sync-apps", name: "sync-apps", icon: "⟳", desc: "Re-apply the theme to GTK apps, foot and fastfetch", special: "syncapps", keywords: "theme colors gtk foot terminal fastfetch hooks refresh" },
        { kind: "cmd", id: "scheme-maker", name: "scheme-maker", icon: "✎", desc: "Create your own colour scheme", special: "schememaker", keywords: "theme colors custom create editor" },
        { kind: "cmd", id: "lock",      name: "lock",      icon: "◉", desc: "Lock the screen",
          special: "lock" },
        { kind: "cmd", id: "sleep",     name: "sleep",     icon: "☾", desc: "Suspend to RAM",       keywords: "suspend",
          special: "sleep" },
        { kind: "cmd", id: "logout",    name: "logout",    icon: "⇥", desc: "Exit Hyprland",        confirm: true, keywords: "exit",
          cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { kind: "cmd", id: "reboot",    name: "reboot",    icon: "↻", desc: "Restart the computer", confirm: true, keywords: "restart",
          cmd: ["systemctl", "reboot"] },
        { kind: "cmd", id: "power",     name: "power",     icon: "⏻", desc: "Power off",            confirm: true, keywords: "shutdown poweroff off",
          cmd: ["systemctl", "poweroff"] },
        { kind: "cmd", id: "reload",    name: "reload",    icon: "⟳", desc: "Reload LovelyRice",    special: "reload" }
    ]

    function basename(p) { return p.split("/").pop() }

    // ---- clipboard history ----
    function parseClips(text) {
        const out = []
        let bins = 0
        for (const line of text.split("\n")) {
            const t = line.indexOf("\t")
            if (t < 0) continue
            const body = line.slice(t + 1)
            const m = body.match(/^\[\[ binary data (.*) \]\]$/)
            out.push({ id: line.slice(0, t), raw: line, binary: !!m, label: m ? m[1] : body,
                       thumb: !!m && bins++ < 12 })      // only the 12 newest images get thumbnails
        }
        return out
    }
    function loadClips() {
        thumbsReady = false
        if (!clipOK) { clips = []; return }
        clipLister.running = true
    }
    function copyClip(it) {
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\n" "$1" | cliphist decode | wl-copy', "sh", it.raw])
    }
    function deleteClip() {
        const it = items[index]
        if (!it || it.kind !== "clip") return
        clipDeleter.command = ["sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", it.raw]
        clipDeleter.running = true
        clips = clips.filter(c => c.id !== it.id)
        index = Math.min(index, Math.max(0, items.length - 1))
    }

    // ---- /music ----
    function musicItems(raw) {
        const out = []
        if (!Music.player) {
            out.push({ kind: "info", id: "nomusic", glyph: "♪", name: "No player running", desc: "Start ldmp or any MPRIS player" })
        } else {
            out.push({ kind: "info", id: "np", glyph: "♪", name: Music.title || "Unknown track",
                       desc: (Music.artist ? Music.artist + "  ·  " : "") + (Music.playing ? "playing" : "paused") + "  ·  " + Music.identity })
            out.push({ kind: "music", id: "toggle", glyph: Music.playing ? "❚❚" : "▶", name: Music.playing ? "Pause" : "Play", desc: "" })
            out.push({ kind: "music", id: "next", glyph: "»", name: "Next track", desc: "" })
            out.push({ kind: "music", id: "prev", glyph: "«", name: "Previous track", desc: "" })
            out.push({ kind: "music", id: "back", glyph: "−10", name: "Back 10 seconds", desc: "" })
            out.push({ kind: "music", id: "fwd",  glyph: "+10", name: "Forward 10 seconds", desc: "" })
            if (Music.shuffleSupported)
                out.push({ kind: "music", id: "shuffle", glyph: "⇄", name: "Shuffle: " + (Music.shuffle ? "on" : "off"), desc: "Enter turns it " + (Music.shuffle ? "off" : "on") })
            if (Music.loopSupported)
                out.push({ kind: "music", id: "repeat", glyph: Music.repeat === "track" ? "↻1" : "↻",
                           name: "Repeat: " + (Music.repeat === "track" ? "one track" : (Music.repeat === "playlist" ? "all" : "off")),
                           desc: "Enter: off → all → one" })
            if (Music.volumeSupported) {
                out.push({ kind: "music", id: "volup",   glyph: "+", name: "Volume up",   desc: "now " + Music.volumePercent + "%" })
                out.push({ kind: "music", id: "voldown", glyph: "−", name: "Volume down", desc: "now " + Music.volumePercent + "%" })
            }
        }
        out.push({ kind: "music", id: "open", glyph: "♫", name: "Open ldmp", desc: "Terminal music player" })
        return out.filter(x => raw === "" || Fuzzy.score(raw, x.name) >= 0)
    }
    function musicAction(id) {
        if (id === "toggle") Music.toggle()
        else if (id === "next") Music.next()
        else if (id === "prev") Music.prev()
        else if (id === "back") Music.seek(-10)
        else if (id === "fwd")  Music.seek(10)
        else if (id === "shuffle") Music.toggleShuffle()
        else if (id === "repeat")  Music.cycleRepeat()
        else if (id === "volup")   Music.changeVolume(0.05)
        else if (id === "voldown") Music.changeVolume(-0.05)
        else if (id === "open") { Music.openLdmp(); closePalette() }
    }

    // ---- /windows ----
    function windowItems(raw) {
        const out = []
        const tl = Hyprland.toplevels.values
        for (let i = 0; i < tl.length; i++) {
            const t = tl[i]
            const ipc = t.lastIpcObject || {}
            const cls = ipc.class || "", title = t.title || ipc.title || ""
            let addr = String(t.address || "")
            if (addr === "") continue
            if (addr.indexOf("0x") !== 0) addr = "0x" + addr
            if (raw !== "" && Fuzzy.score(raw, title + " " + cls) < 0) continue
            const ws = t.workspace ? String(t.workspace.name || "") : ""
            out.push({ kind: "win", id: addr, address: addr, catKind: AppCategory.kindFor(cls), name: title || cls || "(untitled)",
                       desc: cls + (ws ? "  ·  " + (ws.indexOf("special:") === 0 ? "special " + ws.slice(8) : "workspace " + ws) : "") })
        }
        if (out.length === 0) out.push({ kind: "info", id: "nowin", name: raw === "" ? "No windows open" : "No matches", desc: "" })
        return out
    }

    // ---- /kill ----
    function loadProcs() { procLister.running = true }
    function procItems(raw) {
        const out = []
        for (const p of procs) {
            if (raw !== "" && Fuzzy.score(raw, p.comm + " " + p.pid) < 0) continue
            out.push({ kind: "proc", id: p.pid, confirm: true, glyph: "✕", name: p.comm,
                       desc: "pid " + p.pid + "  ·  cpu " + p.cpu + "%  ·  mem " + p.mem + "%" })
        }
        if (out.length === 0) out.push({ kind: "info", id: "noproc", name: procs.length === 0 ? "Loading…" : "No matches", desc: "" })
        return out
    }

    // ---- /todo ----
    function todoItems(raw) {
        const out = []
        const text = query.trim()
        if (text !== "") out.push({ kind: "todoadd", id: "add", glyph: "+", name: "Add: " + text, desc: "Enter adds it to the list" })
        const open = Todos.items.filter(t => !t.done), done = Todos.items.filter(t => t.done)
        for (const t of open.concat(done)) {
            if (raw !== "" && Fuzzy.score(raw, t.text) < 0) continue
            out.push({ kind: "todo", id: t.id, glyph: t.done ? "✔" : "○", name: t.text, desc: t.done ? "done  ·  Enter to undo" : "Enter marks it done" })
        }
        if (done.length > 0 && raw === "") out.push({ kind: "todoclear", id: "clear", glyph: "⌫", name: "Clear completed", desc: "" })
        if (out.length === 0) out.push({ kind: "info", id: "notodo", glyph: "☐", name: "Nothing to do", desc: "Type a task and press Enter" })
        return out
    }
    function deleteTodo() {
        const it = items[index]
        if (!it || it.kind !== "todo") return
        Todos.remove(it.id)
        index = Math.min(index, Math.max(0, items.length - 1))
    }

    // ---- /emoji ----
    function emojiItems(raw) {
        const list = EmojiData.list
        const out = []
        for (let i = 0; i < list.length && out.length < 80; i++)
            if (raw === "" || list[i][1].indexOf(raw) >= 0)
                out.push({ kind: "emoji", id: "e" + i, glyph: list[i][0], name: list[i][1].split(" ").slice(0, 6).join(" "), desc: "Enter copies it" })
        if (out.length === 0) out.push({ kind: "info", id: "noemoji", name: "No emoji matches", desc: "" })
        return out
    }

    // ---- /timer ----
    function timerItems(arg) {
        const out = []
        const m = arg.trim().match(/^(\S+)\s*(.*)$/)
        if (m) {
            const ms = Timers.parse(m[1])
            if (ms > 0) out.push({ kind: "timernew", id: "new", glyph: "◷", name: "Start " + Timers.format(ms) + (m[2] ? "  —  " + m[2] : ""),
                                   desc: "Notifies when it ends", ms: ms, label: m[2] })
            else out.push({ kind: "info", id: "badtimer", name: "Can't read “" + m[1] + "”", desc: "Try 10m, 1h30m, 90s or 25 (minutes)" })
        } else {
            out.push({ kind: "info", id: "timerhelp", glyph: "◷", name: "Type a duration", desc: "/timer 10m tea   ·   1h30m   ·   90s   ·   25 = minutes" })
        }
        for (const t of Timers.timers)
            out.push({ kind: "timer", id: "t" + t.id, tid: t.id, glyph: "◷", name: t.label || "Timer",
                       desc: "ends " + Qt.formatTime(new Date(t.end), "HH:mm:ss") + "  ·  Enter cancels" })
        return out
    }

    // ---- calculator: "2+2*3", "= sqrt(2)" ----
    function calcRow(q) {
        let s = q.trim()
        const explicit = s.startsWith("=")
        if (explicit) s = s.slice(1).trim()
        else if (!Settings.calcAuto || !/^[\d\s.,+\-*\/^%()×÷]+$/.test(s) || !/[\d)]\s*[+\-*\/^%×÷]\s*[\d(.]/.test(s)) return null
        if (s === "") return explicit ? { kind: "info", id: "calchelp", glyph: "=", name: "Type a calculation", desc: "2+2*3   sqrt(16)   (1+2)^3   pi*2" } : null
        const v = Calc.evaluate(s)
        if (v === null) return explicit ? { kind: "info", id: "calcbad", glyph: "=", name: "Can't calculate that", desc: s } : null
        const str = String(Number(v.toPrecision(12)))
        return { kind: "calc", id: "calc", glyph: "=", name: str, value: str, desc: s + "   ·   Enter copies" }
    }
    function copyText(s) { Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", s]) }

    // ---- /network ----
    function netItems(raw) {
        const out = []
        out.push({ kind: "nettoggle", id: "wifi", glyph: Net.wifiEnabled ? "◉" : "○", name: "Wi-Fi " + (Net.wifiEnabled ? "on" : "off"),
                   desc: "Enter turns it " + (Net.wifiEnabled ? "off" : "on") })
        if (Net.connType === "ethernet")
            out.push({ kind: "info", id: "eth", iconKind: "ethernet", name: "Wired connection", desc: "Connected" })
        if (Net.wifiEnabled) {
            out.push({ kind: "netscan", id: "scan", glyph: "↻", name: Net.scanning ? "Scanning…" : "Rescan networks", desc: "" })
            for (const n of Net.networks) {
                if (raw !== "" && Fuzzy.score(raw, n.ssid) < 0) continue
                out.push({ kind: "net", id: "n:" + n.ssid, iconKind: "wifi", iconLevel: n.signal / 100, net: n, name: n.ssid,
                           desc: (n.active ? "connected  ·  Enter disconnects" : (n.known ? "saved" : (n.security === "" ? "open" : n.security)))
                                 + "  ·  " + n.signal + "%" })
            }
            if (Net.networks.length === 0 && !Net.scanning)
                out.push({ kind: "info", id: "nonet", name: "No networks found", desc: "Try rescanning" })
        }
        return raw === "" ? out : out.filter(x => x.kind === "net" || Fuzzy.score(raw, x.name) >= 0)
    }
    function netPassItems() {
        return [{ kind: "netconnect", id: "go", glyph: "→", name: "Connect to " + pendingSsid, desc: "Type the password above, then press Enter" }]
    }

    // ---- /bluetooth ----
    function btItems(raw) {
        if (!Bt.available) return [{ kind: "info", id: "nobt", glyph: "ᛒ", name: "No Bluetooth adapter found", desc: "Is bluetooth.service running?" }]
        const out = []
        out.push({ kind: "bttoggle", id: "pwr", glyph: Bt.powered ? "◉" : "○", name: "Bluetooth " + (Bt.powered ? "on" : "off"),
                   desc: "Enter turns it " + (Bt.powered ? "off" : "on") })
        if (Bt.powered) {
            out.push({ kind: "btscan", id: "scan", glyph: "↻", name: Bt.scanning ? "Scanning…" : "Scan for devices", desc: "" })
            for (const d of Bt.devices) {
                if (raw !== "" && Fuzzy.score(raw, d.name) < 0) continue
                out.push({ kind: "btdev", id: "d:" + d.mac, iconKind: "bluetooth", dev: d, name: d.name,
                           desc: d.connected ? "connected  ·  Enter disconnects" : (d.paired ? "paired  ·  Enter connects" : "new device  ·  Enter pairs") })
            }
        }
        return raw === "" ? out : out.filter(x => x.kind === "btdev" || Fuzzy.score(raw, x.name) >= 0)
    }
    // ---- /keys: read from the running compositor, so it always matches your real config ----
    property var binds: []
    Process {
        id: bindsProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { win.binds = JSON.parse(text) } catch (e) { win.binds = [] } }
        }
    }
    function bindCombo(b) {
        const m = b.modmask || 0, parts = []
        if (m & 64) parts.push("SUPER")
        if (m & 4) parts.push("CTRL")
        if (m & 8) parts.push("ALT")
        if (m & 1) parts.push("SHIFT")
        parts.push(b.key && b.key !== "" ? b.key : "code:" + b.keycode)
        return (b.submap ? "[" + b.submap + "] " : "") + parts.join(" + ")
    }
    function bindAction(b) {
        if (b.description) return b.description
        const arg = b.arg ? String(b.arg) : ""
        if (b.dispatcher === "global") return arg.replace(":", "  →  ")
        return (b.dispatcher || "") + (arg !== "" ? " " + arg : "")
    }
    function keyItems(raw) {
        const out = []
        for (let i = 0; i < binds.length; i++) {
            const combo = bindCombo(binds[i]), act = bindAction(binds[i])
            if (raw !== "" && Fuzzy.score(raw, combo + " " + act) < 0) continue
            out.push({ kind: "info", id: "k" + i, glyph: "⌨", name: combo, desc: act })
        }
        out.sort((a, b) => a.name < b.name ? -1 : (a.name > b.name ? 1 : 0))
        if (out.length === 0)
            out.push({ kind: "info", id: "nokeys", name: raw === "" ? "No binds found" : "No matches", desc: raw === "" ? "hyprctl binds returned nothing" : "" })
        return out
    }

    // ---- /doctor: which tools are installed, what each one enables ----
    function doctorItems(raw) {
        const out = []
        if (!Doctor.loaded) return [{ kind: "info", id: "docload", glyph: "…", name: "Checking…", desc: "" }]
        const miss = Doctor.missing.length
        if (raw === "") {
            if (miss === 0)
                out.push({ kind: "info", id: "docok", glyph: "✓", name: "Everything LovelyRice can use is installed", desc: Doctor.items.length + " tools checked" })
            else {
                if (Doctor.installCommand !== "")
                    out.push({ kind: "doctorall", id: "docall", glyph: "⧉", name: "Copy the install command for all " + Doctor.installable.length + " missing packages",
                               desc: Doctor.installCommand })
                out.push({ kind: "doctorrecheck", id: "docre", glyph: "↻", name: "Check again", desc: "after installing something" })
            }
        }
        for (const i of Doctor.items) {
            const label = Doctor.name(i)
            if (raw !== "" && Fuzzy.score(raw, label + " " + i.pkg + " " + i.feature) < 0) continue
            out.push({ kind: i.ok ? "info" : "doctortool", id: "dt:" + i.cmd, tool: i, glyph: i.ok ? "✓" : "✗",
                       name: label + (i.required ? "  (required)" : ""),
                       desc: i.feature + (i.ok ? "" : (i.pkg !== "-" ? "  ·  Enter copies: sudo pacman -S --needed " + i.pkg : "  ·  install it yourself")) })
        }
        if (out.length === 0) out.push({ kind: "info", id: "docnone", name: "No matches", desc: "" })
        return out
    }

    // ---- /control ----
    function controlItems(raw) {
        const out = []
        out.push({ kind: "ctl", act: "dnd", id: "dnd", glyph: Notifs.dnd ? "◉" : "○",
                   name: "Do not disturb  " + (Notifs.dnd ? "on" : "off"),
                   desc: "Hides notification popups, critical ones still show  ·  Enter turns it " + (Notifs.dnd ? "off" : "on") })
        if (Control.micAvailable)
            out.push({ kind: "ctl", act: "mic", id: "mic", iconKind: Control.micMuted ? "mic-off" : "mic",
                       name: "Microphone  " + (Control.micMuted ? "muted" : "live"),
                       desc: "Enter " + (Control.micMuted ? "unmutes" : "mutes") + " the default input" })
        if (Control.profiles.length > 0)
            out.push({ kind: "ctl", act: "profile", id: "profile", glyph: "◈",
                       name: "Power profile  " + (Control.profile || "unknown"),
                       desc: "Enter cycles: " + Control.profiles.join(" → ") })
        for (const n of Control.sinks) {
            const cur = Control.isDefaultSink(n)
            out.push({ kind: "ctl", act: "sink", id: "o:" + n.id, node: n, iconKind: "volume", iconLevel: 1,
                       name: Control.label(n), desc: "output  ·  " + (cur ? "current" : "Enter makes it the default") })
        }
        for (const n of Control.sources) {
            const cur = Control.isDefaultSource(n)
            out.push({ kind: "ctl", act: "source", id: "i:" + n.id, node: n, iconKind: "mic",
                       name: Control.label(n), desc: "input  ·  " + (cur ? "current" : "Enter makes it the default") })
        }
        for (const app of Notifs.mutedApps)
            out.push({ kind: "ctl", act: "unmute", id: "m:" + app, app: app, iconKind: "bell-off",
                       name: "Unmute " + app, desc: "popups from this app are muted  ·  Enter unmutes" })
        return raw === "" ? out : out.filter(x => Fuzzy.match(raw, x.name, x.desc) >= 0)
    }

    function forgetSelected() {
        const it = items[index]
        if (!it) return
        if (it.kind === "net" && it.net.known) Net.forget(it.net.ssid)
        else if (it.kind === "btdev" && it.dev.paired) Bt.forget(it.dev)
    }

    function appItems(q) {
        const out = []
        const apps = DesktopEntries.applications.values
        for (let i = 0; i < apps.length; i++) {
            const a = apps[i]
            if (a.noDisplay) continue
            const name = a.name || ""
            const nl = name.toLowerCase()
            const extra = ((a.genericName || "") + " " + (a.comment || "")).toLowerCase()
            const score = Fuzzy.match(q, name, extra)
            if (score < 0) continue
            out.push({ kind: "app", id: a.id, name: name, desc: a.genericName || a.comment || "",
                       icon: a.icon, entry: a, score: score, uses: Settings.rankApps ? (Usage.counts[a.id] || 0) : 0 })
        }
        // launch history nudges the order (up to +80) without overriding a clearly better match
        const rank = x => x.score + Math.min(x.uses, 20) * 4
        out.sort((x, y) => (rank(y) - rank(x)) || x.name.localeCompare(y.name))
        return out.slice(0, 60)
    }

    function compute() {
        const raw = query.trim().toLowerCase()
        if (mode === "scheme") {
            return Theme.available.map(n => ({ n: n, sc: Fuzzy.score(raw, n) })).filter(x => x.sc >= 0)
                .sort((x, y) => raw === "" ? 0 : y.sc - x.sc)
                .map(x => ({ kind: "scheme", id: x.n, name: x.n, desc: x.n === originalTheme ? "current" : "" }))
        }
        if (mode === "wallpaper") {
            const out = [{ kind: "wp", id: "", path: "", name: "Theme default", desc: "Generated from the theme colors" }]
            for (const p of wallpapers) {
                const n = basename(p)
                if (Fuzzy.score(raw, n) >= 0) out.push({ kind: "wp", id: p, path: p, name: n, desc: "" })
            }
            if (wallpapers.length === 0)
                out.push({ kind: "info", id: "none", name: "No wallpapers found", desc: "Put images in ~/Pictures/Wallpapers" })
            return out
        }
        if (mode === "clip") {
            if (!clipOK)
                return [{ kind: "info", id: "noclip", name: "cliphist is not installed", desc: "sudo pacman -S cliphist wl-clipboard" }]
            const out = []
            for (const c of clips) {
                if (raw !== "" && Fuzzy.score(raw, c.label) < 0) continue
                out.push({ kind: "clip", id: c.id, raw: c.raw, binary: c.binary,
                           thumb: c.binary && c.thumb && thumbsReady ? clipThumbDir + "/" + c.id : "",
                           name: c.binary ? "Image" : (c.label.replace(/\s+/g, " ").trim() || "(blank)"),
                           desc: c.binary ? c.label : "" })
            }
            if (out.length === 0)
                out.push({ kind: "info", id: "noclips", name: raw === "" ? "Clipboard history is empty" : "No matches",
                           desc: raw === "" ? "Copy something. History records while LovelyRice is running" : "" })
            return out.slice(0, 100)
        }
        if (mode === "music")   return musicItems(raw)
        if (mode === "windows") return windowItems(raw)
        if (mode === "kill")    return procItems(raw)
        if (mode === "todo")    return todoItems(raw)
        if (mode === "emoji")   return emojiItems(raw)
        if (mode === "network") return netItems(raw)
        if (mode === "netpass") return netPassItems()
        if (mode === "bluetooth") return btItems(raw)
        if (mode === "control") return controlItems(raw)
        if (mode === "keys") return keyItems(raw)
        if (mode === "doctor") return doctorItems(raw)
        const tm = query.replace(/^\s+/, "").match(/^\/timer\s+(.*)$/i)
        if (tm) return timerItems(tm[1])
        if (raw.startsWith("?")) {
            const t = query.trim().slice(1).trim()
            const r = Search.resolve(t)
            if (!r) return [{ kind: "info", id: "webhelp", glyph: "↗", name: "Type what to search for",
                              desc: "?arch wiki hyprland   ·   ?aw hyprland (Arch wiki)   ·   ?w, ?gh, ?yt, ?aur, ?g" }]
            return [{ kind: "web", id: "web", glyph: "↗", name: "Search " + r.label + " for “" + r.text + "”", desc: "Opens in your browser", url: r.url }]
        }
        if (raw.startsWith("/")) {
            const q = raw.slice(1)
            let cmds = commands
            if (Recorder.active)
                cmds = commands.filter(c => c.id !== "record" && c.id !== "record-region")
                    .concat([{ kind: "cmd", id: "record-stop", name: "record", icon: "■", desc: "Stop recording and save the video", special: "rec-stop" }])
            const list = cmds.map(c => ({ c: c, sc: Fuzzy.match(q, c.name, (c.keywords || "") + " " + c.desc) }))
                             .filter(x => x.sc >= 0)
            if (q !== "") list.sort((x, y) => y.sc - x.sc)
            return list.map(x => x.c)
        }
        const calc = calcRow(query)
        const apps = appItems(raw)
        return calc ? [calc].concat(apps) : apps
    }
    property var items: compute()

    function preview() {
        if (mode === "scheme" && items[index]) Theme.select(items[index].id)
    }
    onIndexChanged: preview()

    function openWith(startMode) {
        Popups.claim("palette")
        originalTheme = Theme.name
        mode = "root"; query = ""; input.text = ""; index = 0; armed = ""; lastMouse = Qt.point(-1, -1)
        open = true
        input.forceActiveFocus()
        if (startMode) enter(startMode)
    }
    function closePalette() { open = false; input.focus = false }
    function toggle() { open ? dismiss() : openWith("") }

    function enter(m) {
        mode = m
        input.text = ""; query = ""; armed = ""
        originalTheme = Theme.name
        if (m === "wallpaper") wpLister.running = true
        if (m === "clip") loadClips()
        if (m === "kill") loadProcs()
        if (m === "windows") Hyprland.refreshToplevels()
        if (m === "network") { Net.refresh(); Net.scan() }
        if (m === "bluetooth") { Bt.refresh(); Bt.scan() }
        if (m === "control") Control.refresh()
        if (m === "keys") bindsProc.running = true
        if (m === "doctor") Doctor.refresh()
        index = m === "scheme" ? Math.max(0, items.findIndex(i => i.id === Theme.name)) : (m === "music" && Music.player ? 1 : 0)
        preview()
    }
    function back() { mode = "root"; input.text = ""; query = ""; index = 0; armed = "" }
    function cancelSub() {
        if (mode === "netpass") { enter("network"); return }
        if (mode === "scheme") Theme.select(originalTheme)
        back()
    }
    function dismiss() {
        if (mode === "scheme") Theme.select(originalTheme)
        closePalette()
    }
    function goBack() { mode === "root" ? closePalette() : cancelSub() }

    function move(d) {
        const n = items.length
        if (n === 0) return
        armed = ""
        index = (index + d + n) % n
    }

    function activate() {
        const it = items[index]
        if (!it) return
        if (it.kind === "cmd") {
            if (it.sub) { enter(it.id); return }
            if (it.confirm && armed !== it.id) { armed = it.id; return }
            if (it.special === "reload") Quickshell.reload(true)
            else if (it.special === "calendar") { closePalette(); calendarRequested(); return }
            else if (it.special === "settings") { closePalette(); settingsRequested(); return }
            else if (it.special === "lock") { closePalette(); lockRequested(); return }
            else if (it.special === "shot-region") { closePalette(); Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/screenshot.sh"), "region"]); return }
            else if (it.special === "shot-screen") { closePalette(); Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/screenshot.sh"), "screen"]); return }
            else if (it.special === "rec-screen")  { closePalette(); Recorder.start(false); return }
            else if (it.special === "rec-region")  { closePalette(); Recorder.start(true); return }
            else if (it.special === "rec-stop")    { closePalette(); Recorder.stop(); return }
            else if (it.special === "timerhelp")   { input.text = "/timer "; return }
            else if (it.special === "sleep")       { closePalette(); Session.sleep(); return }
            else if (it.special === "schememaker") { closePalette(); schemeMakerRequested(); return }
            else if (it.special === "matchwp") { closePalette(); WallpaperColors.apply(); return }
            else if (it.special === "syncapps") { closePalette(); Hooks.runNow(); return }
            else if (it.special === "overview") { closePalette(); overviewRequested(); return }
            else if (it.special === "dashboard") { closePalette(); dashboardRequested(); return }
            else Quickshell.execDetached(it.cmd)
            closePalette()
        } else if (it.kind === "calc" || it.kind === "emoji") {
            copyText(it.kind === "calc" ? it.value : it.glyph); closePalette()
        } else if (it.kind === "web") {
            Quickshell.execDetached(["xdg-open", it.url]); closePalette()
        } else if (it.kind === "win") {
            Popups.exempt()                       // focusing a window in a special workspace may open it; allow that
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' + it.address + '" })'])
            closePalette()
        } else if (it.kind === "proc") {
            if (armed !== it.id) { armed = it.id; return }
            Quickshell.execDetached(["kill", it.id])
            procs = procs.filter(p => p.pid !== it.id); armed = ""
        } else if (it.kind === "todoadd") {
            Todos.add(query.trim()); input.text = ""
        } else if (it.kind === "todo") {
            Todos.toggle(it.id)
        } else if (it.kind === "todoclear") {
            Todos.clearDone()
        } else if (it.kind === "music") {
            musicAction(it.id)
        } else if (it.kind === "timernew") {
            Timers.add(it.label, it.ms); closePalette()
        } else if (it.kind === "timer") {
            Timers.cancel(it.tid)
        } else if (it.kind === "nettoggle") {
            Net.setWifi(!Net.wifiEnabled)
        } else if (it.kind === "netscan") {
            Net.scan()
        } else if (it.kind === "net") {
            if (it.net.active) Net.disconnectWifi()
            else if (it.net.known || it.net.security === "") { Net.connect(it.net.ssid, ""); closePalette() }
            else { pendingSsid = it.net.ssid; enter("netpass") }
        } else if (it.kind === "netconnect") {
            Net.connect(pendingSsid, input.text); closePalette()
        } else if (it.kind === "bttoggle") {
            Bt.setPower(!Bt.powered)
        } else if (it.kind === "btscan") {
            Bt.scan()
        } else if (it.kind === "btdev") {
            if (it.dev.connected) Bt.disconnectDevice(it.dev); else Bt.connect(it.dev)
        } else if (it.kind === "doctortool") {
            if (it.tool.pkg !== "-") { Doctor.copy("sudo pacman -S --needed " + it.tool.pkg); closePalette() }
        } else if (it.kind === "doctorall") {
            Doctor.copy(Doctor.installCommand); closePalette()
        } else if (it.kind === "doctorrecheck") {
            Doctor.refresh()
        } else if (it.kind === "ctl") {
            if (it.act === "dnd") Notifs.dnd = !Notifs.dnd
            else if (it.act === "mic") Control.toggleMic()
            else if (it.act === "profile") Control.cycleProfile()
            else if (it.act === "sink") Control.setSink(it.node)
            else if (it.act === "source") Control.setSource(it.node)
            else if (it.act === "unmute") Notifs.unmute(it.app)
        } else if (it.kind === "app") {
            Usage.bump(it.id)
            it.entry.execute()
            closePalette()
        } else if (it.kind === "scheme") {
            Theme.select(it.id); Theme.save(); closePalette()
        } else if (it.kind === "wp") {
            Theme.setWallpaper(it.path); closePalette()
        } else if (it.kind === "clip") {
            copyClip(it); closePalette()
        }
    }

    function complete() {
        const it = items[index]
        if (!it || mode !== "root") return
        if (it.kind === "cmd") { it.sub ? enter(it.id) : (input.text = "/" + it.name + (it.special === "timerhelp" ? " " : "")) }
        else if (it.kind === "app") input.text = it.name
    }

    visible: progress > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lovelyrice-palette"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Process {
        id: wpLister
        command: ["sh", "-c",
            'for d in "$@"; do [ -d "$d" ] && find "$d" -maxdepth 2 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\); done | sort',
            "sh"].concat(Theme.wallpaperDirs)
        stdout: StdioCollector {
            onStreamFinished: win.wallpapers = text.split("\n").filter(s => s.length > 0)
        }
    }

    // ---- clipboard history: cliphist stores everything copied while the shell runs ----
    Process {   // are the tools installed?
        running: true
        command: ["sh", "-c", "command -v cliphist && command -v wl-copy && command -v wl-paste"]
        onExited: code => { if (code === 0) { win.clipOK = true; clipCleaner.running = true } }
    }
    Process {   // stop watchers left over from before a reload, then let ours start
        id: clipCleaner
        command: ["sh", "-c", "pkill -f 'wl-paste --type text --watc[h] cliphist store'; pkill -f 'wl-paste --type image --watc[h] cliphist store'; true"]
        onExited: win.watch = true
    }
    Process { running: win.watch; command: ["wl-paste", "--type", "text", "--watch", "cliphist", "store"] }
    Process { running: win.watch; command: ["wl-paste", "--type", "image", "--watch", "cliphist", "store"] }
    Process {
        id: clipLister
        command: ["sh", "-c", "cliphist list | head -n 300"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.clips = win.parseClips(text)
                const lines = win.clips.filter(c => c.thumb).map(c => c.raw)
                if (lines.length > 0) {
                    clipThumbs.command = ["sh", "-c",
                        'd="$1"; shift; rm -rf "$d"; mkdir -p "$d"; for line in "$@"; do id=$(printf "%s" "$line" | cut -f1); printf "%s\\n" "$line" | cliphist decode > "$d/$id" 2>/dev/null; done',
                        "sh", win.clipThumbDir].concat(lines)
                    clipThumbs.running = true
                }
            }
        }
    }
    Process { id: clipThumbs; onExited: win.thumbsReady = true }
    Process { id: clipDeleter }
    Process {
        id: procLister
        command: ["sh", "-c", 'ps -u "$USER" -o pid=,pcpu=,pmem=,comm= --sort=-pcpu | head -n 80']
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                for (const line of text.split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(\S+)\s+(\S+)\s+(.*)$/)
                    if (m) out.push({ pid: m[1], cpu: m[2], mem: m[3], comm: m[4] })
                }
                win.procs = out
            }
        }
    }

    // dim backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4 * win.progress)
        MouseArea { anchors.fill: parent; onClicked: win.dismiss() }
    }

    Card {
        id: card
        readonly property int listH: Math.min(win.items.length, 7) * 52
        width: 600
        height: 72 + (listH > 0 ? listH + 8 : 0) + 34
        x: (parent.width - width) / 2
        y: parent.height / 2 - 170 + (1 - win.progress) * 18
        opacity: win.progress
        scale: 0.94 + 0.06 * win.progress
        transformOrigin: Item.Center
        radius: Theme.radius + 4
        color: Qt.alpha(Theme.bg, 0.97)
        borderColor: Qt.alpha(Theme.accent, 0.8)
        borderWidth: 2
        shadowY: 18
        Behavior on height { NumberAnimation { duration: Theme.dur(240); easing.type: Easing.OutCubic } }

        // ---- input row ----
        RowLayout {
            x: 22; y: 0; width: parent.width - 44; height: 72
            spacing: 12

            Text {
                text: "❯"
                color: Theme.accent
                font { family: Theme.font; pixelSize: 18; bold: true }
            }
            Rectangle {
                visible: win.mode !== "root"
                implicitWidth: chip.implicitWidth + 18
                implicitHeight: 28
                radius: 14
                color: Qt.alpha(Theme.accent, 0.2)
                Text {
                    id: chip
                    anchors.centerIn: parent
                    text: win.mode === "netpass" ? "password" : "/" + win.mode
                    color: Theme.accent
                    font { family: Theme.font; pixelSize: 13 }
                }
            }
            Item {
                Layout.fillWidth: true
                implicitHeight: 30
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: win.mode === "root" ? "Search apps, or type / for commands"
                          : win.mode === "netpass" ? "Wi-Fi password…"
                          : win.mode === "network" ? "Search networks…"
                          : win.mode === "bluetooth" ? "Search devices…"
                          : win.mode === "control" ? "Search quick settings…"
                          : win.mode === "keys" ? "Search keybinds…"
                          : win.mode === "doctor" ? "Search tools…"
                          : win.mode === "todo" ? "Type a task to add, or filter the list…"
                          : win.mode === "emoji" ? "Search emoji…"
                          : win.mode === "windows" ? "Search open windows…"
                          : win.mode === "kill" ? "Search processes…" : "Search…"
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: 17 }
                }
                TextInput {
                    id: input
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    font { family: Theme.font; pixelSize: 17 }
                    clip: true
                    echoMode: win.mode === "netpass" ? TextInput.Password : TextInput.Normal
                    inputMethodHints: win.mode === "netpass" ? (Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase) : Qt.ImhNone

                    onTextChanged: {
                        const m = text.match(/^\/(scheme|wallpaper|clipboard|clip|music|windows|kill|todo|emoji|network|wifi|bluetooth|bt|control|keys)\s+(.*)$/i)
                        if (win.mode === "root" && m) {
                            win.enter(({ clipboard: "clip", wifi: "network", bt: "bluetooth" })[m[1].toLowerCase()] || m[1].toLowerCase())
                            text = m[2]
                            return
                        }
                        const em = text.match(/^:(.*)$/)
                        if (win.mode === "root" && em) {
                            win.enter("emoji")
                            text = em[1]
                            return
                        }
                        win.query = text
                        win.armed = ""
                        win.index = 0
                        win.preview()
                    }

                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier
                        if (e.key === Qt.Key_Escape)                                win.goBack()
                        else if (e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_N)) win.move(1)
                        else if (e.key === Qt.Key_Up   || (ctrl && e.key === Qt.Key_P)) win.move(-1)
                        else if (e.key === Qt.Key_Tab)                              win.complete()
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) win.activate()
                        else if (e.key === Qt.Key_Backspace && text === "" && win.mode !== "root") win.cancelSub()
                        else if (win.mode === "clip" && (e.key === Qt.Key_Delete || (ctrl && e.key === Qt.Key_D))) win.deleteClip()
                        else if (win.mode === "todo" && (e.key === Qt.Key_Delete || (ctrl && e.key === Qt.Key_D))) win.deleteTodo()
                        else if ((win.mode === "network" || win.mode === "bluetooth") && (e.key === Qt.Key_Delete || (ctrl && e.key === Qt.Key_D))) win.forgetSelected()
                        else return
                        e.accepted = true
                    }
                }
            }
        }

        Rectangle {
            x: 18; y: 72; width: parent.width - 36; height: 1
            color: Qt.alpha(Theme.dim, 0.35)
            visible: card.listH > 0
        }

        // ---- results ----
        ListView {
            id: list
            x: 10; y: 80
            width: parent.width - 20
            height: card.listH
            clip: true
            model: win.items
            currentIndex: win.index
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 160
            highlightMoveVelocity: -1
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            highlight: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.surface
                border.color: Qt.alpha(Theme.accent, 0.5)
                border.width: 1
            }
            populate: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur(200) }
                NumberAnimation { property: "x"; from: 16; duration: Theme.dur(240); easing.type: Easing.OutCubic }
            }

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === win.index
                readonly property bool isArmed: !!modelData.confirm && win.armed === modelData.id
                readonly property string iconPath: modelData.kind === "app" && modelData.icon
                                                   ? Quickshell.iconPath(modelData.icon, true) : ""
                width: ListView.view.width
                height: 52

                // icon area
                Item {
                    x: 12; width: 64; height: 36
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {      // glyph tile (commands, info, apps without icon, "theme default")
                        visible: row.modelData.kind === "cmd" || row.modelData.kind === "info"
                                 || (row.modelData.kind === "wp" && row.modelData.path === "")
                                 || (row.modelData.kind === "app" && row.iconPath === "")
                                 || (row.modelData.kind === "clip" && row.modelData.thumb === "")
                                 || ["calc", "web", "win", "proc", "todo", "todoadd", "todoclear", "emoji", "music", "timer", "timernew"].indexOf(row.modelData.kind) >= 0
                                 || row.modelData.glyph !== undefined || row.modelData.iconKind !== undefined
                        width: 36; height: 36
                        radius: Theme.radiusSmall - 2
                        color: row.isArmed ? Qt.alpha(Theme.warn, 0.25) : Theme.surface
                        CategoryIcon {   // window rows: generic icon for the kind of app
                            anchors.centerIn: parent
                            width: 22; height: 22
                            visible: row.modelData.catKind !== undefined
                            kind: row.modelData.catKind || "window"
                            color: row.sel ? Theme.accent : Theme.fg
                        }
                        Icon {   // network / bluetooth rows
                            anchors.centerIn: parent
                            width: 22; height: 22
                            visible: row.modelData.iconKind !== undefined
                            kind: row.modelData.iconKind || "wifi"
                            level: row.modelData.iconLevel !== undefined ? row.modelData.iconLevel : 1
                            color: row.sel ? Theme.accent : Theme.fg
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: row.modelData.catKind === undefined && row.modelData.iconKind === undefined
                            text: row.modelData.glyph !== undefined ? row.modelData.glyph : row.modelData.icon && row.modelData.kind === "cmd" ? row.modelData.icon
                                  : (row.modelData.kind === "app" ? "▪" : (row.modelData.kind === "wp" ? "◌" : (row.modelData.kind === "clip" ? (row.modelData.binary ? "▨" : "≡") : "…")))
                            color: row.isArmed ? Theme.warn : (row.sel ? Theme.accent : Theme.fg)
                            font { family: Theme.font; pixelSize: 17 }
                        }
                    }
                    Image {          // app icon
                        visible: row.modelData.kind === "app" && row.iconPath !== ""
                        width: 36; height: 36
                        source: visible ? row.iconPath : ""
                        sourceSize: Qt.size(72, 72)
                        asynchronous: true
                        fillMode: Image.PreserveAspectFit
                    }
                    Rectangle {      // scheme swatch
                        visible: row.modelData.kind === "scheme"
                        readonly property var pv: Theme.previews[row.modelData.id]
                        width: 56; height: 30
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 15
                        color: pv ? pv.bg : "#000"
                        border.color: Qt.alpha(Theme.dim, 0.6)
                        Rectangle {
                            x: 6; width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            color: parent.pv ? parent.pv.accent : "#fff"
                        }
                        Rectangle {
                            x: 30; width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            color: parent.pv ? parent.pv.accent2 : "#888"
                        }
                    }
                    RoundedImage {   // wallpaper thumbnail
                        visible: row.modelData.kind === "wp" && row.modelData.path !== ""
                        width: 64; height: 36
                        radius: Theme.radiusSmall - 2
                        source: visible ? "file://" + row.modelData.path : ""
                    }
                    RoundedImage {   // clipboard image thumbnail
                        visible: row.modelData.kind === "clip" && row.modelData.thumb !== ""
                        width: 64; height: 36
                        radius: Theme.radiusSmall - 2
                        source: visible ? "file://" + row.modelData.thumb : ""
                    }
                }

                Column {
                    x: row.modelData.kind === "app" ? 62 : 92
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        textFormat: Text.PlainText
                        text: (row.modelData.kind === "cmd" ? "/" : "") + row.modelData.name
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, 480)
                        color: row.isArmed ? Theme.warn : Theme.fg
                        font { family: Theme.font; pixelSize: 15; bold: row.sel }
                    }
                    Text {
                        visible: text !== ""
                        textFormat: Text.PlainText
                        text: row.isArmed ? "Press Enter again to confirm" : row.modelData.desc
                        color: row.isArmed ? Theme.warn : Theme.dim
                        font { family: Theme.font; pixelSize: 11 }
                        elide: Text.ElideRight
                        width: 440
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onPositionChanged: mouse => {
                        const p = mapToItem(null, mouse.x, mouse.y)
                        const moved = win.lastMouse.x >= 0 && (Math.abs(p.x - win.lastMouse.x) > 1 || Math.abs(p.y - win.lastMouse.y) > 1)
                        win.lastMouse = p
                        if (moved) win.index = row.index       // only a real mouse movement selects; scrolling doesn't
                    }
                    onClicked: { win.index = row.index; win.activate() }
                }
            }
        }

        // ---- footer hints ----
        Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 10 }
            horizontalAlignment: Text.AlignHCenter
            text: win.mode === "root"
                  ? "type to search   / commands   = calc   ? web   : emoji   esc close"
                  : win.mode === "clip" ? "↑↓ navigate   ⏎ copy   ctrl+d delete   esc back"
                  : win.mode === "todo" ? "⏎ add / toggle   ctrl+d delete   esc back"
                  : win.mode === "kill" ? "⏎ twice ends the process   esc back"
                  : win.mode === "music" ? "↑↓ navigate   ⏎ do it   esc back"
                  : win.mode === "doctor" ? "⏎ copy the install command   esc back"
                  : win.mode === "network" ? "⏎ connect   ctrl+d forget   esc back"
                  : win.mode === "bluetooth" ? "⏎ connect / disconnect   ctrl+d remove   esc back"
                  : win.mode === "control" ? "⏎ toggle / select   esc back"
                  : win.mode === "keys" ? "your Hyprland binds (hyprctl binds)   esc back"
                  : win.mode === "netpass" ? "⏎ connect   esc back"
                  : "↑↓ navigate   ⏎ select   esc back"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 10 }
        }
    }
}
