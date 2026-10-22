import QtQuick

// Brightness slider for the bar: vertical on a left/right bar, horizontal on a top/bottom bar.
// Drag or click the track, scroll to nudge by 5%.
// Hidden on machines without a backlight, or when turned off in /settings.
Item {
    id: root
    property bool compact: false          // shorter track on small screens
    readonly property bool horizontal: Bar.horizontalFor(root)
    readonly property int trackLen: horizontal ? (compact ? 56 : 90) : (compact ? 40 : 72)
    readonly property int pctWidth: Math.round(Theme.fs(10) * 2.5)    // room for "100%" so the bar does not jiggle
    readonly property real frac: Brightness.value < 0 ? 0 : Math.min(1, Brightness.value)

    visible: Brightness.available && Settings.showBrightness
    implicitWidth: horizontal ? (visible ? Theme.iconSize + 6 + trackLen + 6 + pctWidth : 0) : Theme.cell
    implicitHeight: horizontal ? Theme.cell : (visible ? Theme.iconSize + 6 + trackLen + 6 + Theme.fs(10) + 4 : 0)

    Icon {
        id: icon
        x: root.horizontal ? 0 : (root.width - width) / 2
        y: root.horizontal ? (root.height - height) / 2 : 0
        width: Theme.iconSize; height: Theme.iconSize
        kind: "brightness"
        color: area.pressed || area.containsMouse ? Theme.accent : Theme.fg
    }

    Rectangle {
        id: track
        x: root.horizontal ? icon.width + 6 : (root.width - width) / 2
        y: root.horizontal ? (root.height - height) / 2 : icon.height + 6
        width: root.horizontal ? root.trackLen : 8
        height: root.horizontal ? 8 : root.trackLen
        radius: 4
        color: Qt.alpha(Theme.dim, 0.35)
        Rectangle {   // fill: grows from the bottom (vertical) or from the left (horizontal)
            x: 0
            y: root.horizontal ? 0 : parent.height - height
            width: root.horizontal ? Math.max(parent.height, parent.width * root.frac) : parent.width
            height: root.horizontal ? parent.height : Math.max(parent.width, parent.height * root.frac)
            radius: 4
            color: Theme.accent
            Behavior on width  { enabled: !area.pressed; NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutCubic } }
            Behavior on height { enabled: !area.pressed; NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutCubic } }
        }
        Rectangle {   // knob
            width: 14; height: 14; radius: 7
            x: root.horizontal ? root.frac * (parent.width - width) : (parent.width - width) / 2
            y: root.horizontal ? (parent.height - height) / 2 : (1 - root.frac) * (parent.height - height)
            color: Theme.fg
            border.color: Theme.bg; border.width: 2
            opacity: area.containsMouse || area.pressed ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(140) } }
        }
    }

    Text {
        x: root.horizontal ? track.x + track.width + 6 : (root.width - width) / 2
        y: root.horizontal ? (root.height - height) / 2 : track.y + track.height + 6
        width: root.horizontal ? root.pctWidth : implicitWidth
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
        x: root.horizontal ? track.x - 6 : 0
        y: root.horizontal ? 0 : track.y - 6
        width: root.horizontal ? track.width + 12 : root.width
        height: root.horizontal ? root.height : track.height + 12
        hoverEnabled: true
        preventStealing: true
        function setFrom(mx, my) {
            const p = mapToItem(track, mx, my)
            const f = root.horizontal ? p.x / track.width : 1 - p.y / track.height
            Brightness.set(Math.max(0, Math.min(1, f)))
        }
        onPressed: mouse => { Brightness.dragging = true; setFrom(mouse.x, mouse.y) }
        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x, mouse.y) }
        onReleased: Brightness.dragging = false
        onCanceled: Brightness.dragging = false
    }
}
