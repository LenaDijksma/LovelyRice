import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Flying popout for volume and brightness. Slides out from under the utility bar (whichever edge it is on), then flies back.
// Volume comes from PipeWire; brightness from Brightness.qml (/sys/class/backlight, laptop panels).
PanelWindow {
    id: win

    property string kind: "volume"      // volume | brightness
    property real value: 0
    property bool muted: false
    property bool shown: false
    property bool armed: false          // ignore the initial values at startup
    property real progress: shown ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(420); easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

    function popup(k, v, m) {
        if (!armed || !Settings.osd) return
        kind = k; value = v; muted = m
        shown = true
        hideTimer.restart()
    }

    Timer { interval: 2500; running: true; onTriggered: win.armed = true }
    Timer { id: hideTimer; interval: 1700; onTriggered: win.shown = false }

    // ---- volume ----
    readonly property var sink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [win.sink] }
    Connections {
        target: win.sink && win.sink.audio ? win.sink.audio : null
        function onVolumeChanged() { win.popup("volume", win.sink.audio.volume, win.sink.audio.muted) }
        function onMutedChanged()  { win.popup("volume", win.sink.audio.volume, win.sink.audio.muted) }
    }

    // ---- brightness ----
    // Brightness.qml reads the backlight; it only reports changes made by something else (brightness keys),
    // so dragging the bar slider doesn't also fly this popout out.
    Connections {
        target: Brightness
        function onExternal(v) { win.popup("brightness", v, false) }
    }

    // ---- window: next to the bar, centered along it, on the focused monitor ----
    // Anchored to one edge only, so the compositor centers it along the bar.
    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    // which bar it comes out of: the one the status icons (volume) are on
    readonly property string at: Bar.posOf("status")
    readonly property bool alongX: Bar.isHorizontal(at)
    anchors { left: !alongX; top: alongX }
    margins.left: !alongX ? Bar.originX(win.screen ? win.screen.width : 1920, implicitWidth, 0, at) : 0
    margins.top: alongX ? Bar.originY(win.screen ? win.screen.height : 1080, implicitHeight, 0, at) : 0
    implicitWidth: Bar.winWidth(card.width, at)
    implicitHeight: Bar.winHeight(card.height, at)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: progress > 0.001
    mask: Region { item: card }
    WlrLayershell.namespace: "lovelyrice-osd"

    Card {
        id: card
        width: 66
        height: 230
        x: Bar.flyX(width, parent.width, win.progress, win.at)     // flies out from the bar edge
        y: Bar.flyY(height, parent.height, win.progress, win.at)
        opacity: Math.min(1, win.progress * 1.5)
        color: Qt.alpha(Theme.bg, 0.97)
        radius: Theme.radius
        shadowX: Bar.shadowXFor(win.at)
        shadowY: Bar.shadowYFor(win.at)

        Icon {
            id: ic
            anchors { top: parent.top; topMargin: 18; horizontalCenter: parent.horizontalCenter }
            width: 28; height: 28
            kind: win.kind === "brightness" ? "brightness" : (win.muted ? "muted" : "volume")
            level: win.value
            color: win.muted ? Theme.dim : Theme.accent
        }

        Rectangle {   // track
            id: track
            width: 12
            anchors { top: ic.bottom; topMargin: 14; bottom: pct.top; bottomMargin: 12; horizontalCenter: parent.horizontalCenter }
            radius: 6
            color: Qt.alpha(Theme.dim, 0.3)
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Math.max(width, parent.height * Math.min(1, win.muted ? 0 : win.value))
                radius: 6
                color: win.muted ? Theme.dim : (win.value > 1.0 ? Theme.warn : Theme.accent)
                Behavior on height { NumberAnimation { duration: Theme.dur(180); easing.type: Easing.OutCubic } }
                Behavior on color  { ColorAnimation { duration: Theme.dur(200) } }
            }
        }
        Text {
            id: pct
            anchors { bottom: parent.bottom; bottomMargin: 14; horizontalCenter: parent.horizontalCenter }
            text: win.muted ? "mute" : Math.round(win.value * 100)
            color: Theme.fg
            font { family: Theme.font; pixelSize: 13; bold: true }
        }
    }
}
