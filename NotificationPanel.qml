import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Notification history popout, bottom-right (the same list is a card in the dropdown panel). Toggle with SUPER + N
// (or: qs -c lovelyrice ipc call rice notifications). ✕ removes one, "clear all" empties it.
// "dnd" silences popups (critical ones still show); history keeps recording. Esc closes once the panel is clicked.
PanelWindow {
    id: win
    readonly property int cardWidth: 380
    readonly property int maxList: 440

    property bool open: false
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(280); easing.type: Easing.OutCubic } }

    onOpenChanged: {
        Popups.report("notifications", open)
        Notifs.panelOpen = open
        if (open) Notifs.markRead()
    }
    Connections {
        target: Popups
        function onCloseOthers(except) { if (except !== "notifications" && win.open) win.hide() }
        function onCloseAll() { if (win.open) win.hide() }
    }

    function show() { Popups.claim("notifications"); open = true; keys.forceActiveFocus() }
    function hide() { open = false }
    function toggle() { open ? hide() : show() }


    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    anchors { bottom: true; right: true }
    // keep clear of the bar(s) when one is on the right or along the bottom
    margins.right: Bar.insetOn("right")
    margins.bottom: Bar.insetOn("bottom")
    implicitWidth: cardWidth + Theme.gap + Theme.shadowPad
    implicitHeight: 56 + maxList + 10 + Theme.gap + Theme.shadowPad
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: progress > 0.001
    mask: Region { item: card }
    WlrLayershell.namespace: "lovelyrice-notification-history"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Card {
        id: card
        width: win.cardWidth
        height: body.implicitHeight
        x: parent.width - width - Theme.gap + (1 - win.progress) * 40
        y: parent.height - height - Theme.gap
        opacity: win.progress
        radius: Theme.radius + 4
        color: Qt.alpha(Theme.bg, 0.97)
        borderColor: Qt.alpha(Theme.accent, 0.7)
        borderWidth: 2
        shadowY: 12

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => { if (e.key === Qt.Key_Escape) { win.hide(); e.accepted = true } }
        }

        NotificationsCard { id: body; anchors.fill: parent; maxList: win.maxList }
    }
}
