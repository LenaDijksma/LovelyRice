pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Keeps Quickshell's copy of Hyprland's state fresh. Quickshell only learns a window's class (and which workspace
// it is on) from an explicit refresh, so without this the workspace icons stayed empty until the next /reload.
//  - a few seconds of polling at startup, until Hyprland has answered (the shell can start before it is ready)
//  - a refresh shortly after every window / workspace event
//  - a slow safety refresh
// `refreshed` fires once the answers have had time to arrive; `rev` changes with it, for bindings to depend on.
Singleton {
    id: root
    property int rev: 0
    signal refreshed()

    function refreshNow() {
        Hyprland.refreshWorkspaces()
        Hyprland.refreshToplevels()
        Hyprland.refreshMonitors()
        settle.restart()
    }

    readonly property var watched: ({
        openwindow: 1, closewindow: 1, movewindow: 1, movewindowv2: 1, windowtitle: 1, windowtitlev2: 1,
        workspace: 1, workspacev2: 1, createworkspace: 1, createworkspacev2: 1, destroyworkspace: 1, destroyworkspacev2: 1,
        moveworkspace: 1, moveworkspacev2: 1, renameworkspace: 1, focusedmon: 1, focusedmonv2: 1,
        activespecial: 1, activespecialv2: 1, monitoradded: 1, monitoraddedv2: 1, monitorremoved: 1, changefloatingmode: 1
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) { if (root.watched[event.name]) debounce.restart() }
    }
    Timer { id: debounce; interval: 60; onTriggered: root.refreshNow() }
    Timer { id: settle; interval: 180; onTriggered: { root.rev++; root.refreshed() } }

    // startup: ask every 300 ms until Hyprland has answered, then a few more times to catch late windows
    property int bootTicks: 0
    property int stable: 0
    Timer {
        interval: 300; repeat: true; running: true; triggeredOnStart: true
        onTriggered: {
            root.refreshNow()
            if (Hyprland.workspaces.values.length > 0) root.stable++
            if (++root.bootTicks >= 60 || root.stable >= 8) stop()
        }
    }
    Timer { interval: 5000; repeat: true; running: true; onTriggered: root.refreshNow() }
}
