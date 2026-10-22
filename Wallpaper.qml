import QtQuick
import Quickshell
import Quickshell.Wayland

// Draws the desktop background on every monitor, cross-fading between wallpapers.
// With no wallpaper set it paints a theme-colored gradient, so each theme still looks complete.
// If another wallpaper program (hyprpaper, swww, Caelestia's shell...) is running, stop it.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData
        property int zc: 1
        property bool useA: true

        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "black"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "lovelyrice-wallpaper"

        function setPath(p) {
            if (p === "") { clearAnim.restart(); return }
            clearAnim.stop()
            const n = useA ? a : b
            useA = !useA
            n.fadeMs = Theme.previewActive ? Theme.dur(220) : Theme.dur(800)   // previews switch quickly
            n.z = ++zc
            n.load(p)
        }
        // the layer that is fully covered stops (a video would keep decoding behind the new wallpaper)
        function settle(top, under) { if (under.z < top.z) under.release() }
        Component.onCompleted: setPath(Theme.shownWallpaper)
        Connections {
            target: Theme
            function onShownWallpaperChanged() { win.setPath(Theme.shownWallpaper) }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.bg }
                GradientStop { position: 1.0; color: Theme.surface }
            }
            Rectangle {   // soft accent glow
                width: parent.width * 0.7; height: width; radius: width / 2
                x: parent.width * 0.55; y: -height * 0.35
                color: Qt.alpha(Theme.accent, 0.10)
            }
            Rectangle {
                width: parent.width * 0.6; height: width; radius: width / 2
                x: -width * 0.3; y: parent.height * 0.6
                color: Qt.alpha(Theme.accent2, 0.08)
            }
        }

        WallpaperLayer {
            id: a
            animate: Settings.wallpaperAnimate
            sourceSize: Qt.size(win.screen.width * win.screen.devicePixelRatio, win.screen.height * win.screen.devicePixelRatio)
            onRevealed: win.settle(a, b)
        }
        WallpaperLayer {
            id: b
            animate: Settings.wallpaperAnimate
            sourceSize: Qt.size(win.screen.width * win.screen.devicePixelRatio, win.screen.height * win.screen.devicePixelRatio)
            onRevealed: win.settle(b, a)
        }

        ParallelAnimation {
            id: clearAnim
            NumberAnimation { target: a; property: "opacity"; to: 0; duration: Theme.dur(500) }
            NumberAnimation { target: b; property: "opacity"; to: 0; duration: Theme.dur(500) }
            onFinished: { a.release(); b.release() }
        }
    }
}
