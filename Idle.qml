import QtQuick
import Quickshell
import Quickshell.Wayland

// Built-in idle handling (replaces hypridle for locking). Apps that inhibit idle (video players,
// browsers playing video) are respected.
// Before an auto-lock the screen dims for the last 15 seconds; any input brings it back.
Scope {
    id: idle
    property bool dimmed: false
    readonly property int dimLead: 15      // seconds of dimming before the lock

    IdleMonitor {
        enabled: Settings.autoLock && Settings.dimBeforeLock
        timeout: Math.max(5, Settings.lockMinutes * 60 - idle.dimLead)
        respectInhibitors: true
        onIsIdleChanged: idle.dimmed = isIdle
    }
    IdleMonitor {
        enabled: Settings.autoLock
        timeout: Settings.lockMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Session.lock()
    }
    IdleMonitor {
        enabled: Settings.autoSuspend
        timeout: Settings.suspendMinutes * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle) Session.sleep()
    }

    // dark overlay on every monitor; it ignores the pointer, so input still reaches the idle monitor
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: dimWin
            required property var modelData
            screen: modelData
            property real level: idle.dimmed ? 0.7 : 0
            Behavior on level { NumberAnimation { duration: Theme.dur(1500); easing.type: Easing.OutCubic } }
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            visible: level > 0.001
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "lovelyrice-dim"
            Rectangle { anchors.fill: parent; color: "black"; opacity: dimWin.level }
        }
    }
}
