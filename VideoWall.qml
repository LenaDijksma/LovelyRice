import QtQuick
import QtMultimedia

// A looping, muted video wallpaper. Loaded by WallpaperLayer only for video files, because importing
// QtMultimedia fails when qt6-multimedia is not installed.
Item {
    id: vw

    property string source: ""
    property bool playing: true
    property bool ready: false      // the first frame has arrived

    onSourceChanged: ready = false
    onPlayingChanged: apply()

    function apply() {
        if (player.mediaStatus !== MediaPlayer.LoadedMedia && player.mediaStatus !== MediaPlayer.BufferedMedia) return
        if (playing) player.play(); else player.pause()
    }

    MediaPlayer {
        id: player
        source: vw.source
        loops: MediaPlayer.Infinite
        videoOutput: out            // no audioOutput on purpose: wallpapers are silent
        onMediaStatusChanged: vw.apply()
        onErrorOccurred: (error, text) => console.warn("LovelyRice: video wallpaper:", text)
    }
    VideoOutput {
        id: out
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
    Connections {
        target: out.videoSink
        function onVideoFrameChanged() { if (!vw.ready) vw.ready = true }
    }
}
