import QtQuick

// What is behind a bar window: the wallpaper, cropped to the screen the way Wallpaper.qml crops it. One per bar window (only
// loaded while a glass style is in use). Glass surfaces sample `texture`; `wallItem` is the item behind it, for the fallback.
// Tiled windows never sit under the bar (it reserves its space), so the wallpaper is what the glass really sees. A floating
// window dragged over the bar is not reflected, and neither is a video wallpaper (it uses the theme-colored background).
Item {
    id: root
    property real sw: 1920          // the screen, in logical pixels
    property real sh: 1080
    property real winX: 0           // where the bar window's top-left corner is on the screen
    property real winY: 0
    readonly property alias wallItem: wall
    width: 0; height: 0

    readonly property string path: Theme.shownWallpaper
    readonly property bool still: path !== "" && Theme.wallpaperKind(path) !== "video"     // gif / webp show their first frame

    Item {
        id: wall
        width: root.sw; height: root.sh
        Rectangle {                                    // same generated background as Wallpaper.qml, for themes without a wallpaper
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.bg }
                GradientStop { position: 1.0; color: Theme.surface }
            }
            Rectangle {
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
        Image {
            anchors.fill: parent
            source: root.still ? "file://" + root.path : ""
            sourceSize: Qt.size(Math.round(root.sw / 2), Math.round(root.sh / 2))    // half size is plenty for something that gets blurred
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
        }
    }

    // The wallpaper as a texture: half size with mipmaps, so a high mip level is a cheap, large blur.
    // An unparented source (the usual way to hand one to a ShaderEffect): it never draws by itself, and it hides `wall`.
    property Item texture: ShaderEffectSource {
        sourceItem: wall
        hideSource: true
        live: true
        mipmap: true
        smooth: true
        textureSize: Qt.size(Math.max(1, Math.round(root.sw / 2)), Math.max(1, Math.round(root.sh / 2)))
    }
}
