import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// /settings — what the utility bar shows, how it looks (Style), whether it is split in two, popouts.
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
        logo: "Logo", workspaces: "Workspaces", spacer: "Flexible gap (pushes the rest to the far end)", media: "Media controls",
        status: "Status icons (see below)", brightness: "Brightness slider", buttons: "Launcher and theme buttons",
        recording: "Recording indicator (only while recording)", clock: "Clock"
    })
    readonly property var moduleToggle: ({
        logo: "showLogo", workspaces: "showWorkspaces", media: "showMedia", brightness: "showBrightness",
        buttons: "showButtons", clock: "showClock"
    })
    readonly property var dropLabels: ({
        dashboard: "Dashboard (weather, graphs, calendar)", control: "Control (mic, dnd, audio, power)",
        media: "Media (only while something plays)", notifications: "Notifications"
    })
    readonly property var dropToggle: ({
        dashboard: "dropdownDashboard", control: "dropdownControl", media: "dropdownMedia", notifications: "dropdownNotifications"
    })
    // "plugin:<name>" in a module list is a plugin's module / tab; it is "off" while the plugin is not running
    function pluginLabel(id) {
        if (id.indexOf("plugin:") !== 0) return id
        const n = id.slice(7)
        return n + (Plugins.barComponent(n) || Plugins.cardComponent(n) ? "  (plugin)" : "  (plugin, off)")
    }
    property string confirming: ""       // the plugin whose Allow is waiting for a second Enter
    readonly property var tabs: [
        { name: "Bar", rows: [
            { type: "header", label: "Size and position" },
            { type: "slider", key: "barThickness", label: "Thickness",     min: 44, max: 84, step: 2, unit: " px" },
            { type: "slider", key: "gap",          label: "Edge gap",      min: 0,  max: 24, step: 2, unit: " px" },
            { type: "choice", key: "barPosition",  label: "Position",      options: Settings.barPositions },
            { type: "slider", key: "radius",       label: "Corner radius (popouts, panels)", min: 0,  max: 32, step: 2, unit: " px" },
            { type: "header", label: "Modules, " + (Theme.horizontal ? "left to right  (← → or ◀ ▶ moves, Enter shows / hides)"
                                                                      : "top to bottom  (← → or ▲ ▼ moves, Enter shows / hides)") }
        ].concat(Settings.barOrder.map(id => ({ type: "module", list: "barOrder", id: id, label: moduleLabels[id] || pluginLabel(id), key: moduleToggle[id] || "" })))
         .concat([
            { type: "header", label: "Status icons" },
            { type: "toggle", key: "showStats",      label: "CPU / memory rings" },
            { type: "toggle", key: "showAudio",      label: "Volume" },
            { type: "toggle", key: "showBattery",    label: "Battery" },
            { type: "toggle", key: "showNetwork",    label: "Network (Wi-Fi / ethernet)" },
            { type: "toggle", key: "showBluetooth",  label: "Bluetooth" },
            { type: "toggle", key: "showNotifications", label: "Notification bell (unread count)" }
        ]) },
        { name: "Style", rows: [
            { type: "header", label: "Looks  (Enter applies one; your position, modules and colors stay)" }
        ].concat(Settings.presetNames.map(n => ({ type: "action", act: "preset:" + n, label: Settings.presetInfo[n] })))
         .concat([
            { type: "header", label: "Bar background" },
            { type: "choice", key: "barStyle",         label: "Made of",          options: Settings.enums.barStyle },
            { type: "slider", key: "barOpacity",       label: "Opacity",          min: 0,  max: 100, step: 5, unit: " %" },
            { type: "slider", key: "barRadius",        label: "Corner radius",    min: 0,  max: 40,  step: 2, unit: " px" },
            { type: "slider", key: "barBorder",        label: "Border width",     min: 0,  max: 4,   step: 1, unit: " px" },
            { type: "choice", key: "barBorderColor",   label: "Border color",     options: Settings.enums.barBorderColor },
            { type: "slider", key: "barBorderOpacity", label: "Border strength",  min: 0,  max: 100, step: 5, unit: " %" },
            { type: "slider", key: "barShadow",        label: "Shadow",           min: 0,  max: 100, step: 5, unit: " %" },
            { type: "choice", key: "barShadowColor",   label: "Shadow color  (accent = a glow)", options: Settings.enums.barShadowColor },
            { type: "header", label: "Shape on its edge" },
            { type: "slider", key: "barLength",        label: "Length",           min: 30, max: 100, step: 5, unit: " %" },
            { type: "choice", key: "barAlign",         label: "Sits at the",      options: Settings.enums.barAlign },
            { type: "slider", key: "barPadding",       label: "Padding inside the bar", min: 0, max: 14, step: 1, unit: " px" },
            { type: "slider", key: "moduleSpacing",    label: "Space between modules",  min: 0, max: 20, step: 1, unit: " px" },
            { type: "header", label: "Module pills" },
            { type: "choice", key: "pillStyle",        label: "Made of",          options: Settings.enums.pillStyle },
            { type: "slider", key: "pillRadius",       label: "Corner radius",    min: 0,  max: 28,  step: 1, unit: " px" },
            { type: "slider", key: "pillOpacity",      label: "Opacity (filled)", min: 0,  max: 100, step: 5, unit: " %" },
            { type: "slider", key: "pillPadding",      label: "Padding inside",   min: 0,  max: 12,  step: 1, unit: " px" },
            { type: "header", label: "Glass  (bar or pills made of glass)" },
            { type: "info",   label: Glass.shaderReady ? "Refraction shader: built, the rim bends what is behind it"
                                                       : "Refraction shader not built: blur only. Run  lovelyrice shaders  (needs qt6-shadertools)" },
            { type: "slider", key: "glassBlur",        label: "Blur",             min: 0,  max: 100, step: 5, unit: " %" },
            { type: "slider", key: "glassRefraction",  label: "Refraction",       min: 0,  max: 100, step: 5, unit: " %" },
            { type: "slider", key: "glassLight",       label: "Rim light",        min: 0,  max: 100, step: 5, unit: " %" },
            { type: "slider", key: "glassTint",        label: "Theme tint",       min: 0,  max: 100, step: 5, unit: " %" },
            { type: "toggle", key: "glassFringe",      label: "Color fringing at the rim" },
            { type: "header", label: "Visibility" },
            { type: "choice", key: "barVisibility",    label: "Bar is",           options: Settings.enums.barVisibility },
            { type: "toggle", key: "barReserveSpace",  label: "Auto-hide: keep room for the bar" },
            { type: "slider", key: "barHideDelay",     label: "Auto-hide delay",  min: 200, max: 2000, step: 100, unit: " ms" }
        ]) },
        { name: "Split", rows: [
            { type: "header", label: "Two bars" },
            { type: "toggle", key: "barSplit",         label: "Split the bar in two" },
            { type: "choice", key: "bar2Position",     label: "Bar 2 sits on the", options: Settings.barPositions.filter(p => p !== Settings.barPosition) },
            { type: "action", act: "splitLayout",      label: "Preset: workspaces along the top, the rest on the right" },
            { type: "header", label: "Where each module lives  (bar 1 is on the " + Settings.barPosition + ", bar 2 on the " + Settings.bar2Position + ")" }
        ].concat(Settings.barOrder.filter(id => id !== "spacer")
                 .map(id => ({ type: "member", id: id, label: moduleLabels[id] || pluginLabel(id) })))
         .concat([
            { type: "info", label: "Order within a bar is set on the Bar tab. The flexible gap is on both bars." }
        ]) },
        { name: "Hyprland", rows: [
            { type: "header", label: "Window borders and shape follow LovelyRice" },
            { type: "toggle", key: "hyprSync",         label: "Hyprland follows the theme and the bar" },
            { type: "info",   label: "Changes the running compositor only; turning it off reloads your own config. `lovelyrice hypr log` shows its answer." },
            { type: "header", label: "Borders" },
            { type: "toggle", key: "hyprBorders",      label: "Border colors from the theme" },
            { type: "choice", key: "hyprBorderStyle",  label: "Active border",   options: Settings.enums.hyprBorderStyle },
            { type: "header", label: "Shape" },
            { type: "toggle", key: "hyprShape",        label: "Control border width, rounding and gaps" },
            { type: "slider", key: "hyprBorderSize",   label: "Border width",    min: 0, max: 8,  step: 1, unit: " px" },
            { type: "toggle", key: "hyprRoundFollow",  label: "Window rounding = the bar's corner radius" },
            { type: "slider", key: "hyprRounding",     label: "Window rounding", min: 0, max: 30, step: 1, unit: " px" },
            { type: "toggle", key: "hyprGapsFollow",   label: "Gaps follow the bar's edge gap" },
            { type: "slider", key: "hyprGapsOut",      label: "Outer gap",       min: 0, max: 40, step: 1, unit: " px" },
            { type: "slider", key: "hyprGapsIn",       label: "Inner gap",       min: 0, max: 20, step: 1, unit: " px" },
            { type: "header", label: "Effects" },
            { type: "toggle", key: "hyprBlur",         label: "Blur behind windows" },
            { type: "slider", key: "hyprBlurSize",     label: "Blur size",       min: 1, max: 20, step: 1, unit: "" },
            { type: "slider", key: "hyprBlurPasses",   label: "Blur passes",     min: 1, max: 6,  step: 1, unit: "" },
            { type: "toggle", key: "hyprShadow",       label: "Window shadows" },
            { type: "toggle", key: "hyprShadowGlow",   label: "Shadows glow in the accent color" },
            { type: "slider", key: "hyprShadowRange",  label: "Shadow size",     min: 1, max: 40, step: 1, unit: " px" },
            { type: "toggle", key: "hyprOpacity",      label: "Window opacity" },
            { type: "slider", key: "hyprActiveOpacity",   label: "Focused window",   min: 50, max: 100, step: 1, unit: " %" },
            { type: "slider", key: "hyprInactiveOpacity", label: "Other windows",    min: 50, max: 100, step: 1, unit: " %" }
        ] },
        { name: "Dropdown", rows: [
            { type: "header", label: "Panel" },
            { type: "choice", key: "dropdownPosition", label: "Position", options: Settings.dropdownPositions },
            { type: "toggle", key: "dropdownHotEdge",  label: "Open when the pointer pushes against its edge" },
            { type: "header", label: "Tabs, left to right  (← → moves, Enter shows / hides)" }
        ].concat(Settings.dropdownOrder.map(id => ({ type: "module", list: "dropdownOrder", id: id, label: dropLabels[id] || pluginLabel(id), key: dropToggle[id] || "" }))) },
        { name: "Theme", rows: [
            { type: "header", label: "Colors" },
            { type: "toggle", key: "wallpaperTheme", label: "Colors follow the wallpaper" },
            { type: "action", act: "match",  label: "Match colors to current wallpaper" },
            { type: "toggle", key: "wallpaperAnimate", label: "Play animated wallpapers (gif, webp, video)" },
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
        { name: "Plugins", rows: [
            { type: "header", label: "Plugins are code that runs with your full permissions" },
            { type: "toggle", key: "pluginHotReload", label: "Reload a plugin when its files change (for development)" },
            { type: "action", act: "pluginsReload",   label: "Look for plugins again" },
            { type: "header", label: "Installed  (Enter allows / turns on / turns off)" }
        ].concat(Plugins.list.length === 0
                 ? [{ type: "info", label: "none yet: lovelyrice plugin new <name>   or   lovelyrice plugin install <git-url>" }]
                 : Plugins.list.map(p => ({ type: "plugin", plugin: p, label: p.name + (p.version ? "  " + p.version : "") }))) },
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
    function setTab(t) { confirming = ""; tab = (t + tabs.length) % tabs.length; index = firstSelectable() }

    function selectable(i) { return rows[i] && rows[i].type !== "header" }
    function move(d) {
        confirming = ""
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
            if (nb && nb.type === "module") { Settings.moveModule(r.id, dir, r.list); index += dir }
        }
        else if (r.type === "member") Settings.toggleBar2(r.id)
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
            else if (r.act === "pluginsReload") Plugins.reload()
            else if (r.act.indexOf("preset:") === 0) Settings.applyPreset(r.act.slice(7))
            else if (r.act === "splitLayout") Settings.presetSplitLayout()
            else Settings.reset()
        }
        else if (r.type === "plugin") {
            const p = r.plugin
            if (p.error !== "") return
            if (!p.allowed || p.trust !== "ok") {
                // trusting a plugin is a decision: the first Enter asks, the second one allows
                if (confirming === p.name) { confirming = ""; Plugins.act("allow", p.name) }
                else confirming = p.name
            } else Plugins.act(p.enabled ? "disable" : "enable", p.name)
        }
        else if (r.type === "toggle" || r.type === "choice" || r.type === "member") adjust(1)
        else if (r.type === "module" && r.key) Settings.set(r.key, !Settings[r.key])
    }
    function show() { Popups.claim("settings"); confirming = ""; index = firstSelectable(); open = true; keys.forceActiveFocus() }
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
        width: Math.min(parent.width - 40, 820)
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

        Flow {   // tabs: wrap onto a second line instead of running off the card
            id: tabBar
            x: 18; y: 58
            width: parent.width - 36
            spacing: 4
            Repeater {
                model: win.tabs
                delegate: Item {
                    id: tb
                    required property var modelData
                    required property int index
                    readonly property bool cur: index === win.tab
                    width: label.implicitWidth + 22; height: 30
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
            x: 12; y: tabBar.y + tabBar.height + 8
            width: parent.width - 24
            height: parent.height - y - 40
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
                readonly property var val: modelData.type === "member" ? Settings.bar2Modules.indexOf(modelData.id) >= 0
                                           : (modelData.key ? Settings[modelData.key] : undefined)
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

                // ---- bar module: ▲ ▼ (◀ ▶ on a top/bottom bar) and (when it can be hidden) a switch ----
                Row {
                    visible: row.modelData.type === "module"
                    anchors { right: parent.right; rightMargin: row.modelData.key ? 80 : 24; verticalCenter: parent.verticalCenter }
                    spacing: 6
                    Repeater {
                        model: {
                            const h = row.modelData.list === "dropdownOrder" ? true : Theme.horizontal
                            return [{ g: h ? "◀" : "▲", d: -1 }, { g: h ? "▶" : "▼", d: 1 }]
                        }
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
                    visible: row.modelData.type === "toggle" || row.modelData.type === "member" || (row.modelData.type === "module" && row.modelData.key !== "")
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

                Text {   // which bar a module is on
                    visible: row.modelData.type === "member"
                    anchors { right: parent.right; rightMargin: 80; verticalCenter: parent.verticalCenter }
                    text: row.val ? "bar 2" : "bar 1"
                    color: row.val ? Theme.accent : Theme.dim
                    font { family: Theme.font; pixelSize: 12 }
                }

                // ---- plugin: its state, and what Enter will do ----
                Text {
                    visible: row.modelData.type === "plugin"
                    anchors { right: parent.right; rightMargin: 24; verticalCenter: parent.verticalCenter }
                    width: Math.min(implicitWidth, parent.width - 250)
                    elide: Text.ElideRight
                    readonly property var pl: row.modelData.plugin
                    readonly property bool asking: pl !== undefined && win.confirming === pl.name
                    text: !pl ? "" : (asking ? "⏎ again: allow it, full access" : Plugins.stateText(pl))
                    color: !pl ? Theme.dim : (asking || pl.trust === "changed" || pl.error !== "" || Plugins.errors[pl.name] ? Theme.warn
                                              : (Plugins.stateText(pl) === "on" ? Theme.accent : Theme.dim))
                    font { family: Theme.font; pixelSize: 13 }
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
            text: "↑↓ select   ←→ change   ⏎ toggle   tab / 1-" + win.tabs.length + " switch tab   esc close"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 10 }
        }
    }
}
