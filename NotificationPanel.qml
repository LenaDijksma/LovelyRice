import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Notification history popout, bottom-right. Toggle with SUPER + N
// (or: qs -c lovelyrice ipc call rice notifications). ✕ removes one, "clear all" empties it.
// "dnd" silences popups (critical ones still show); history keeps recording. Esc closes once the panel is clicked.
PanelWindow {
    id: win
    readonly property int cardWidth: 380
    readonly property int maxList: 440

    property bool open: false
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(280); easing.type: Easing.OutCubic } }
    property double now: Date.now()

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

    function show() { Popups.claim("notifications"); now = Date.now(); open = true; keys.forceActiveFocus() }
    function hide() { open = false }
    function toggle() { open ? hide() : show() }

    function ago(t) {
        const s = Math.max(0, Math.floor((win.now - t) / 1000))
        if (s < 60) return "now"
        const m = Math.floor(s / 60)
        if (m < 60) return m + "m"
        const h = Math.floor(m / 60)
        if (h < 24) return h + "h"
        return Math.floor(h / 24) + "d"
    }
    Timer { interval: 30000; repeat: true; running: win.open; onTriggered: win.now = Date.now() }

    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    anchors { bottom: true; right: true }
    margins.right: Settings.side === "right" ? Theme.gap * 2 + Theme.barWidth : 0
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
        height: 56 + (Notifs.history.length === 0 ? 90 : Math.min(list.contentHeight, win.maxList) + 10)
        Behavior on height { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutCubic } }
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

        Text {
            x: 20; y: 16
            text: "Notifications"
            color: Theme.fg
            font { family: Theme.font; pixelSize: 16; bold: true }
        }
        Row {
            anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 15 }
            spacing: 6
            NotifButton { label: "dnd"; active: Notifs.dnd; onClicked: Notifs.dnd = !Notifs.dnd }
            NotifButton { label: "clear all"; visible: Notifs.history.length > 0; onClicked: Notifs.clear() }
        }

        Text {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 68 }
            visible: Notifs.history.length === 0
            text: Notifs.dnd ? "do not disturb is on" : "no notifications"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 13 }
        }

        ListView {
            id: list
            anchors {
                left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom
                leftMargin: 12; rightMargin: 12; topMargin: 56; bottomMargin: 10
            }
            visible: Notifs.history.length > 0
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.history

            delegate: Rectangle {
                id: item
                required property var modelData
                readonly property bool critical: modelData.urgency === 2

                width: ListView.view.width
                height: Math.max(58, info.height + 22)
                radius: Theme.radiusSmall + 2
                color: Qt.alpha(Theme.fg, rowHover.hovered ? 0.08 : 0.04)
                border.width: critical ? 1 : 0
                border.color: Qt.alpha(Theme.warn, 0.7)
                Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                HoverHandler { id: rowHover }

                NotifIcon {
                    x: 10; y: 11; width: 34; height: 34
                    icon: item.modelData.icon
                    app: item.modelData.app
                    tint: item.critical ? Theme.warn : Theme.accent
                }
                Column {
                    id: info
                    x: 54; y: 11
                    width: parent.width - 54 - 32
                    spacing: 2

                    Text {
                        readonly property bool muted: Notifs.isMuted(item.modelData.app)
                        width: parent.width - (rowHover.hovered ? 40 : 0)
                        text: item.modelData.app + (item.modelData.app !== "" ? "  ·  " : "") + win.ago(item.modelData.time)
                              + (muted ? "  ·  muted" : "")
                        color: Theme.dim
                        elide: Text.ElideRight
                        font { family: Theme.font; pixelSize: 10 }
                    }
                    Text {
                        width: parent.width
                        text: item.modelData.summary
                        color: Theme.fg
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font { family: Theme.font; pixelSize: 13; bold: true }
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: item.modelData.body
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        color: Qt.alpha(Theme.fg, 0.75)
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }
                Row {
                    anchors { top: parent.top; right: parent.right; topMargin: 8; rightMargin: 12 }
                    visible: rowHover.hovered
                    spacing: 14
                    Text {   // mute / unmute everything from this app
                        visible: item.modelData.app !== ""
                        text: Notifs.isMuted(item.modelData.app) ? "unmute" : "mute"
                        color: muteArea.containsMouse ? Theme.fg : Theme.dim
                        font { family: Theme.font; pixelSize: 11 }
                        MouseArea {
                            id: muteArea
                            anchors { fill: parent; margins: -6 }
                            hoverEnabled: true
                            onClicked: Notifs.toggleMute(item.modelData.app)
                        }
                    }
                    Text {
                        text: "✕"
                        color: delArea.containsMouse ? Theme.fg : Theme.dim
                        font { family: Theme.font; pixelSize: 11 }
                        MouseArea {
                            id: delArea
                            anchors { fill: parent; margins: -8 }
                            hoverEnabled: true
                            onClicked: Notifs.remove(item.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
