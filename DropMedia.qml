import QtQuick

// Media tab of the dropdown: large cover, big title, a thin seek line and round transport buttons.
// Laid out across the panel, unlike the compact media popout.
Item {
    id: root
    implicitHeight: 200
    readonly property var player: Music.player
    readonly property int coverSize: 180

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

    Rectangle {
        id: cover
        x: 0; y: 10
        width: root.coverSize; height: root.coverSize
        radius: 4
        color: Qt.alpha(Theme.dim, 0.18)
        Text {
            anchors.centerIn: parent
            visible: art.status !== Image.Ready
            text: "♪"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 56 }
        }
        RoundedImage {
            id: art
            anchors.fill: parent
            radius: 4
            source: Music.cover
            visible: status === Image.Ready
        }
    }

    Column {
        anchors { left: cover.right; leftMargin: 26; right: parent.right; top: cover.top; bottom: cover.bottom }
        spacing: 4

        Text {
            width: parent.width
            visible: text !== ""
            text: Music.identity.toUpperCase()
            color: Theme.accent
            elide: Text.ElideRight
            font { family: Theme.font; pixelSize: 10; letterSpacing: 1.6 }
        }
        Text {
            width: parent.width
            text: Music.title !== "" ? Music.title : "Nothing playing"
            color: Theme.fg
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font { family: Theme.font; pixelSize: 22; bold: true }
        }
        Text {
            width: parent.width
            visible: text !== ""
            text: Music.artist
            color: Theme.dim
            elide: Text.ElideRight
            font { family: Theme.font; pixelSize: 14 }
        }

        Item { width: 1; height: 8 }

        // ---- seek ----
        Item {
            id: seek
            width: parent.width; height: 22
            readonly property real len: root.player && root.player.lengthSupported ? root.player.length : 0
            readonly property real pos: root.player && root.player.positionSupported ? root.player.position : 0
            property real dragFrac: -1
            readonly property real frac: dragFrac >= 0 ? dragFrac : (len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0)
            Rectangle {
                id: line
                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 4 }
                height: 3; radius: 1.5
                color: Qt.alpha(Theme.dim, 0.3)
                Rectangle { width: parent.width * seek.frac; height: parent.height; radius: 1.5; color: Theme.accent }
                Rectangle {
                    width: 10; height: 10; radius: 2
                    x: parent.width * seek.frac - width / 2; anchors.verticalCenter: parent.verticalCenter
                    color: Theme.fg
                    opacity: seekArea.containsMouse || seekArea.pressed ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.dur(140) } }
                }
            }
            Text {
                text: root.fmt(seek.frac * seek.len)
                color: Theme.dim
                anchors { left: parent.left; bottom: parent.bottom }
                font { family: Theme.font; pixelSize: 10 }
            }
            Text {
                text: seek.len > 0 ? root.fmt(seek.len) : "–:––"
                color: Theme.dim
                anchors { right: parent.right; bottom: parent.bottom }
                font { family: Theme.font; pixelSize: 10 }
            }
            MouseArea {
                id: seekArea
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom }
                hoverEnabled: true
                preventStealing: true
                enabled: root.player !== null && root.player.canSeek && seek.len > 0
                function fracAt(mx) { return Math.max(0, Math.min(1, mx / width)) }
                onPressed: mouse => seek.dragFrac = fracAt(mouse.x)
                onPositionChanged: mouse => { if (pressed) seek.dragFrac = fracAt(mouse.x) }
                onReleased: { if (seek.dragFrac >= 0) Music.seekTo(seek.dragFrac * seek.len); seek.dragFrac = -1 }
                onCanceled: seek.dragFrac = -1
            }
        }

        // ---- transport ----
        Row {
            spacing: 12
            Repeater {
                model: ["prev", "toggle", "next"]
                delegate: Rectangle {
                    id: btn
                    required property string modelData
                    readonly property bool main: modelData === "toggle"
                    width: main ? 46 : 36; height: width; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: main ? (bArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : "transparent"
                    border.width: main ? 0 : 1
                    border.color: Qt.alpha(Theme.dim, bArea.containsMouse ? 0.9 : 0.5)
                    scale: bArea.pressed ? 0.92 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.dur(120); easing.type: Easing.OutBack } }
                    Text {
                        anchors.centerIn: parent
                        text: btn.modelData === "prev" ? "«" : (btn.modelData === "next" ? "»" : (Music.playing ? "❚❚" : "▶"))
                        color: btn.main ? Theme.bg : Theme.fg
                        font { family: Theme.font; pixelSize: btn.main ? 16 : 17 }
                    }
                    MouseArea {
                        id: bArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: btn.modelData === "prev" ? Music.prev() : (btn.modelData === "next" ? Music.next() : Music.toggle())
                    }
                }
            }
            Item { width: 6; height: 1; visible: Music.shuffleSupported || Music.loopSupported }
            Repeater {
                model: ["shuffle", "repeat"]
                delegate: Item {
                    id: mode
                    required property string modelData
                    readonly property bool isShuffle: modelData === "shuffle"
                    readonly property bool supported: isShuffle ? Music.shuffleSupported : Music.loopSupported
                    readonly property bool active: isShuffle ? Music.shuffle : Music.repeat !== "none"
                    visible: supported
                    width: 30; height: 46
                    Text {
                        anchors.centerIn: parent
                        text: mode.isShuffle ? "⇄" : (Music.repeat === "track" ? "↻1" : "↻")
                        color: mode.active ? Theme.accent : Qt.alpha(Theme.dim, 0.8)
                        font { family: Theme.font; pixelSize: 16 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: mode.isShuffle ? Music.toggleShuffle() : Music.cycleRepeat() }
                }
            }
        }
    }
}
