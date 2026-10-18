import QtQuick
import Quickshell.Services.Pipewire

// Hidden when PipeWire has no default sink or when turned off in /settings.
// Click = mute, scroll = volume.
Item {
    id: root
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real vol: ready ? sink.audio.volume : 0
    readonly property bool muted: ready && sink.audio.muted
    visible: ready && Settings.showAudio
    implicitWidth: Theme.cell
    implicitHeight: visible ? Theme.iconSize + Theme.fs(10) + 6 : 0

    PwObjectTracker { objects: [root.sink] }

    Column {
        anchors.centerIn: parent
        spacing: 1
        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.iconSize; height: Theme.iconSize
            kind: root.muted ? "muted" : "volume"
            level: root.vol
            color: root.muted ? Theme.dim : Theme.fg
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
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
