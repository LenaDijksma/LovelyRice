pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// Notification server + history.
//  - popups:  notifications currently on screen (shown by NotificationToasts.qml)
//  - history: everything that arrived, newest first, saved to ~/.local/state/lovelyrice/notifications.json
//             (shown by NotificationPanel.qml). Do-not-disturb still records history, it only hides popups.
//  - unread:  how many arrived since the history panel was last open (the badge on the sidebar bell).
//  - muted apps: no popup and not counted as unread, but still kept in the history. Saved to notif-muted.json.
//    Critical notifications always get through, for both do-not-disturb and muted apps.
// Only one program can own org.freedesktop.Notifications: stop mako / dunst / swaync / any other shell first.
Singleton {
    id: root

    property bool dnd: false
    property int unread: 0
    property bool panelOpen: false       // set by NotificationPanel; nothing is "unread" while it is open
    property var mutedApps: []
    property var history: []
    readonly property int maxHistory: 50
    readonly property var popups: server.trackedNotifications
    readonly property string file: Quickshell.env("HOME") + "/.local/state/lovelyrice/notifications.json"
    readonly property string mutedFile: Quickshell.env("HOME") + "/.local/state/lovelyrice/notif-muted.json"
    property int seq: 0

    function start() {}      // shell.qml calls this once so the server exists from startup

    function remember(n) {
        const entry = {
            id: Date.now() * 100 + (seq++ % 100),
            app: n.appName || "",
            icon: n.appIcon || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency === NotificationUrgency.Critical ? 2
                   : (n.urgency === NotificationUrgency.Low ? 0 : 1),
            time: Date.now()
        }
        history = [entry].concat(history).slice(0, maxHistory)
        save()
    }
    function remove(id) { history = history.filter(e => e.id !== id); save() }
    function clear()    { history = []; unread = 0; save() }
    function markRead() { unread = 0 }

    function isMuted(app) { return app !== "" && mutedApps.indexOf(app) >= 0 }
    function mute(app) {
        if (app === "" || isMuted(app)) return
        mutedApps = mutedApps.concat([app])
        mutedTimer.restart()
    }
    function unmute(app) { mutedApps = mutedApps.filter(a => a !== app); mutedTimer.restart() }
    function toggleMute(app) { isMuted(app) ? unmute(app) : mute(app) }
    function save()     { saveTimer.restart() }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: n => {
            const critical = n.urgency === NotificationUrgency.Critical
            const muted = root.isMuted(n.appName || "")
            root.remember(n)
            if ((!muted || critical) && !root.panelOpen) root.unread++
            if ((root.dnd || muted) && !critical) return                           // history only
            n.tracked = true                                                       // show a popup
        }
    }

    Timer {
        id: saveTimer
        interval: 600
        onTriggered: {
            saver.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"',
                             "sh", root.file, JSON.stringify(root.history)]
            saver.running = true
        }
    }
    Process { id: saver }

    Timer {
        id: mutedTimer
        interval: 400
        onTriggered: {
            mutedSaver.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf %s "$2" > "$1"',
                                  "sh", root.mutedFile, JSON.stringify(root.mutedApps)]
            mutedSaver.running = true
        }
    }
    Process { id: mutedSaver }
    FileView {
        path: root.mutedFile
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text())
                if (Array.isArray(saved)) root.mutedApps = saved.filter(a => typeof a === "string")
            } catch (e) { console.warn("LovelyRice: bad notif-muted.json") }
        }
    }

    FileView {
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const saved = JSON.parse(text())
                if (Array.isArray(saved))
                    root.history = root.history.concat(saved).slice(0, root.maxHistory)
            } catch (e) { console.warn("LovelyRice: bad notifications.json") }
        }
    }
}
