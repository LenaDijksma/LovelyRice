import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Dashboard: weather, CPU / memory / network graphs and a mini calendar. It flies out of the utility bar while you
// hover the clock (click the clock for the full calendar). `qs -c lovelyrice ipc call rice dashboard` shows it for a few seconds.
// Weather is opt-in (/settings), see Weather.qml.
PanelWindow {
    id: win

    property bool peeked: false
    property bool hoverShown: false
    readonly property bool hovering: Stats.hoverWidget || Stats.hoverCard
    readonly property bool wanted: Settings.dashboard && !Popups.anyOpen && (peeked || hoverShown)
    property real progress: wanted ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(420); easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

    function peek() { peeked = true; peekTimer.restart() }
    Timer { id: peekTimer; interval: 6000; onTriggered: win.peeked = false }
    Timer { id: hoverTimer; interval: win.hovering ? 350 : 450; onTriggered: win.hoverShown = win.hovering }
    onHoveringChanged: hoverTimer.restart()
    onVisibleChanged: if (!visible) Stats.hoverCard = false
    onWantedChanged: if (wanted) body.refresh()


    // ---- window ----
    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    anchors { left: true; top: true }
    readonly property real screenW: win.screen ? win.screen.width : 1920
    readonly property real screenH: win.screen ? win.screen.height : 1080
    // The clock sits at the far end of the bar (the bottom of a left/right bar, the right end of a top/bottom bar),
    // so the card lines its far edge up with the clock and grows back toward the start of the bar.
    readonly property string at: Bar.posOf("clock")      // the bar the clock is on
    readonly property real farEdge: {
        const v = Bar.isHorizontal(at) ? Stats.widgetX : Stats.widgetY
        return v >= 0 ? v + 40 : (Bar.isHorizontal(at) ? screenW : screenH) - 40
    }
    margins.left: Bar.originX(screenW, implicitWidth, farEdge - implicitWidth, at)
    margins.top: Bar.originY(screenH, implicitHeight, farEdge - implicitHeight, at)
    implicitWidth: Bar.winWidth(card.width, at)
    implicitHeight: Bar.winHeight(card.height, at)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: progress > 0.001
    mask: Region { item: card }
    WlrLayershell.namespace: "lovelyrice-dashboard"

    Card {
        id: card
        width: 340
        height: body.implicitHeight
        x: Bar.flyX(width, parent.width, win.progress, win.at)
        y: Bar.flyY(height, parent.height, win.progress, win.at)
        opacity: Math.min(1, win.progress * 1.5)
        color: Qt.alpha(Theme.bg, 0.97)
        radius: Theme.radius
        shadowX: Bar.shadowXFor(win.at)
        shadowY: Bar.shadowYFor(win.at)
        HoverHandler { onHoveredChanged: Stats.hoverCard = hovered }

        DashboardCard { id: body; anchors.fill: parent }
    }
}
