import QtQuick
import Quickshell.Services.Pipewire

// Hidden when PipeWire has no default sink or when turned off in /settings.
// Click = mute, scroll = volume.
Item {
    id: root
    readonly property bool horizontal: Bar.horizontalFor(root)       // which way this bar runs (a split bar can have one of each)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real vol: ready ? sink.audio.volume : 0
    readonly property bool muted: ready && sink.audio.muted
    visible: ready && Settings.showAudio
    // icon above the percentage on a left/right bar, next to it on a top/bottom bar
    implicitWidth: root.horizontal ? (visible ? stack.implicitWidth + 4 : 0) : Theme.cell
    implicitHeight: root.horizontal ? Theme.cell : (visible ? Theme.iconSize + Theme.fs(10) + 6 : 0)

    PwObjectTracker { objects: [root.sink] }

    BarStack {
        id: stack
        anchors.centerIn: parent
        spacing: root.horizontal ? 4 : 1
        Icon {
            width: Theme.iconSize; height: Theme.iconSize
            kind: root.muted ? "muted" : "volume"
            level: root.vol
            color: root.muted ? Theme.dim : Theme.fg
        }
        Text {
            // a fixed width on a top/bottom bar so the bar does not jiggle as the volume changes
            width: root.horizontal ? Math.max(implicitWidth, Math.round(Theme.fs(10) * 2.5)) : implicitWidth
            horizontalAlignment: root.horizontal ? Text.AlignLeft : Text.AlignHCenter
            text: root.muted ? "mute" : Math.round(root.vol * 100) + "%"
            color: Theme.dim
            font { family: Theme.font; pixelSize: Theme.fs(10) }
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: if (root.ready) root.sink.audio.muted = !root.sink.audio.muted
        onWheel: wheel => {
            if (!root.ready) return
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
            root.sink.audio.volume = Math.max(0, Math.min(1.0, root.sink.audio.volume + step))
        }
    }
}
