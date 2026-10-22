import QtQuick
import Quickshell.Services.Mpris

// No player running → this widget has zero size and the bar is unaffected.
// Click = play/pause, scroll = next/previous, hover = media popout (cover art, seek bar).
// Left/right bar: play glyph above a short title. Top/bottom bar: glyph and title on one line.
Item {
    id: root
    readonly property var player: Music.player   // whatever is playing, otherwise ldmp
    readonly property bool horizontal: Bar.horizontalFor(root)
    visible: player !== null && Settings.showMedia
    implicitWidth: horizontal ? (player !== null ? row.implicitWidth : 0) : 0
    implicitHeight: horizontal ? Theme.cell : (player !== null ? col.implicitHeight : 0)

    Column {
        id: col
        visible: !root.horizontal
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        spacing: 2
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.player && root.player.isPlaying ? "❚❚" : "▶"
            color: Theme.accent
            font { family: Theme.font; pixelSize: Theme.fs(14) }
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.player ? (root.player.trackTitle || "—") : ""
            color: Theme.dim
            font { family: Theme.font; pixelSize: Theme.fs(9) }
        }
    }

    Row {
        id: row
        visible: root.horizontal
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.player && root.player.isPlaying ? "❚❚" : "▶"
            color: Theme.accent
            font { family: Theme.font; pixelSize: Theme.fs(14) }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 170)
            elide: Text.ElideRight
            text: root.player ? (root.player.trackTitle || "—") : ""
            color: Theme.dim
            font { family: Theme.font; pixelSize: Theme.fs(11) }
        }
    }

    // lets the popout line up with this widget
    function reportPos() {
        const p = root.mapToItem(null, root.width / 2, root.height / 2)
        Music.widgetX = p.x
        Music.widgetY = p.y
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: { root.reportPos(); Music.hoverWidget = true }
        onExited: Music.hoverWidget = false
        onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
        onWheel: wheel => {
            if (!root.player) return
            if (wheel.angleDelta.y > 0 && root.player.canGoNext) root.player.next()
            else if (wheel.angleDelta.y < 0 && root.player.canGoPrevious) root.player.previous()
        }
    }
}
