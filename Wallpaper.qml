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
            const url = "file://" + p
            n.z = ++zc
            n.pending = true
            if (n.source.toString() === url && n.status === Image.Ready) { n.reveal(); return }
            n.opacity = 0
            n.source = url
        }
        Component.onCompleted: setPath(Theme.wallpaper)
        Connections {
            target: Theme
            function onWallpaperChanged() { win.setPath(Theme.wallpaper) }
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

        WallpaperLayer { id: a; sourceSize: Qt.size(win.screen.width * win.screen.devicePixelRatio, win.screen.height * win.screen.devicePixelRatio) }
        WallpaperLayer { id: b; sourceSize: Qt.size(win.screen.width * win.screen.devicePixelRatio, win.screen.height * win.screen.devicePixelRatio) }

        ParallelAnimation {
            id: clearAnim
            NumberAnimation { target: a; property: "opacity"; to: 0; duration: Theme.dur(500) }
            NumberAnimation { target: b; property: "opacity"; to: 0; duration: Theme.dur(500) }
        }
    }
}
