pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Network status and Wi-Fi control through NetworkManager's nmcli.
Singleton {
    id: root
    property bool wifiEnabled: true
    property string connType: ""      // "wifi" | "ethernet" | ""
    property string ssid: ""
    property int signal: 0            // 0-100 of the connected Wi-Fi network
    property string wifiDevice: ""
    property var networks: []         // [{ ssid, signal, security, active, known }]
    property var knownNames: []
    property bool scanning: false
    property bool busy: false
    property string lastSsid: ""

    function notify(title, body) { Quickshell.execDetached(["notify-send", "-a", "Network", title, body || ""]) }
    function refresh() { statusProc.running = true; radioProc.running = true; knownProc.running = true }
    function scan() {
        if (scanning) return
        scanning = true
        listProc.command = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "yes"]
        listProc.running = true
    }
    function loadList() {
        if (listProc.running) return
        listProc.command = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"]
        listProc.running = true
    }
    function setWifi(on) {
        miscProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        miscProc.running = true
        wifiEnabled = on
        later.restart()
    }
    function connect(name, password) {
        busy = true; lastSsid = name
        connProc.environment = ({ LR_PW: password || "" })
        connProc.command = ["sh", "-c",
            'if [ -n "$LR_PW" ]; then nmcli device wifi connect "$1" password "$LR_PW"; ' +
            'elif nmcli -t -f NAME connection show | grep -qxF "$1"; then nmcli connection up id "$1"; ' +
            'else nmcli device wifi connect "$1"; fi', "sh", name]
        connProc.running = true
    }
    function disconnectWifi() {
        if (wifiDevice === "") return
        miscProc.command = ["nmcli", "device", "disconnect", wifiDevice]
        miscProc.running = true
        later.restart()
    }
    function forget(name) {
        miscProc.command = ["nmcli", "connection", "delete", "id", name]
        miscProc.running = true
        later.restart()
    }

    function merge(lines) {
        const best = {}
        for (const line of lines) {
            const m = line.match(/^([* ]?):(.*):(\d+):([^:]*)$/)
            if (!m) continue
            const name = m[2].replace(/\\:/g, ":").replace(/\\\\/g, "\\")
            if (name === "") continue
            const n = { ssid: name, signal: parseInt(m[3]), security: m[4].trim(), active: m[1] === "*", known: knownNames.indexOf(name) >= 0 }
            const old = best[name]
            if (!old || n.active || (!old.active && n.signal > old.signal)) best[name] = n
        }
        const out = Object.keys(best).map(k => best[k])
        out.sort((a, b) => (b.active - a.active) || (b.signal - a.signal))
        networks = out
        const act = out.filter(n => n.active)[0]
        if (act) signal = act.signal
    }

    Process {
        id: statusProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let eth = false, wifi = false, wname = "", wdev = ""
                for (const line of text.split("\n")) {
                    const m = line.match(/^([^:]*):([^:]*):([^:]*):(.*)$/)
                    if (!m) continue
                    if (m[2] === "wifi" && wdev === "") wdev = m[1]
                    if (m[3] !== "connected") continue
                    if (m[2] === "ethernet") eth = true
                    if (m[2] === "wifi") { wifi = true; wname = m[4].replace(/\\:/g, ":") }
                }
                root.wifiDevice = wdev
                root.connType = eth ? "ethernet" : (wifi ? "wifi" : "")
                root.ssid = wname
                if (wifi) root.loadList()
                else root.signal = 0
            }
        }
    }
    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: StdioCollector { onStreamFinished: root.wifiEnabled = text.trim() === "enabled" }
    }
    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = []
                for (const line of text.split("\n")) {
                    const m = line.match(/^(.*):(?:802-11-wireless|wifi)$/)
                    if (m) names.push(m[1].replace(/\\:/g, ":"))
                }
                root.knownNames = names
            }
        }
    }
    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: { root.merge(text.split("\n")); root.scanning = false }
        }
        onExited: root.scanning = false
    }
    Process { id: miscProc; onExited: root.refresh() }
    Process {
        id: connProc
        stderr: StdioCollector { id: connErr }
        onExited: code => {
            root.busy = false
            if (code === 0) root.notify("Connected", root.lastSsid)
            else root.notify("Couldn't connect to " + root.lastSsid, connErr.text.trim().split("\n").pop())
            root.refresh()
        }
    }

    Timer { id: later; interval: 1500; onTriggered: root.refresh() }
    Timer { interval: 10000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
