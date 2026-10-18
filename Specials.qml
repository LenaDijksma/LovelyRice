pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Tracks the open special workspace (scratchpad) per monitor: monitor name -> "special:xyz" ("" = none).
Singleton {
    id: root
    property var byMonitor: ({})
    signal opened(string monitor, string name)   // a special workspace just became visible

    function load() {
        const m = {}
        const ms = Hyprland.monitors.values
        for (let i = 0; i < ms.length; i++) {
            const sw = ms[i].lastIpcObject ? ms[i].lastIpcObject.specialWorkspace : null
            m[ms[i].name] = sw && sw.name ? sw.name : ""
        }
        byMonitor = m
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activespecial") return
            const p = event.data.split(",")
            const m = Object.assign({}, root.byMonitor)
            const prev = m[p[1]] || ""
            m[p[1]] = p[0]
            root.byMonitor = m
            if (p[0] !== "" && prev === "") root.opened(p[1], p[0])
        }
    }

    property int ticks: 0
    Timer {
        interval: 400; repeat: true; running: true; triggeredOnStart: true
        onTriggered: { Hyprland.refreshMonitors(); root.load(); if (++root.ticks >= 8) stop() }
    }
}
