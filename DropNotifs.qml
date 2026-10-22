import QtQuick

// Notifications tab of the dropdown: a plain ruled list with text actions in the header.
// Same data as the notification history popout, shown without its tinted rounded rows.
Item {
    id: root
    property int maxList: 380
    implicitHeight: head.height + 8 + (Notifs.history.length === 0 ? 70 : Math.min(list.contentHeight, maxList))
    Behavior on implicitHeight { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutCubic } }

    property double now: Date.now()
    function ago(t) {
        const s = Math.max(0, Math.floor((root.now - t) / 1000))
        if (s < 60) return "now"
        const m = Math.floor(s / 60)
        if (m < 60) return m + "m"
        const h = Math.floor(m / 60)
        if (h < 24) return h + "h"
        return Math.floor(h / 24) + "d"
    }
    Timer { interval: 30000; repeat: true; running: root.visible; onTriggered: root.now = Date.now() }
    onVisibleChanged: if (visible) now = Date.now()

    Item {
        id: head
        width: parent.width; height: 24
        DropHeader { anchors { left: parent.left; right: actions.left; rightMargin: 12; verticalCenter: parent.verticalCenter }
                     text: "notifications" + (Notifs.history.length > 0 ? "  ·  " + Notifs.history.length : "") }
        Row {
            id: actions
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 16
            Repeater {
                model: [
                    { id: "dnd", label: Notifs.dnd ? "dnd: on" : "dnd: off", on: Notifs.dnd, show: true },
                    { id: "clear", label: "clear all", on: false, show: Notifs.history.length > 0 }
                ]
                delegate: Text {
                    id: act
                    required property var modelData
                    visible: modelData.show
                    text: modelData.label
                    color: modelData.on ? Theme.accent : (actArea.containsMouse ? Theme.fg : Theme.dim)
                    font { family: Theme.font; pixelSize: 11; underline: actArea.containsMouse }
                    MouseArea {
                        id: actArea
                        anchors { fill: parent; margins: -4 }
                        hoverEnabled: true
                        onClicked: act.modelData.id === "dnd" ? Notifs.dnd = !Notifs.dnd : Notifs.clear()
                    }
                }
            }
        }
    }

    Text {
        anchors { horizontalCenter: parent.horizontalCenter; top: head.bottom; topMargin: 28 }
        visible: Notifs.history.length === 0
        text: Notifs.dnd ? "do not disturb is on" : "no notifications"
        color: Theme.dim
        font { family: Theme.font; pixelSize: 13 }
    }

    ListView {
        id: list
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 8 }
        height: Math.min(contentHeight, root.maxList)
        visible: Notifs.history.length > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: Notifs.history

        delegate: Item {
            id: item
            required property var modelData
            readonly property bool critical: modelData.urgency === 2
            width: ListView.view.width
            height: Math.max(52, info.height + 20)
            HoverHandler { id: rowHover }

            Rectangle {   // hairline between rows
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 1; color: Qt.alpha(Theme.dim, 0.18)
            }
            Rectangle {   // urgent marker
                visible: item.critical
                x: 0; y: 10; width: 2; height: parent.height - 20; radius: 1
                color: Theme.warn
            }
            NotifIcon {
                x: 10; y: 10; width: 30; height: 30
                icon: item.modelData.icon
                app: item.modelData.app
                tint: item.critical ? Theme.warn : Theme.accent
            }
            Column {
                id: info
                x: 52; y: 10
                width: parent.width - 52 - 70
                spacing: 1
                Text {
                    width: parent.width
                    text: item.modelData.summary
                    color: Theme.fg
                    elide: Text.ElideRight
                    font { family: Theme.font; pixelSize: 12; bold: true }
                }
                Text {
                    width: parent.width
                    visible: text !== ""
                    text: item.modelData.body
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Qt.alpha(Theme.fg, 0.7)
                    font { family: Theme.font; pixelSize: 11 }
                }
            }
            Column {
                anchors { right: parent.right; top: parent.top; topMargin: 10 }
                spacing: 4
                Text {
                    anchors.right: parent.right
                    text: (item.modelData.app !== "" ? item.modelData.app + "  ·  " : "") + root.ago(item.modelData.time)
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: 10 }
                }
                Row {
                    anchors.right: parent.right
                    visible: rowHover.hovered
                    spacing: 12
                    Text {
                        visible: item.modelData.app !== ""
                        text: Notifs.isMuted(item.modelData.app) ? "unmute" : "mute"
                        color: muteArea.containsMouse ? Theme.fg : Theme.dim
                        font { family: Theme.font; pixelSize: 10 }
                        MouseArea {
                            id: muteArea
                            hoverEnabled: true
                            anchors { fill: parent; margins: -4 }
                            onClicked: Notifs.toggleMute(item.modelData.app)
                        }
                    }
                    Text {
                        text: "✕"
                        color: delArea.containsMouse ? Theme.fg : Theme.dim
                        font { family: Theme.font; pixelSize: 10 }
                        MouseArea {
                            id: delArea
                            hoverEnabled: true
                            anchors { fill: parent; margins: -6 }
                            onClicked: Notifs.remove(item.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
