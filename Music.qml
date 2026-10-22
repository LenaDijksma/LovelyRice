pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// The media player LovelyRice controls: whatever is playing, otherwise ldmp, otherwise the first player.
Singleton {
    id: root
    readonly property var player: {
        const v = Mpris.players.values
        let ldmp = null, playing = null
        for (let i = 0; i < v.length; i++) {
            if (v[i].isPlaying && !playing) playing = v[i]
            if ((v[i].dbusName || "").indexOf("ldmp") >= 0 && !ldmp) ldmp = v[i]
        }
        return playing || ldmp || (v.length > 0 ? v[0] : null)
    }
    readonly property string title:    player ? (player.trackTitle || "") : ""
    readonly property string artist:   player ? (player.trackArtist || "") : ""
    readonly property string identity: player ? (player.identity || "") : ""
    readonly property string artUrl:   player ? (player.trackArtUrl || "") : ""

    // ---- cover art: the player's own (mpris:artUrl), else a cover/folder image next to the playing file ----
    // This is what makes ldmp show covers without ldmp having to export them.
    readonly property string trackUrl: {
        const m = player ? player.metadata : null
        return m && m["xesam:url"] ? String(m["xesam:url"]) : ""
    }
    property string folderCover: ""
    readonly property string cover: artUrl !== "" ? (artUrl.charAt(0) === "/" ? "file://" + artUrl : artUrl) : folderCover
    function encodePath(p) { return p.split("/").map(encodeURIComponent).join("/") }
    function findCover() {
        coverFinder.running = false
        if (artUrl !== "" || trackUrl.indexOf("file://") !== 0) { folderCover = ""; return }
        let path = ""
        try { path = decodeURIComponent(trackUrl.slice(7)) } catch (e) { folderCover = ""; return }
        coverFinder.command = ["sh", "-c",
            'd=$(dirname "$1"); for n in cover folder front album albumart Cover Folder Front Album AlbumArt; do for e in jpg jpeg png webp; do [ -f "$d/$n.$e" ] && { printf %s "$d/$n.$e"; exit 0; }; done; done',
            "sh", path]
        coverFinder.running = true
    }
    onTrackUrlChanged: findCover()
    onArtUrlChanged: findCover()
    Process {
        id: coverFinder
        stdout: StdioCollector { onStreamFinished: root.folderCover = text.trim() === "" ? "" : "file://" + root.encodePath(text.trim()) }
    }

    // shared with MediaPopout / Media: where the bar widget is, and whether the pointer is on it
    property bool hoverWidget: false
    property bool hoverCard: false
    property real widgetX: -1
    property real widgetY: -1
    readonly property bool playing:    player ? player.isPlaying : false
    readonly property bool volumeSupported: player ? player.volumeSupported : false
    readonly property int volumePercent: player && player.volumeSupported ? Math.round(player.volume * 100) : 0

    // ---- shuffle / repeat over MPRIS (shows up only when the player supports it) ----
    readonly property bool shuffleSupported: player ? !!player.shuffleSupported : false
    readonly property bool shuffle: shuffleSupported ? !!player.shuffle : false
    readonly property bool loopSupported: player ? !!player.loopSupported : false
    readonly property string repeat: {
        if (!loopSupported) return "none"
        if (player.loopState === MprisLoopState.Track) return "track"
        if (player.loopState === MprisLoopState.Playlist) return "playlist"
        return "none"
    }
    function toggleShuffle() { if (shuffleSupported) player.shuffle = !player.shuffle }
    // off → repeat all → repeat one → off
    function cycleRepeat() {
        if (!loopSupported) return
        const s = player.loopState
        player.loopState = s === MprisLoopState.None ? MprisLoopState.Playlist
                         : (s === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
    }

    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function next()   { if (player && player.canGoNext) player.next() }
    function prev()   { if (player && player.canGoPrevious) player.previous() }
    function seek(seconds) { if (player && player.canSeek) player.seek(seconds) }
    // absolute position in seconds
    function seekTo(seconds) { if (player && player.canSeek && player.positionSupported) player.position = seconds }
    function changeVolume(delta) {
        if (player && player.volumeSupported) player.volume = Math.max(0, Math.min(1, player.volume + delta))
    }

    // Opens ldmp in your terminal (see Terminal.qml; pick one in /settings if auto guesses wrong).
    function openLdmp() {
        Terminal.run(["sh", "-c", 'exec "$(command -v ldmp || echo "$HOME/.local/bin/ldmp")"'])
    }
}
