pragma Singleton
import QtQuick
import Quickshell

// Coordinates the palette, calendar and settings popups:
//  - opening one closes the others, and SUPER closes whatever is open
//  - while a popup is open (and briefly after), a special workspace that appears by itself is closed again.
//    Overlay windows take and give back keyboard focus, and Hyprland can answer that by refocusing the last
//    window it knew — which may be one sitting in a hidden special workspace.
Singleton {
    id: root
    property var openSet: ({})
    readonly property bool anyOpen: {
        for (const k in openSet) if (openSet[k]) return true
        return false
    }
    signal closeOthers(string except)
    signal closeAll()

    property var snapshot: ({})
    property double guardUntil: 0
    property double exemptUntil: 0

    // The next special workspace to open is intentional (e.g. focusing a window that lives in one).
    function exempt() { exemptUntil = Date.now() + 2500 }

    function claim(name) { closeOthers(name) }
    function report(name, isOpen) {
        const was = anyOpen
        const s = Object.assign({}, openSet)
        s[name] = isOpen
        openSet = s
        if (!was && anyOpen) snapshot = Object.assign({}, Specials.byMonitor)
        if (was && !anyOpen) guardUntil = Date.now() + 1500
    }

    Connections {
        target: Specials
        function onOpened(monitor, name) {
            if (Date.now() < root.exemptUntil) return
            if (!(root.anyOpen || Date.now() < root.guardUntil)) return
            if (root.snapshot[monitor]) return           // was already open when the popup appeared
            Quickshell.execDetached(["hyprctl", "dispatch",
                'hl.dsp.workspace.toggle_special("' + name.replace(/^special:/, "") + '")'])
        }
    }
}
