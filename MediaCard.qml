import QtQuick

// Cover art, title, artist, transport buttons and a seek bar for whatever Music.player is playing.
// One body, two homes: the MediaPopout and the dropdown panel. 340 x 136.
Item {
    id: root
    implicitWidth: 340
    implicitHeight: 136
    readonly property var player: Music.player

    function fmt(s) {
        const t = Math.max(0, Math.floor(s))
        const m = Math.floor(t / 60), r = t % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // Mpris only updates `position` when asked to
    Timer {
        interval: 1000; repeat: true
        running: root.visible && root.player !== null && root.player.isPlaying && root.player.positionSupported
        onTriggered: root.player.positionChanged()
    }
    onVisibleChanged: if (visible && player && player.positionSupported) player.positionChanged()

        // ---- cover art ----
        Rectangle {
            id: cover
            x: 14; y: 14; width: 84; height: 84
            radius: Theme.radiusSmall
            color: Theme.surface
            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "♪"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 30 }
            }
            RoundedImage {
                id: art
                anchors.fill: parent
                radius: Theme.radiusSmall
                source: Music.cover
                visible: status === Image.Ready
            }
        }

        // ---- text ----
        Column {
            x: 110; y: 14
            width: root.width - 110 - 16
            spacing: 2
            Text {
                width: parent.width
                text: Music.title !== "" ? Music.title : "Nothing playing"
                color: Theme.fg
                elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 14; bold: true }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: Music.artist
                color: Theme.dim
                elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 12 }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: Music.identity
                color: Qt.alpha(Theme.dim, 0.7)
                elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 10 }
            }
        }

        // ---- transport ----
        Row {
            x: 108; y: 66
            spacing: 6
            Repeater {
                model: ["prev", "toggle", "next"]
                delegate: Rectangle {
                    id: btn
                    required property string modelData
                    width: 38; height: 30; radius: 15
                    color: btnArea.containsMouse ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                    scale: btnArea.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutBack } }
                    Text {
                        anchors.centerIn: parent
                        text: btn.modelData === "prev" ? "«" : (btn.modelData === "next" ? "»" : (Music.playing ? "❚❚" : "▶"))
                        color: btn.modelData === "toggle" ? Theme.accent : Theme.fg
                        font { family: Theme.font; pixelSize: btn.modelData === "toggle" ? 14 : 18 }
                    }
                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (btn.modelData === "prev") Music.prev()
                            else if (btn.modelData === "next") Music.next()
                            else Music.toggle()
                        }
                    }
                }
            }
        }

        // ---- shuffle / repeat (only for players that support them, e.g. ldmp once it exports them) ----
        Row {
            x: 108 + 3 * 38 + 2 * 6 + 10; y: 66
            spacing: 4
            visible: Music.shuffleSupported || Music.loopSupported
            Repeater {
                model: [ "shuffle", "repeat" ]
                delegate: Rectangle {
                    id: mode
                    required property string modelData
                    readonly property bool isShuffle: modelData === "shuffle"
                    readonly property bool supported: isShuffle ? Music.shuffleSupported : Music.loopSupported
                    readonly property bool active: isShuffle ? Music.shuffle : Music.repeat !== "none"
                    visible: supported
                    width: 30; height: 30; radius: 15
                    color: modeArea.containsMouse ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                    scale: modeArea.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutBack } }
                    Text {
                        anchors.centerIn: parent
                        text: mode.isShuffle ? "⇄" : (Music.repeat === "track" ? "↻1" : "↻")
                        color: mode.active ? Theme.accent : Qt.alpha(Theme.dim, 0.8)
                        Behavior on color { ColorAnimation { duration: Theme.dur(160) } }
                        font { family: Theme.font; pixelSize: 15 }
                    }
                    MouseArea {
                        id: modeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: mode.isShuffle ? Music.toggleShuffle() : Music.cycleRepeat()
                    }
                }
            }
        }

        // ---- seek bar ----
        Item {
            id: seek
            x: 14; y: 104; width: parent.width - 28; height: 24
            readonly property real len: root.player && root.player.lengthSupported ? root.player.length : 0
            readonly property real pos: root.player && root.player.positionSupported ? root.player.position : 0
            property real dragFrac: -1                                   // >= 0 while dragging; applied on release
            readonly property real frac: dragFrac >= 0 ? dragFrac
                                         : (len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0)

            Text {
                id: tl
                width: 40
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: root.fmt(seek.frac * seek.len)
                color: Theme.dim
                font { family: Theme.font; pixelSize: 10 }
            }
            Text {
                id: tr
                width: 40
                horizontalAlignment: Text.AlignRight
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: seek.len > 0 ? root.fmt(seek.len) : "–:––"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 10 }
            }
            Rectangle {
                id: seekTrack
                anchors { left: tl.right; right: tr.left; leftMargin: 6; rightMargin: 6; verticalCenter: parent.verticalCenter }
                height: 6; radius: 3
                color: Qt.alpha(Theme.dim, 0.3)
                Rectangle {
                    width: parent.width * seek.frac; height: parent.height; radius: 3
                    color: Theme.accent
                }
                Rectangle {   // knob
                    x: parent.width * seek.frac - 6; y: -3
                    width: 12; height: 12; radius: 6
                    color: Theme.fg
                    opacity: seekArea.containsMouse || seekArea.pressed ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.dur(140) } }
                }
            }
            MouseArea {
                id: seekArea
                anchors { left: seekTrack.left; right: seekTrack.right; top: parent.top; bottom: parent.bottom
                          leftMargin: -6; rightMargin: -6 }
                hoverEnabled: true
                preventStealing: true
                enabled: root.player !== null && root.player.canSeek && seek.len > 0
                function fracAt(mx) { return Math.max(0, Math.min(1, mapToItem(seekTrack, mx, 0).x / seekTrack.width)) }
                onPressed: mouse => seek.dragFrac = fracAt(mouse.x)
                onPositionChanged: mouse => { if (pressed) seek.dragFrac = fracAt(mouse.x) }
                onReleased: { if (seek.dragFrac >= 0) Music.seekTo(seek.dragFrac * seek.len); seek.dragFrac = -1 }
                onCanceled: seek.dragFrac = -1
            }
        }
}
