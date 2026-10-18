pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bluetooth status and device control through bluetoothctl (BlueZ).
Singleton {
    id: root
    property bool available: true
    property bool powered: false
    readonly property bool scanning: scanProc.running
    property var devices: []          // [{ mac, name, paired, connected }]
    readonly property int connectedCount: devices.filter(d => d.connected).length
    property string lastName: ""

    function notify(title, body) { Quickshell.execDetached(["notify-send", "-a", "Bluetooth", title, body || ""]) }
    function refresh() { showProc.running = true; devProc.running = true }
    function scan() { if (!powered || scanProc.running) return; scanProc.running = true }
    function setPower(on) {
        miscProc.command = ["bluetoothctl", "power", on ? "on" : "off"]
        miscProc.running = true
        powered = on
    }
    function connect(dev) {
        lastName = dev.name
        actProc.command = ["sh", "-c",
            'if [ "$2" != yes ]; then bluetoothctl pair "$1"; bluetoothctl trust "$1"; fi; bluetoothctl connect "$1"',
            "sh", dev.mac, dev.paired ? "yes" : "no"]
        actProc.running = true
    }
    function disconnectDevice(dev) {
        miscProc.command = ["bluetoothctl", "disconnect", dev.mac]
        miscProc.running = true
    }
    function forget(dev) {
        miscProc.command = ["bluetoothctl", "remove", dev.mac]
        miscProc.running = true
    }

    Process {
        id: showProc
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = text.indexOf("Controller") >= 0
                root.powered = /Powered:\s*yes/.test(text)
            }
        }
    }
    Process {
        id: devProc
        command: ["sh", "-c", 'bluetoothctl devices; echo "@@P"; bluetoothctl devices Paired; echo "@@C"; bluetoothctl devices Connected']
        stdout: StdioCollector {
            onStreamFinished: {
                const all = {}, paired = {}, conn = {}
                let section = 0
                for (const line of text.split("\n")) {
                    if (line === "@@P") { section = 1; continue }
                    if (line === "@@C") { section = 2; continue }
                    const m = line.match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.*)$/)
                    if (!m) continue
                    if (section === 0) all[m[1]] = m[2]
                    else if (section === 1) paired[m[1]] = true
                    else conn[m[1]] = true
                }
                const out = Object.keys(all).map(mac => ({ mac: mac, name: all[mac], paired: !!paired[mac], connected: !!conn[mac] }))
                out.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
                root.devices = out
            }
        }
    }
    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "12", "scan", "on"]
    }
    Process { id: miscProc; onExited: root.refresh() }
    Process {
        id: actProc
        stdout: StdioCollector { id: actOut }
        onExited: {
            const ok = actOut.text.indexOf("Connection successful") >= 0
            root.notify(ok ? "Connected" : "Couldn't connect", ok ? root.lastName : "Is " + root.lastName + " on and in range?")
            root.refresh()
        }
    }

    Timer { interval: 2000; repeat: true; running: root.scanning; onTriggered: devProc.running = true }
    Timer { interval: 10000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
