import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// One utility bar on one edge of one monitor. UtilityBar.qml makes one of these for every (bar, edge) pair and only the ones
// that are wanted are visible. Slides in when it appears, and can sit in the corner as a short bar, be glass, be transparent,
// hide until the pointer pushes against its edge, or be one of two bars (Settings.barSplit).
// Size, position, gap and which modules appear are controlled from /settings. Only the bar itself takes input;
// the transparent shadow margin is click-through.
PanelWindow {
    id: win
    required property var targetScreen
    required property string position     // "left" | "right" | "top" | "bottom"
    required property int barIndex        // 1 = the main bar, 2 = the second bar of a split layout
    readonly property bool horizontal: position === "top" || position === "bottom"
    screen: targetScreen
    property bool shown: false
    property bool revealed: false         // auto-hide: the pointer is on the bar or its edge
    signal launcherRequested()
    signal calendarRequested()
    signal networkRequested()
    signal bluetoothRequested()
    signal notificationsRequested()

    readonly property bool autoHide: Settings.barVisibility === "autohide"
    readonly property bool showing: shown && (!autoHide || revealed)
    // this window is wanted when the bar exists, is on this edge and is not switched off
    visible: Settings.barVisibility !== "hidden" && Settings.barExists(barIndex) && Settings.positionOf(barIndex) === position

    anchors {
        left: position !== "right"
        right: position !== "left"
        top: position !== "bottom"
        bottom: position !== "top"
    }
    // only the size across the bar counts; along it the anchors stretch the window over the screen
    implicitWidth: Theme.gap + Theme.barThickness + Theme.shadowPad
    implicitHeight: Theme.gap + Theme.barThickness + Theme.shadowPad
    // auto-hide bars float over the windows unless you ask them to keep their room
    exclusiveZone: (Settings.barVisibility === "always" || (autoHide && Settings.barReserveSpace)) ? Theme.barThickness + Theme.gap * 2 : 0
    color: "transparent"
    // the bar, plus (auto-hide) a thin strip on the screen edge that brings it back
    mask: Region { item: bar; Region { item: strip } }
    WlrLayershell.namespace: "lovelyrice-sidebar"   // unchanged on purpose: layer rules in your hyprland config may match it

    // slide in whenever this window becomes visible
    Timer { id: showTimer; interval: 80; running: true; onTriggered: win.shown = true }
    onVisibleChanged: { shown = false; revealed = false; if (visible) showTimer.restart() }

    // ---- auto-hide ----
    onAutoHideChanged: revealed = false
    readonly property bool hovering: stripHover.hovered || barHover.hovered
    onHoveringChanged: {
        if (!autoHide) return
        if (hovering) { hideTimer.stop(); revealTimer.restart() }
        else { revealTimer.stop(); hideTimer.restart() }
    }
    Timer { id: revealTimer; interval: 120; onTriggered: win.revealed = true }       // a short dwell, so a pass-by does not pop it out
    Timer {
        id: hideTimer
        interval: Settings.barHideDelay
        onTriggered: { if (Popups.anyOpen || win.hovering) hideTimer.restart(); else win.revealed = false }   // stays while a popup it opened is up
    }

    // ---- two bars: bar 2 stops short of bar 1 where they meet in a corner ----
    function cornerInset(side) {
        if (barIndex !== 2) return 0
        return Settings.barPosition === side ? Theme.barThickness + Theme.gap : 0
    }
    readonly property real startInset: cornerInset(horizontal ? "left" : "top")
    readonly property real endInset: cornerInset(horizontal ? "right" : "bottom")
    // ---- length and alignment along the edge ----
    readonly property real along: horizontal ? width : height
    readonly property real avail: Math.max(0, along - 2 * Theme.gap - startInset - endInset)
    readonly property real barLen: avail * Settings.barLength / 100
    readonly property real barStart: Theme.gap + startInset
                                     + (avail - barLen) * (Settings.barAlign === "start" ? 0 : (Settings.barAlign === "end" ? 1 : 0.5))

    // ---- glass: what is behind the bar (only loaded while a glass style is in use) ----
    Loader {
        id: backdropLoader
        active: Theme.anyGlass && win.visible
        sourceComponent: GlassBackdrop {
            sw: win.targetScreen ? win.targetScreen.width : 1920
            sh: win.targetScreen ? win.targetScreen.height : 1080
            winX: win.position === "right" ? sw - win.width : 0
            winY: win.position === "bottom" ? sh - win.height : 0
        }
    }
    readonly property var backdrop: backdropLoader.item

    Item {      // the hot strip on the screen edge (only has size while auto-hide is on)
        id: strip
        x: win.horizontal ? win.barStart : (win.position === "left" ? 0 : parent.width - width)
        y: !win.horizontal ? win.barStart : (win.position === "top" ? 0 : parent.height - height)
        width: win.horizontal ? win.barLen : (win.autoHide ? 2 : 0)
        height: win.horizontal ? (win.autoHide ? 2 : 0) : win.barLen
        HoverHandler { id: stripHover }
    }

    Card {
        id: bar
        readonly property real hiddenOffset: -(Theme.barThickness + 40)
        readonly property real edge: win.showing ? Theme.gap : hiddenOffset      // distance from the screen edge the bar sits on

        width: win.horizontal ? win.barLen : Theme.barThickness
        height: win.horizontal ? Theme.barThickness : win.barLen
        radius: Theme.barRadius
        // a glass bar draws its own surface; a transparent bar has no fill (its border and shadow, if any, still show)
        color: Theme.glassBar ? Theme.bg : Qt.alpha(Theme.bg, Theme.barAlpha)
        borderColor: Theme.glassBar ? "transparent" : Theme.barBorderTint
        borderWidth: Settings.barBorder
        shadowX: Bar.shadowXFor(win.position)
        shadowY: Bar.shadowYFor(win.position)
        shadowColor: Theme.barShadowTint
        shadowAmount: Theme.barShadowAmount

        x: win.horizontal ? win.barStart
                          : (win.position === "left" ? edge : parent.width - width - edge)
        y: !win.horizontal ? win.barStart
                           : (win.position === "top" ? edge : parent.height - height - edge)
        // the first slide-in bounces; an auto-hide bar slides quickly and smoothly
        Behavior on x { NumberAnimation { duration: Theme.dur(win.autoHide ? 260 : 700); easing.type: win.autoHide ? Easing.OutCubic : Easing.OutBack; easing.overshoot: 1.15 } }
        Behavior on y { NumberAnimation { duration: Theme.dur(win.autoHide ? 260 : 700); easing.type: win.autoHide ? Easing.OutCubic : Easing.OutBack; easing.overshoot: 1.15 } }

        HoverHandler { id: barHover }

        Loader {                // glass bar
            anchors.fill: parent
            active: Theme.glassBar
            sourceComponent: GlassSurface {
                backdrop: win.backdrop
                radius: Theme.barRadius
            }
        }
        Rectangle {             // the border of a glass bar goes on top of the glass
            anchors.fill: parent
            visible: Theme.glassBar && Settings.barBorder > 0
            radius: Theme.barRadius
            color: "transparent"
            border.width: Settings.barBorder
            border.color: Theme.barBorderTint
        }

        // The modules, in the order chosen in /settings -> Bar (only the ones on this bar when it is split). A module that is
        // switched off (or has nothing to show) is not loaded at all, so it leaves no gap. Top to bottom on a left/right bar,
        // left to right on a top/bottom bar.
        GridLayout {
            id: layout
            // what the modules ask their bar (see Bar.horizontalFor / Bar.backdropFor)
            property bool barHorizontal: win.horizontal
            property var glassBackdrop: win.backdrop
            anchors {
                fill: parent
                topMargin: win.horizontal ? Theme.sideMargin : Theme.sideMargin + 4
                bottomMargin: win.horizontal ? Theme.sideMargin : Theme.sideMargin + 4
                leftMargin: win.horizontal ? Theme.sideMargin + 4 : Theme.sideMargin
                rightMargin: win.horizontal ? Theme.sideMargin + 4 : Theme.sideMargin
            }
            flow: win.horizontal ? GridLayout.LeftToRight : GridLayout.TopToBottom
            columns: win.horizontal ? 64 : 1
            rows: win.horizontal ? 1 : 64
            rowSpacing: Settings.moduleSpacing
            columnSpacing: Settings.moduleSpacing

            Repeater {
                model: Settings.modulesFor(win.barIndex)
                delegate: Loader {
                    id: slot
                    required property string modelData
                    // the spacer takes the free room along the bar; everything fills the bar across
                    Layout.fillWidth: win.horizontal ? modelData === "spacer" : true
                    Layout.fillHeight: win.horizontal ? true : modelData === "spacer"
                    active: win.wanted(modelData)
                    visible: active
                    sourceComponent: modelData.indexOf("plugin:") === 0 ? cPlugin : win.parts[modelData]
                    // a plugin module: tell the slot which plugin it shows
                    onLoaded: if (modelData.indexOf("plugin:") === 0) item.pluginName = modelData.slice(7)
                }
            }
        }
    }

    // ---- modules ----
    function wanted(id) {
        if (id.indexOf("plugin:") === 0) return Plugins.barComponent(id.slice(7)) !== null     // a plugin that is off has no module
        switch (id) {
        case "logo":       return Settings.showLogo
        case "workspaces": return Settings.showWorkspaces
        case "spacer":     return true
        case "media":      return Settings.showMedia && Music.player !== null
        case "status":     return Settings.showStats || Settings.showAudio || Settings.showBattery
                                  || Settings.showNetwork || Settings.showBluetooth || Settings.showNotifications
        case "brightness": return Brightness.available && Settings.showBrightness
        case "buttons":    return Settings.showButtons
        case "recording":  return Recorder.active
        case "clock":      return Settings.showClock
        }
        return false
    }
    readonly property var parts: ({
        logo: cLogo, workspaces: cWorkspaces, spacer: cSpacer, media: cMedia, status: cStatus,
        brightness: cBrightness, buttons: cButtons, recording: cRecording, clock: cClock
    })

    Component { id: cSpacer; Item {} }
    Component { id: cPlugin; PluginSlot {} }
    Component {
        id: cLogo
        Item {
            implicitWidth: logo.implicitWidth
            implicitHeight: logo.implicitHeight
            Logo { id: logo; anchors.centerIn: parent }
        }
    }
    Component {
        id: cWorkspaces
        Pill {
            Workspaces { monitorName: win.targetScreen.name }
        }
    }
    Component { id: cMedia; Media {} }
    Component {
        id: cStatus
        Pill {
            SystemStats { visible: Settings.showStats }
            Audio {}
            Battery {}
            NetworkWidget   { onClicked: win.networkRequested() }
            BluetoothWidget { onClicked: win.bluetoothRequested() }
            NotifWidget     { onClicked: win.notificationsRequested() }
        }
    }
    Component {
        id: cBrightness
        Pill {
            BrightnessSlider { compact: win.along < 820 }
        }
    }
    Component {
        id: cButtons
        Pill {
            spacing: 2
            BarButton { glyph: "⊞"; onClicked: win.launcherRequested() }
            BarButton { glyph: "◐"; onClicked: Theme.next() }
        }
    }
    Component { id: cRecording; RecIndicator {} }
    Component {
        id: cClock
        Pill {
            Clock { onClicked: win.calendarRequested() }
        }
    }
}
