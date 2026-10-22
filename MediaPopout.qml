import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Mpris

// Media popout: cover art, title, artist, transport buttons and a seek bar, flying out of the utility bar like the
// volume popout. It appears for a few seconds when the track changes, and while you hover the bar media
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

    Timer { interval: 2500; running: true; onTriggered: win.armed = true }
    Timer { id: autoTimer; interval: 4500; onTriggered: win.autoShown = false }
    Timer { id: hoverTimer; interval: win.hovering ? 300 : 400; onTriggered: win.hoverShown = win.hovering }
    onHoveringChanged: hoverTimer.restart()

    Connections {
        target: Music
        function onTitleChanged() { if (win.armed && Music.title !== "") win.peek() }
    }
    onVisibleChanged: if (!visible) Music.hoverCard = false

    onWantedChanged: if (wanted && player && player.positionSupported) player.positionChanged()

    // ---- window: next to the bar, level with the bar media widget, on the focused monitor ----
    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    anchors { left: true; top: true }
    readonly property real screenW: win.screen ? win.screen.width : 1920
    readonly property real screenH: win.screen ? win.screen.height : 1080
    // where the bar widget is along the bar (x on a top/bottom bar, y on a left/right bar); the middle of the screen until it has been hovered
    readonly property string at: Bar.posOf("media")      // the bar the media widget is on
    readonly property real mid: {
        const v = Bar.isHorizontal(at) ? Music.widgetX : Music.widgetY
        return v >= 0 ? v : (Bar.isHorizontal(at) ? screenW : screenH) / 2
    }
    margins.left: Bar.originX(screenW, implicitWidth, mid - implicitWidth / 2, at)
    margins.top: Bar.originY(screenH, implicitHeight, mid - implicitHeight / 2, at)
    implicitWidth: Bar.winWidth(card.width, at)
    implicitHeight: Bar.winHeight(card.height, at)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: progress > 0.001
    mask: Region { item: card }
    WlrLayershell.namespace: "lovelyrice-media"

    Card {
        id: card
        width: 340
        height: 136
        x: Bar.flyX(width, parent.width, win.progress, win.at)
        y: Bar.flyY(height, parent.height, win.progress, win.at)
        opacity: Math.min(1, win.progress * 1.5)
        color: Qt.alpha(Theme.bg, 0.97)
        radius: Theme.radius
        shadowX: Bar.shadowXFor(win.at)
        shadowY: Bar.shadowYFor(win.at)

        HoverHandler { onHoveredChanged: Music.hoverCard = hovered }

        MediaCard { id: body; anchors.fill: parent }
    }
}
