import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Flying popout for volume and brightness. Slides out from under the sidebar, then flies back.
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
    // so dragging the sidebar slider doesn't also fly this popout out.
    Connections {
        target: Brightness
        function onExternal(v) { win.popup("brightness", v, false) }
    }

    // ---- window: right of the sidebar, vertically centered, on the focused monitor ----
    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    anchors { left: true }
    margins.left: Settings.side === "left"
        ? Theme.gap * 2 + Theme.barWidth
        : Math.max(0, (win.screen ? win.screen.width : 1920) - (Theme.gap * 2 + Theme.barWidth) - implicitWidth)
    implicitWidth: card.width + 24 + Theme.shadowPad
    implicitHeight: card.height + Theme.shadowPad * 2
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: progress > 0.001
    mask: Region { item: card }
    WlrLayershell.namespace: "lovelyrice-osd"

    Card {
        id: card
        width: 66
        height: 230
        anchors.verticalCenter: parent.verticalCenter
        x: Settings.side === "left" ? -width + (width + 14) * win.progress   // flies out from the sidebar edge
                                     : parent.width - (width + 14) * win.progress
        opacity: Math.min(1, win.progress * 1.5)
        color: Qt.alpha(Theme.bg, 0.97)
        radius: Theme.radius
        shadowX: Settings.side === "left" ? 4 : -4
        shadowY: 6

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
