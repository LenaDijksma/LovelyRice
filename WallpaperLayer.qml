import QtQuick
import Quickshell

// One wallpaper layer; Wallpaper.qml keeps two per monitor and cross-fades between them.
// The renderer follows the file type:
//   still image          png / jpg / ...         Image
//   animated image       gif / animated webp     AnimatedImage  (built into Qt, no extra packages)
//   video                mp4 / webm / mkv / mov  VideoWall.qml  (needs qt6-multimedia; muted, loops)
// Video is loaded from its own file so a missing qt6-multimedia only breaks video wallpapers, not the shell.
Item {
    id: wl

    property string path: ""
    property bool pending: false
    property size sourceSize: Qt.size(0, 0)
    property int fadeMs: 800
    property bool animate: true
    readonly property string kind: Theme.wallpaperKind(path)

    signal revealed()

    anchors.fill: parent
    opacity: 0

    readonly property bool itemReady: {
        const it = kind === "video" ? video.item : stills.item
        return it ? it.ready : false
    }
    onItemReadyChanged: if (itemReady && pending) reveal()

    function reveal() { pending = false; fade.restart() }

    // Start showing p in this layer; it fades in once the first frame is ready.
    function load(p) {
        pending = true
        if (p === path && itemReady) { reveal(); return }
        fade.stop()
        opacity = 0
        path = p
    }

    // Stop and unload (a covered video must not keep decoding behind the new wallpaper).
    function release() {
        fade.stop()
        pending = false
        opacity = 0
        path = ""
    }

    Loader {
        id: stills
        anchors.fill: parent
        active: wl.path !== "" && wl.kind !== "video"
        sourceComponent: wl.kind === "anim" ? animC : imgC
    }
    Component {
        id: imgC
        Image {
            readonly property bool ready: status === Image.Ready
            source: "file://" + wl.path
            sourceSize: wl.sourceSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }
    }
    Component {
        id: animC
        AnimatedImage {
            readonly property bool ready: status === Image.Ready
            source: "file://" + wl.path
            sourceSize: wl.sourceSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            playing: wl.animate
        }
    }

    Loader {
        id: video
        anchors.fill: parent
        active: wl.kind === "video"
        source: "VideoWall.qml"
        onStatusChanged: if (status === Loader.Error && !Theme.videoWarned) {
            Theme.videoWarned = true
            console.warn("LovelyRice: video wallpapers need qt6-multimedia (run /doctor)")
            Quickshell.execDetached(["notify-send", "-a", "LovelyRice", "Video wallpapers need qt6-multimedia",
                                     "Run /doctor to see the package to install"])
        }
    }
    Binding { target: video.item; property: "source"; value: "file://" + wl.path; when: video.item !== null }
    Binding { target: video.item; property: "playing"; value: wl.animate; when: video.item !== null }

    NumberAnimation {
        id: fade
        target: wl; property: "opacity"; from: 0; to: 1
        duration: wl.fadeMs; easing.type: Easing.OutCubic
        onFinished: wl.revealed()
    }
}
