import QtQuick
import Quickshell.Services.Mpris

// No player running → this widget has zero height and the sidebar is unaffected.
// Click = play/pause, scroll = next/previous, hover = media popout (cover art, seek bar).
Item {
    id: root
    readonly property var player: Music.player   // whatever is playing, otherwise ldmp
    visible: player !== null && Settings.showMedia
    implicitHeight: player !== null ? col.implicitHeight : 0

    Column {
        id: col
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
    // lets the popout line up with this widget
    function reportPos() { Music.widgetY = root.mapToItem(null, 0, root.height / 2).y }

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
