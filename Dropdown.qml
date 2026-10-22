import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Dropdown panel: dashboard, control, media and notifications as TABS in one panel that is attached to a screen edge
// (Settings.dropdownPosition, top by default), centered along it and at most half as wide as the room the bar leaves.
// Unlike the floating popouts it is flush with the screen (only its inner corners are rounded), has a tab strip, and its tabs
// are laid out and styled on their own (DropDashboard, DropControl, DropMedia, DropNotifs). If that edge is the utility bar's,
// the panel stops beyond the bar instead of under it and floats like the bar does.
// Toggle with the "dropdown" shortcut (SUPER + D), `lovelyrice dropdown`, or the hot edge (DropdownEdge.qml).
// ← → or 1-4 switch tab, Esc or a click outside closes it. Tabs are shown, hidden and ordered in /settings → Dropdown.
PanelWindow {
    id: win

    property bool open: false
    property bool byHover: false              // opened by the hot edge: closes again when the pointer leaves, and never grabs clicks
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(380); easing.type: Easing.OutCubic } }

    readonly property string pos: Settings.dropdownPosition                 // top | bottom | left | right
    readonly property bool horizontal: pos === "top" || pos === "bottom"    // runs along the top or bottom edge
    readonly property bool flush: !Bar.occupies(pos)                        // no bar on its edge: sits right against the screen
    readonly property real dist: flush ? 0 : Bar.inset                      // from the screen edge to the panel
    readonly property real over: flush ? Theme.radius : 0                   // the panel reaches this far off screen, hiding its outer corners
    // where the panel starts and ends along its edge: clear of the bar if the bar is on a neighbouring edge
    readonly property real startM: horizontal ? (Bar.occupies("left") ? Bar.inset : (flush ? 0 : Theme.gap))
                                              : (Bar.occupies("top") ? Bar.inset : (flush ? 0 : Theme.gap))
    readonly property real endM: horizontal ? (Bar.occupies("right") ? Bar.inset : (flush ? 0 : Theme.gap))
                                            : (Bar.occupies("bottom") ? Bar.inset : (flush ? 0 : Theme.gap))
    readonly property int pad: 14
    readonly property int tabH: 38
    // The panel is never wider than half the room the bar leaves (a little more only on a very small screen)
    readonly property real availW: win.width - Bar.insetOn("left") - Bar.insetOn("right")
    readonly property real panelW: Math.min(availW, Math.max(availW * 0.5, 480))
    readonly property real leftOff: Bar.insetOn("left")

    onOpenChanged: {
        Popups.report("dropdown", open)
        if (tabOn("notifications")) { Notifs.panelOpen = open && current === "notifications"; if (Notifs.panelOpen) Notifs.markRead() }
    }
    Connections {
        target: Popups
        function onCloseOthers(except) { if (except !== "dropdown" && win.open) win.hide() }
        function onCloseAll() { if (win.open) win.hide() }
    }

    function show(hover) {
        Popups.claim("dropdown")
        byHover = hover === true
        open = true
        if (byHover) { leaveTimer.interval = 1500; leaveTimer.restart() }
        else keys.forceActiveFocus()
    }
    function hide() { open = false }
    function toggle() { open ? hide() : show(false) }

    // opened by the hot edge: close once the pointer has been off the panel for a moment
    property bool cardHover: false
    onCardHoverChanged: if (byHover) { leaveTimer.interval = 600; leaveTimer.restart() }
    Timer { id: leaveTimer; onTriggered: if (win.open && win.byHover && !win.cardHover) win.hide() }

    // ---- tabs ----
    property string tabId: ""
    readonly property var tabNames: ({ dashboard: "Dashboard", control: "Control", media: "Media", notifications: "Notifications" })
    function tabName(id) { return tabNames[id] || (id.indexOf("plugin:") === 0 ? Plugins.cardTitle(id.slice(7)) : id) }
    function tabOn(id) {
        if (id.indexOf("plugin:") === 0) return Plugins.cardComponent(id.slice(7)) !== null    // a plugin tab exists while its plugin runs
        switch (id) {
        case "dashboard":     return Settings.dropdownDashboard
        case "control":       return Settings.dropdownControl
        case "media":         return Settings.dropdownMedia && Music.player !== null
        case "notifications": return Settings.dropdownNotifications
        }
        return false
    }
    readonly property var tabs: Settings.dropdownOrder.filter(id => tabOn(id))
    readonly property string current: tabs.indexOf(tabId) >= 0 ? tabId : (tabs.length > 0 ? tabs[0] : "")
    function stepTab(d) { if (tabs.length > 0) tabId = tabs[(tabs.indexOf(current) + d + tabs.length) % tabs.length] }
    onCurrentChanged: {
        if (tabOn("notifications") && open) { Notifs.panelOpen = current === "notifications"; if (Notifs.panelOpen) Notifs.markRead() }
    }
    // built-in tabs: an id -> Component entry. A plugin's tab ("plugin:<name>") comes from Plugins.cardComponent instead;
    // its card gets the panel's width and should set an implicitHeight.
    readonly property var parts: ({ dashboard: cDash, control: cControl, media: cMedia, notifications: cNotif })
    function part(id) { return id.indexOf("plugin:") === 0 ? Plugins.cardComponent(id.slice(7)) : parts[id] }

    // tallest the tab content may be before it scrolls
    readonly property real maxContentH: Math.max(160, win.height * 0.7 - tabH - 2 * pad - 8)

    // ---- window: the whole screen, so a click outside can close it ----
    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: progress > 0.001
    mask: Region { item: win.byHover ? panel : backdrop }
    WlrLayershell.namespace: "lovelyrice-dropdown"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && !byHover ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Item {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) win.hide()
            else if (e.key === Qt.Key_Right || e.key === Qt.Key_Tab) win.stepTab(1)
            else if (e.key === Qt.Key_Left || e.key === Qt.Key_Backtab) win.stepTab(-1)
            else if (e.key >= Qt.Key_1 && e.key < Qt.Key_1 + win.tabs.length) win.tabId = win.tabs[e.key - Qt.Key_1]
            else return
            e.accepted = true
        }
    }
    Item {
        id: backdrop
        anchors.fill: parent
        MouseArea { anchors.fill: parent; enabled: win.open; onClicked: win.hide() }
    }

    Card {
        id: panel
        readonly property real contentH: Math.min(body.height, win.maxContentH)
        width: Math.max(0, win.panelW + (win.horizontal ? 0 : win.over))
        height: win.horizontal ? win.pad + win.tabH + 9 + contentH + win.pad + win.over
                               : Math.max(0, parent.height - win.startM - win.endM)
        Behavior on height { enabled: win.horizontal; NumberAnimation { duration: Theme.dur(200); easing.type: Easing.OutCubic } }

        // slides in from its edge; `dist - over` is where its inner edge ends up
        x: win.pos === "left"  ? -width + (width + win.dist - win.over) * win.progress
         : win.pos === "right" ? parent.width - (width + win.dist - win.over) * win.progress
         : win.leftOff + (win.availW - win.panelW) / 2
        y: win.pos === "top"    ? -height + (height + win.dist - win.over) * win.progress
         : win.pos === "bottom" ? parent.height - (height + win.dist - win.over) * win.progress
         : win.startM

        opacity: Math.min(1, win.progress * 2)
        color: Qt.alpha(Theme.bg, 0.98)
        radius: Theme.radius + 4
        shadowX: win.pos === "left" ? 3 : (win.pos === "right" ? -3 : 0)
        shadowY: win.pos === "bottom" ? -6 : (win.pos === "top" ? 6 : 0)

        HoverHandler { onHoveredChanged: win.cardHover = hovered }

        // the part of the panel that is on screen (the rest is the hidden overshoot)
        Item {
            id: inner
            x: win.pos === "left" ? win.over : 0
            y: win.pos === "top" ? win.over : 0
            width: panel.width - (win.horizontal ? 0 : win.over)
            height: panel.height - (win.horizontal ? win.over : 0)

            // ---- tab strip ----
            Row {
                id: strip
                y: win.pad
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4
                Repeater {
                    model: win.tabs
                    delegate: Item {
                        id: tab
                        required property string modelData
                        required property int index
                        readonly property bool on: modelData === win.current
                        width: label.implicitWidth + 32
                        height: win.tabH
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: win.tabName(tab.modelData) + (tab.modelData === "notifications" && Notifs.unread > 0 ? "  " + Notifs.unread : "")
                            color: tab.on ? Theme.accent : (tabArea.containsMouse ? Theme.fg : Theme.dim)
                            Behavior on color { ColorAnimation { duration: Theme.dur(140) } }
                            font { family: Theme.font; pixelSize: 13; bold: tab.on }
                        }
                        Rectangle {   // underline
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                            height: 2; radius: 1
                            width: tab.on ? parent.width - 20 : 0
                            color: Theme.accent
                            Behavior on width { NumberAnimation { duration: Theme.dur(220); easing.type: Easing.OutCubic } }
                        }
                        MouseArea { id: tabArea; anchors.fill: parent; hoverEnabled: true; onClicked: win.tabId = tab.modelData }
                    }
                }
            }
            Rectangle {
                x: win.pad; y: win.pad + win.tabH
                width: parent.width - 2 * win.pad; height: 1
                color: Qt.alpha(Theme.dim, 0.25)
            }
            Text {
                anchors.centerIn: parent
                visible: win.tabs.length === 0
                text: "no tabs on — /settings → Dropdown"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 12 }
            }

            // ---- the open tab ----
            Flickable {
                id: scroller
                x: win.pad; y: win.pad + win.tabH + 9
                width: parent.width - 2 * win.pad
                height: parent.height - y - win.pad
                contentWidth: width
                contentHeight: body.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Loader {
                    id: body
                    width: scroller.width
                    height: item ? item.implicitHeight : 0
                    sourceComponent: win.part(win.current)
                }
            }
        }
    }

    // the tabs have their own look (Drop*.qml); the popouts keep theirs (DashboardCard, MediaCard, ...)
    Component { id: cDash; DropDashboard {} }
    Component { id: cControl; DropControl {} }
    Component { id: cMedia; DropMedia {} }
    Component { id: cNotif; DropNotifs {} }
}
