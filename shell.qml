//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// LovelyRice — entry point.
// Each piece is independent: if one optional service is missing, the rest still load.
ShellRoot {
    id: root
    Component.onCompleted: { Specials.load(); Notifs.start(); Timers.start(); Net.refresh(); Bt.refresh(); Terminal.resolve(); Doctor.start(); Power.start(); WallpaperColors.start(); Lid.start(); Stats.start(); Hooks.start(); Plugins.start(); HyprTheme.start() }

    // SUPER / launcher button: if any popup is open, close it; otherwise open the palette.
    function mainToggle() {
        if (Popups.anyOpen) Popups.closeAll()
        else palette.toggle()
    }
    property string barBeforeHide: "always"      // what `lovelyrice bar toggle` goes back to
    function doLock() {
        Popups.closeAll()
        if (lockLoader.status === Loader.Ready) lockLoader.item.lock()
        else Quickshell.execDetached(["sh", "-c", "pidof hyprlock >/dev/null || hyprlock"])   // fallback
    }
    Timer { id: lockTimer; interval: 200; onTriggered: root.doLock() }

    Wallpaper {}

    // One utility bar per monitor
    Variants {
        model: Quickshell.screens
        UtilityBar {
            onLauncherRequested: root.mainToggle()
            onCalendarRequested: cal.toggle()
            onNetworkRequested: palette.openWith("network")
            onBluetoothRequested: palette.openWith("bluetooth")
            onNotificationsRequested: notifPanel.toggle()
        }
    }

    CommandPalette {
        id: palette
        onCalendarRequested: cal.show()
        onSettingsRequested: settings.show()
        onLockRequested: lockTimer.restart()
        onSchemeMakerRequested: maker.show()
        onOverviewRequested: overview.show()
        onDashboardRequested: dash.peek()
    }
    CalendarPopup { id: cal }
    Overview { id: overview }
    Dashboard { id: dash }
    SettingsPopup { id: settings; onSchemeMakerRequested: maker.show(); onDoctorRequested: palette.openWith("doctor") }
    SchemeMaker { id: maker }
    Osd {}
    MediaPopout { id: mediaPop }
    NotificationToasts {}
    NotificationPanel { id: notifPanel }
    Dropdown { id: dropdown }
    DropdownEdge { dropdown: dropdown }
    Loader { id: lockLoader; source: "Lock.qml" }
    Loader { source: "Idle.qml" }                    // auto-lock / auto-suspend (settings)
    Connections { target: Session; function onLockRequested() { lockTimer.restart() } }   // a failure here must not take the shell down

    // Bind these in hyprland.lua — see hyprland-binds.lua.
    // "palette" accepts both kinds of bind: a normal bind delivers press then release,
    // while a release bind (tap-SUPER) may deliver only the release. Either way it toggles once.
    GlobalShortcut {
        property bool down: false
        appid: "lovelyrice"
        name: "palette"
        description: "Toggle the launcher / command palette (closes any open popup)"
        onPressed: { console.log("LovelyRice: palette pressed"); down = true; root.mainToggle() }
        onReleased: {
            console.log("LovelyRice: palette released (press seen:", down + ")")
            if (!down) root.mainToggle()
            down = false
        }
    }
    GlobalShortcut {
        appid: "lovelyrice"; name: "themes"; description: "Open the palette on /scheme"
        onPressed: { console.log("LovelyRice: shortcut themes"); palette.openWith("scheme") }
    }
    GlobalShortcut {
        appid: "lovelyrice"; name: "wallpapers"; description: "Open the palette on /wallpaper"
        onPressed: { console.log("LovelyRice: shortcut wallpapers"); palette.openWith("wallpaper") }
    }
    GlobalShortcut {
        appid: "lovelyrice"; name: "calendar"; description: "Toggle the calendar"
        onPressed: cal.toggle()
    }
    GlobalShortcut {
        appid: "lovelyrice"; name: "settings"; description: "Open settings"
        onPressed: settings.toggle()
    }
    GlobalShortcut {
        appid: "lovelyrice"; name: "overview"; description: "Toggle the workspace overview"
        onPressed: { console.log("LovelyRice: shortcut overview"); overview.toggle() }
    }
    GlobalShortcut {
        appid: "lovelyrice"; name: "lock"; description: "Lock the screen"
        onPressed: root.doLock()
    }
    GlobalShortcut {
        appid: "lovelyrice"; name: "nextTheme"; description: "Cycle to the next theme"
        onPressed: Theme.next()
    }
    GlobalShortcut {
        appid: "lovelyrice"; name: "notifications"; description: "Toggle the notification history"
        onPressed: notifPanel.toggle()
    }
    GlobalShortcut {
        appid: "lovelyrice"; name: "dropdown"; description: "Toggle the dropdown panel"
        onPressed: dropdown.toggle()
    }

    // CLI: qs -c lovelyrice ipc call rice toggle
    IpcHandler {
        target: "rice"
        function toggle(): void { root.mainToggle() }
        function open(mode: string): void { palette.openWith(mode) }
        function calendar(): void { cal.toggle() }
        function settings(): void { settings.toggle() }
        function lock(): void { root.doLock() }
        function notifications(): void { notifPanel.toggle() }
        function dropdown(): void { dropdown.toggle() }
        function dnd(): void { Notifs.dnd = !Notifs.dnd }
        function screenshot(mode: string): void { Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/screenshot.sh"), mode === "screen" ? "screen" : "region"]) }
        function record(region: bool): void { Recorder.active ? Recorder.stop() : Recorder.start(region) }
        function music(action: string): void { if (action === "next") Music.next(); else if (action === "prev") Music.prev(); else Music.toggle() }
        function network(): void { palette.openWith("network") }
        function bluetooth(): void { palette.openWith("bluetooth") }
        function control(): void { palette.openWith("control") }
        function overview(): void { overview.toggle() }
        function dashboard(): void { dash.peek() }
        function keys(): void { palette.openWith("keys") }
        function doctor(): void { palette.openWith("doctor") }
        function matchWallpaper(): void { WallpaperColors.apply() }
        function runHooks(): void { Hooks.runNow() }
        function mic(): void { Control.toggleMic() }
        function powerProfile(): void { Control.cycleProfile() }
        function media(): void { mediaPop.peek() }
        function schemeMaker(): void { maker.show() }
        function nextTheme(): void { Theme.next() }
        function setTheme(name: string): void { Theme.select(name); Theme.save() }
        function pluginsReload(): void { Plugins.reload() }
        function pluginStatus(): string { return Plugins.status() }
        // Hyprland integration: on | off | toggle, apply now, and what Hyprland last answered
        function hypr(mode: string): string {
            Settings.set("hyprSync", mode === "on" ? true : (mode === "off" ? false : !Settings.hyprSync))
            return Settings.hyprSync ? "on" : "off"
        }
        function hyprApply(): void { HyprTheme.applyNow() }
        function bar(): string { return Settings.barPosition }
        function setBar(position: string): string {
            if (Settings.barPositions.indexOf(position) < 0)
                return "unknown position '" + position + "' (use " + Settings.barPositions.join(", ") + ")"
            Settings.set("barPosition", position)
            return position
        }
        // visibility: always | autohide | hidden
        function barMode(): string { return Settings.barVisibility }
        function setBarMode(mode: string): string {
            if (Settings.enums.barVisibility.indexOf(mode) < 0)
                return "unknown mode '" + mode + "' (use " + Settings.enums.barVisibility.join(", ") + ")"
            Settings.set("barVisibility", mode)
            return mode
        }
        function toggleBar(): string {
            if (Settings.barVisibility === "hidden") Settings.set("barVisibility", root.barBeforeHide)
            else { root.barBeforeHide = Settings.barVisibility; Settings.set("barVisibility", "hidden") }
            return Settings.barVisibility
        }
        // looks (the presets of /settings -> Style)
        function looks(): string { return Settings.presetNames.join(" ") }
        function setLook(name: string): string {
            if (Settings.presetNames.indexOf(name) < 0)
                return "unknown look '" + name + "' (use " + Settings.presetNames.join(", ") + ")"
            Settings.applyPreset(name)
            return name
        }
        // the split bar: on | off | toggle, and where bar 2 sits
        function split(mode: string): string {
            Settings.set("barSplit", mode === "on" ? true : (mode === "off" ? false : !Settings.barSplit))
            return Settings.barSplit ? "on" : "off"
        }
        function bar2(): string { return Settings.barSplit ? Settings.bar2Position : "off" }
        function setBar2(position: string): string {
            if (Settings.barPositions.indexOf(position) < 0)
                return "unknown position '" + position + "' (use " + Settings.barPositions.join(", ") + ")"
            Settings.set("bar2Position", position)
            return Settings.bar2Position
        }
    }
}
