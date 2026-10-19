import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// /settings — what the sidebar shows, its size and position, corner radius, popouts.
// ↑/↓ select · ←/→ change · Enter/Space toggle · Esc close. Everything also works with the mouse.
// Changes apply live and are saved automatically.
PanelWindow {
    id: win

    signal schemeMakerRequested()
    signal doctorRequested()
    property bool open: false
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(280); easing.type: Easing.OutCubic } }
    property int index: 1
    onOpenChanged: Popups.report("settings", open)
    Connections {
        target: Popups
        function onCloseOthers(except) { if (except !== "settings" && win.open) win.hide() }
        function onCloseAll() { if (win.open) win.hide() }
    }

    property int tab: 0
    readonly property var moduleLabels: ({
        logo: "Logo", workspaces: "Workspaces", spacer: "Flexible gap (pushes the rest down)", media: "Media controls",
        status: "Status icons (see below)", brightness: "Brightness slider", buttons: "Launcher and theme buttons",
        recording: "Recording indicator (only while recording)", clock: "Clock"
    })
    readonly property var moduleToggle: ({
        logo: "showLogo", workspaces: "showWorkspaces", media: "showMedia", brightness: "showBrightness",
        buttons: "showButtons", clock: "showClock"
    })
    readonly property var tabs: [
        { name: "Sidebar", rows: [
            { type: "header", label: "Size and position" },
            { type: "slider", key: "sidebarWidth", label: "Width",         min: 44, max: 84, step: 2, unit: " px" },
            { type: "slider", key: "gap",          label: "Edge gap",      min: 0,  max: 24, step: 2, unit: " px" },
            { type: "choice", key: "side",         label: "Position",      options: ["left", "right"] },
            { type: "slider", key: "radius",       label: "Corner radius", min: 0,  max: 32, step: 2, unit: " px" },
            { type: "header", label: "Modules, top to bottom  (← → or ▲ ▼ moves, Enter shows / hides)" }
        ].concat(Settings.sidebarOrder.map(id => ({ type: "module", id: id, label: moduleLabels[id] || id, key: moduleToggle[id] || "" })))
         .concat([
            { type: "header", label: "Status icons" },
            { type: "toggle", key: "showStats",      label: "CPU / memory rings" },
            { type: "toggle", key: "showAudio",      label: "Volume" },
            { type: "toggle", key: "showBattery",    label: "Battery" },
            { type: "toggle", key: "showNetwork",    label: "Network (Wi-Fi / ethernet)" },
            { type: "toggle", key: "showBluetooth",  label: "Bluetooth" },
            { type: "toggle", key: "showNotifications", label: "Notification bell (unread count)" }
        ]) },
        { name: "Theme", rows: [
            { type: "header", label: "Colors" },
            { type: "toggle", key: "wallpaperTheme", label: "Colors follow the wallpaper" },
            { type: "action", act: "match",  label: "Match colors to current wallpaper" },
            { type: "action", act: "editor", label: "Edit colors (scheme maker)…" },
            { type: "header", label: "Apps follow the theme" },
            { type: "toggle", key: "syncApps",       label: "Sync GTK, foot and fastfetch" },
            { type: "toggle", key: "syncGtk",        label: "    GTK apps" },
            { type: "toggle", key: "syncFoot",       label: "    foot terminal" },
            { type: "toggle", key: "runHooks",       label: "Run theme hooks (~/.config/lovelyrice/hooks)" },
            { type: "header", label: "Motion" },
            { type: "choice", key: "animSpeed",      label: "Animation speed", options: ["off", "fast", "normal", "slow"] }
        ] },
        { name: "Popouts", rows: [
            { type: "header", label: "Popouts" },
            { type: "toggle", key: "osd",            label: "Volume / brightness popouts" },
            { type: "toggle", key: "mediaPopout",    label: "Media popout (track change / hover)" },
            { type: "toggle", key: "dashboard",      label: "Dashboard popout (hover the clock)" },
            { type: "toggle", key: "weather",        label: "Weather in the dashboard (asks wttr.in)" },
            { type: "choice", key: "weatherUnits",   label: "Weather units", options: ["metric", "imperial"] }
        ] },
        { name: "Power", rows: [
            { type: "header", label: "Battery" },
            { type: "toggle", key: "batteryWarning", label: "Low-battery warning" },
            { type: "slider", key: "batteryLow",     label: "Warn at", min: 5, max: 50, step: 5, unit: " %" },
            { type: "header", label: "Lock and sleep" },
            { type: "toggle", key: "autoLock",       label: "Lock automatically when idle" },
            { type: "slider", key: "lockMinutes",    label: "Lock after", min: 1, max: 60, step: 1, unit: " min" },
            { type: "toggle", key: "autoSuspend",    label: "Suspend automatically when idle" },
            { type: "slider", key: "suspendMinutes", label: "Suspend after", min: 5, max: 180, step: 5, unit: " min" },
            { type: "toggle", key: "lockOnSleep",    label: "Lock before sleeping" },
            { type: "toggle", key: "dimBeforeLock",  label: "Dim the screen 15 s before auto-lock" },
            { type: "toggle", key: "lockOnLid",      label: "Lock when the lid closes" },
            { type: "toggle", key: "lockBlur",       label: "Blurred screenshot on the lock screen" },
            { type: "toggle", key: "lockFingerprint", label: "Fingerprint unlock (needs fprintd)" }
        ] },
        { name: "Launcher", rows: [
            { type: "header", label: "Palette" },
            { type: "choice", key: "searchEngine",   label: "Web search engine (?text)", options: Search.names },
            { type: "toggle", key: "calcAuto",       label: "Calculate as you type (2+2*3 without =)" },
            { type: "toggle", key: "rankApps",       label: "Put frequently used apps first" },
            { type: "action", act: "clearUsage",     label: "Forget app launch history" },
            { type: "header", label: "Apps" },
            { type: "choice", key: "terminal",       label: "Terminal for ldmp", options: ["auto"].concat(Terminal.installed) },
            { type: "header", label: "Tools" },
            { type: "action", act: "doctor",         label: "Check installed tools (/doctor)…" },
            { type: "header", label: "" },
            { type: "action", act: "reset", label: "Reset all settings to defaults" }
        ] }
    ]
    readonly property var rows: tabs[tab].rows

    function firstSelectable() { for (let i = 0; i < rows.length; i++) if (selectable(i)) return i; return 0 }
    function setTab(t) { tab = (t + tabs.length) % tabs.length; index = firstSelectable() }

    function selectable(i) { return rows[i] && rows[i].type !== "header" }
    function move(d) {
        let i = index
        for (let n = 0; n < rows.length; n++) {
            i = (i + d + rows.length) % rows.length
            if (selectable(i)) break
        }
        index = i
    }
    function adjust(dir) {
        const r = rows[index]
        if (!r) return
        if (r.type === "module") {   // ← up, → down; the row follows the module
            const nb = rows[index + dir]
            if (nb && nb.type === "module") { Settings.moveModule(r.id, dir); index += dir }
        }
        else if (r.type === "toggle") Settings.set(r.key, !Settings[r.key])
        else if (r.type === "slider") Settings.set(r.key, Settings[r.key] + dir * r.step)
        else if (r.type === "choice") {
            const n = r.options.length
            Settings.set(r.key, r.options[(r.options.indexOf(Settings[r.key]) + dir + n) % n])
        }
    }
    function activate() {
        const r = rows[index]
        if (!r) return
        if (r.type === "action") {
            if (r.act === "match") WallpaperColors.apply()
            else if (r.act === "editor") schemeMakerRequested()
            else if (r.act === "doctor") doctorRequested()
            else if (r.act === "clearUsage") Usage.clear()
            else Settings.reset()
        }
        else if (r.type === "toggle" || r.type === "choice") adjust(1)
        else if (r.type === "module" && r.key) Settings.set(r.key, !Settings[r.key])
    }
    function show() { Popups.claim("settings"); index = firstSelectable(); open = true; keys.forceActiveFocus() }
    function hide() { open = false; keys.focus = false }
    function toggle() { open ? hide() : show() }

    visible: progress > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lovelyrice-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4 * win.progress)
        MouseArea { anchors.fill: parent; onClicked: win.hide() }
    }

    Card {
        id: card
        width: 560
        height: Math.min(parent.height - 80, 560)
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 + (1 - win.progress) * 20
        opacity: win.progress
        scale: 0.94 + 0.06 * win.progress
        transformOrigin: Item.Center
        radius: Theme.radius + 4
        color: Qt.alpha(Theme.bg, 0.97)
        borderColor: Qt.alpha(Theme.accent, 0.8)
        borderWidth: 2
        shadowY: 18

        MouseArea { anchors.fill: parent }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape)                              win.hide()
                else if (e.key === Qt.Key_Down  || e.key === Qt.Key_J)   win.move(1)
                else if (e.key === Qt.Key_Up    || e.key === Qt.Key_K)   win.move(-1)
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_L)   win.adjust(1)
                else if (e.key === Qt.Key_Left  || e.key === Qt.Key_H)   win.adjust(-1)
                else if (e.key === Qt.Key_Tab || e.key === Qt.Key_PageDown)                              win.setTab(win.tab + 1)
                else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_PageUp)                            win.setTab(win.tab - 1)
                else if (e.key >= Qt.Key_1 && e.key < Qt.Key_1 + win.tabs.length)                        win.setTab(e.key - Qt.Key_1)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) win.activate()
                else return
                e.accepted = true
            }
        }

        Text {
            x: 26; y: 20
            text: "Settings"
            color: Theme.fg
            font { family: Theme.font; pixelSize: 20; bold: true }
        }
        Text {
            anchors { right: parent.right; rightMargin: 26; top: parent.top; topMargin: 26 }
            text: "saved automatically"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 11 }
        }

        Row {   // tabs
            id: tabBar
            x: 18; y: 58
            spacing: 4
            Repeater {
                model: win.tabs
                delegate: Item {
                    id: tb
                    required property var modelData
                    required property int index
                    readonly property bool cur: index === win.tab
                    width: label.implicitWidth + 28; height: 30
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusSmall
                        color: tb.cur ? Qt.alpha(Theme.accent, 0.18) : (tma.containsMouse ? Theme.surface : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.dur(150) } }
                    }
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: tb.modelData.name
                        color: tb.cur ? Theme.accent : Theme.fg
                        font { family: Theme.font; pixelSize: 13; bold: tb.cur }
                    }
                    Rectangle {   // underline
                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                        width: tb.cur ? parent.width - 16 : 0; height: 2; radius: 1
                        color: Theme.accent
                        Behavior on width { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutCubic } }
                    }
                    MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; onClicked: win.setTab(tb.index) }
                }
            }
        }

        ListView {
            id: list
            x: 12; y: 96
            width: parent.width - 24
            height: parent.height - 96 - 40
            clip: true
            model: win.rows
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: win.index
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === win.index
                readonly property bool hdr: modelData.type === "header"
                readonly property var val: modelData.key ? Settings[modelData.key] : undefined
                width: ListView.view.width
                height: hdr ? 36 : 44

                Rectangle {
                    visible: !row.hdr
                    anchors { fill: parent; topMargin: 2; bottomMargin: 2; leftMargin: 4; rightMargin: 4 }
                    radius: Theme.radiusSmall
                    color: row.sel ? Theme.surface : "transparent"
                    border.color: row.sel ? Qt.alpha(Theme.accent, 0.5) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.dur(150) } }
                }

                Text {   // section header
                    visible: row.hdr
                    x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                    text: row.modelData.label.toUpperCase()
                    color: Theme.accent
                    font { family: Theme.font; pixelSize: 10; bold: true; letterSpacing: 1.5 }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !row.hdr
                    onClicked: { win.index = row.index; if (row.modelData.type !== "slider") win.activate() }
                }

                Text {
                    visible: !row.hdr && row.modelData.type !== "action"
                    x: 20; anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: 14 }
                }
                Text {   // action row
                    visible: row.modelData.type === "action"
                    anchors.centerIn: parent
                    text: row.modelData.label
                    color: row.modelData.act === "reset" ? Theme.warn : Theme.accent
                    font { family: Theme.font; pixelSize: 14 }
                }

                // ---- sidebar module: ▲ ▼ and (when it can be hidden) a switch ----
                Row {
                    visible: row.modelData.type === "module"
                    anchors { right: parent.right; rightMargin: row.modelData.key ? 80 : 24; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: [{ g: "▲", d: -1 }, { g: "▼", d: 1 }]
                        delegate: Rectangle {
                            id: ab
                            required property var modelData
                            width: 28; height: 26; radius: 6
                            color: am.containsMouse ? Qt.alpha(Theme.accent, 0.25) : Qt.alpha(Theme.dim, 0.18)
                            Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                            Text { anchors.centerIn: parent; text: ab.modelData.g; color: Theme.accent
                                   font { family: Theme.font; pixelSize: 11 } }
                            MouseArea {
                                id: am
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: { win.index = row.index; win.adjust(ab.modelData.d) }
                            }
                        }
                    }
                }

                // ---- toggle ----
                Rectangle {
                    visible: row.modelData.type === "toggle" || (row.modelData.type === "module" && row.modelData.key !== "")
                    anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                    width: 44; height: 24; radius: 12
                    color: row.val ? Theme.accent : Qt.alpha(Theme.dim, 0.4)
                    Behavior on color { ColorAnimation { duration: Theme.dur(180) } }
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        y: 3
                        x: row.val ? 23 : 3
                        color: row.val ? Theme.bg : Theme.fg
                        Behavior on x { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutBack } }
                    }
                }

                // ---- choice ----
                Text {
                    visible: row.modelData.type === "choice"
                    anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                    text: "‹   " + row.val + "   ›"
                    color: Theme.accent
                    font { family: Theme.font; pixelSize: 14 }
                }

                // ---- slider ----
                Item {
                    id: sl
                    visible: row.modelData.type === "slider"
                    anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                    width: 250; height: 28
                    readonly property real frac: visible
                        ? (row.val - row.modelData.min) / (row.modelData.max - row.modelData.min) : 0

                    Rectangle {
                        id: track
                        x: 0; width: parent.width - 66; height: 6; radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: Qt.alpha(Theme.dim, 0.35)
                        Rectangle {
                            width: parent.width * sl.frac; height: parent.height; radius: 3
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: Theme.dur(90) } }
                        }
                        Rectangle {
                            x: parent.width * sl.frac - 7; y: -4
                            width: 14; height: 14; radius: 7
                            color: Theme.fg
                            Behavior on x { NumberAnimation { duration: Theme.dur(90) } }
                        }
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: row.val + (row.modelData.unit || "")
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 12 }
                    }
                    MouseArea {
                        anchors { left: track.left; right: track.right; top: parent.top; bottom: parent.bottom
                                  leftMargin: -8; rightMargin: -8 }
                        function setFrom(mx) {
                            const px = mapToItem(track, mx, 0).x
                            const f = Math.max(0, Math.min(1, px / track.width))
                            const m = row.modelData
                            const raw = m.min + f * (m.max - m.min)
                            Settings.set(m.key, Math.round((raw - m.min) / m.step) * m.step + m.min)
                        }
                        onPressed: mouse => { win.index = row.index; setFrom(mouse.x) }
                        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
                    }
                }
            }
        }

        Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 14 }
            horizontalAlignment: Text.AlignHCenter
            text: "↑↓ select   ←→ change   ⏎ toggle   tab / 1-5 switch tab   esc close"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 10 }
        }
    }
}
