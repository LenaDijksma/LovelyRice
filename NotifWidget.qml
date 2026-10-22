import QtQuick

// Bell with an unread-count badge. Click opens the notification history, right-click toggles do-not-disturb.
// While do-not-disturb is on the bell is dimmed and slashed (the badge keeps counting what you miss).
Item {
    id: root
    readonly property bool horizontal: Bar.horizontalFor(root)       // which way this bar runs (a split bar can have one of each)
    signal clicked()
    readonly property int count: Math.min(Notifs.unread, Notifs.history.length)
    visible: Settings.showNotifications
    implicitWidth: root.horizontal ? (visible ? Theme.iconSize + 8 : 0) : Theme.cell
    implicitHeight: root.horizontal ? Theme.cell : (visible ? Theme.iconSize + 8 : 0)
    scale: area.pressed ? 0.9 : (area.containsMouse ? 1.1 : 1.0)
    Behavior on scale { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutBack } }

    Icon {
        id: bell
        anchors.centerIn: parent
        width: Theme.iconSize; height: Theme.iconSize
        kind: Notifs.dnd ? "bell-off" : "bell"
        color: Notifs.dnd ? Theme.dim : (root.count > 0 ? Theme.accent : Theme.fg)
        Behavior on color { ColorAnimation { duration: Theme.dur(250) } }
    }
    Rectangle {   // badge
        visible: root.count > 0
        height: Math.max(12, Theme.fs(13))
        width: Math.max(height, badgeText.implicitWidth + 6)
        radius: height / 2
        anchors { right: bell.right; top: bell.top; rightMargin: -5; topMargin: -4 }
        color: Notifs.dnd ? Theme.dim : Theme.accent
        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.count > 9 ? "9+" : root.count
            color: Theme.bg
            font { family: Theme.font; pixelSize: Theme.fs(9); bold: true }
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => { if (mouse.button === Qt.RightButton) Notifs.dnd = !Notifs.dnd; else root.clicked() }
    }
}
