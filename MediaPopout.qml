import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Mpris

// Media popout: cover art, title, artist, transport buttons and a seek bar, flying out of the sidebar like the
// volume popout. It appears for a few seconds when the track changes, and while you hover the sidebar media
// widget (or the popout itself). `qs -c lovelyrice ipc call rice media` shows it on demand. Turn it off in /settings.
PanelWindow {
    id: win

    readonly property var player: Music.player
    property bool armed: false              // ignore the track that is already playing at startup
    property bool autoShown: false          // track changed recently
    property bool hoverShown: false         // pointer is on the widget or the card
    readonly property bool hovering: Music.hoverWidget || Music.hoverCard
    readonly property bool wanted: Settings.mediaPopout && player !== null && (autoShown || hoverShown)
    property real progress: wanted ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(420); easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

    function peek() { if (player) { autoShown = true; autoTimer.restart() } }
    function fmt(s) {
        const t = Math.max(0, Math.floor(s))
        const m = Math.floor(t / 60), r = t % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    Timer { interval: 2500; running: true; onTriggered: win.armed = true }
    Timer { id: autoTimer; interval: 4500; onTriggered: win.autoShown = false }
    Timer { id: hoverTimer; interval: win.hovering ? 300 : 400; onTriggered: win.hoverShown = win.hovering }
    onHoveringChanged: hoverTimer.restart()

    Connections {
        target: Music
        function onTitleChanged() { if (win.armed && Music.title !== "") win.peek() }
    }
    onVisibleChanged: if (!visible) Music.hoverCard = false

    // Mpris only updates `position` when asked to
    Timer {
        interval: 1000; repeat: true
        running: win.visible && win.player !== null && win.player.isPlaying && win.player.positionSupported
        onTriggered: win.player.positionChanged()
    }
    onWantedChanged: if (wanted && player && player.positionSupported) player.positionChanged()

    // ---- window: right of the sidebar, level with the sidebar media widget, on the focused monitor ----
    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    anchors { left: true; top: true }
    margins.left: Settings.side === "left"
        ? Theme.gap * 2 + Theme.barWidth
        : Math.max(0, (win.screen ? win.screen.width : 1920) - (Theme.gap * 2 + Theme.barWidth) - implicitWidth)
    margins.top: {
        const h = win.screen ? win.screen.height : 1080
        const mid = Music.widgetY >= 0 ? Music.widgetY : h / 2
        return Math.max(0, Math.min(h - implicitHeight, mid - implicitHeight / 2))
    }
    implicitWidth: card.width + 24 + Theme.shadowPad
    implicitHeight: card.height + Theme.shadowPad * 2
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: progress > 0.001
    mask: Region { item: card }
    WlrLayershell.namespace: "lovelyrice-media"

    Card {
        id: card
        width: 340
        height: 136
        anchors.verticalCenter: parent.verticalCenter
        x: Settings.side === "left" ? -width + (width + 14) * win.progress
                                    : parent.width - (width + 14) * win.progress
        opacity: Math.min(1, win.progress * 1.5)
        color: Qt.alpha(Theme.bg, 0.97)
        radius: Theme.radius
        shadowX: Settings.side === "left" ? 4 : -4
        shadowY: 6

        HoverHandler { onHoveredChanged: Music.hoverCard = hovered }

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
            width: card.width - 110 - 16
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
            readonly property real len: win.player && win.player.lengthSupported ? win.player.length : 0
            readonly property real pos: win.player && win.player.positionSupported ? win.player.position : 0
            property real dragFrac: -1                                   // >= 0 while dragging; applied on release
            readonly property real frac: dragFrac >= 0 ? dragFrac
                                         : (len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0)

            Text {
                id: tl
                width: 40
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: win.fmt(seek.frac * seek.len)
                color: Theme.dim
                font { family: Theme.font; pixelSize: 10 }
            }
            Text {
                id: tr
                width: 40
                horizontalAlignment: Text.AlignRight
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: seek.len > 0 ? win.fmt(seek.len) : "–:––"
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
                enabled: win.player !== null && win.player.canSeek && seek.len > 0
                function fracAt(mx) { return Math.max(0, Math.min(1, mapToItem(seekTrack, mx, 0).x / seekTrack.width)) }
                onPressed: mouse => seek.dragFrac = fracAt(mouse.x)
                onPositionChanged: mouse => { if (pressed) seek.dragFrac = fracAt(mouse.x) }
                onReleased: { if (seek.dragFrac >= 0) Music.seekTo(seek.dragFrac * seek.len); seek.dragFrac = -1 }
                onCanceled: seek.dragFrac = -1
            }
        }
    }
}
