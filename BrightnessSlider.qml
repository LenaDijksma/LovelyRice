import QtQuick

// Vertical brightness slider for the sidebar. Drag or click the track, scroll to nudge by 5%.
// Hidden on machines without a backlight, or when turned off in /settings.
Item {
    id: root
    property bool compact: false          // shorter track on small screens
    readonly property int trackLen: compact ? 40 : 72
    readonly property real frac: Brightness.value < 0 ? 0 : Math.min(1, Brightness.value)

    visible: Brightness.available && Settings.showBrightness
    implicitWidth: Theme.cell
    implicitHeight: visible ? Theme.iconSize + 6 + trackLen + 6 + Theme.fs(10) + 4 : 0

    Icon {
        id: icon
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
        width: Theme.iconSize; height: Theme.iconSize
        kind: "brightness"
        color: area.pressed || area.containsMouse ? Theme.accent : Theme.fg
    }

    Rectangle {
        id: track
        anchors { top: icon.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
        width: 8; height: root.trackLen
        radius: 4
        color: Qt.alpha(Theme.dim, 0.35)
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.max(parent.width, parent.height * root.frac)
            radius: 4
            color: Theme.accent
            Behavior on height { enabled: !area.pressed; NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutCubic } }
        }
        Rectangle {   // knob
            width: 14; height: 14; radius: 7
            anchors.horizontalCenter: parent.horizontalCenter
            y: (1 - root.frac) * (parent.height - height)
            color: Theme.fg
            border.color: Theme.bg; border.width: 2
            opacity: area.containsMouse || area.pressed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(140) } }
        }
    }

    Text {
        anchors { top: track.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
        text: Math.round(root.frac * 100) + "%"
        color: Theme.dim
        font { family: Theme.font; pixelSize: Theme.fs(10) }
    }

    // scroll anywhere on the widget
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => Brightness.step(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
    }
    // drag on the track (a little wider than it looks, so it is easy to grab)
    MouseArea {
        id: area
        anchors { left: parent.left; right: parent.right; top: track.top; bottom: track.bottom; topMargin: -6; bottomMargin: -6 }
        hoverEnabled: true
        preventStealing: true
        function setFrom(my) {
            const y = mapToItem(track, 0, my).y
            Brightness.set(1 - Math.max(0, Math.min(1, y / track.height)))
        }
        onPressed: mouse => { Brightness.dragging = true; setFrom(mouse.y) }
        onPositionChanged: mouse => { if (pressed) setFrom(mouse.y) }
        onReleased: Brightness.dragging = false
        onCanceled: Brightness.dragging = false
    }
}
