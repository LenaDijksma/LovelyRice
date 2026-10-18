pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "ColorUtil.js" as CU

// Builds a colour scheme from the current wallpaper and applies it as the user theme "wallpaper".
//  - /match-wallpaper (palette) or /settings → "Match colors to current wallpaper" does it once.
//  - /settings → "Colors follow the wallpaper" redoes it whenever the wallpaper changes.
// The image is shrunk to 40x40 with ImageMagick (`magick` or `convert`); no other dependency.
// The result is a normal scheme in ~/.config/lovelyrice/themes/wallpaper.json, so you can tweak it in /scheme-maker.
Singleton {
    id: root

    property bool busy: false
    readonly property string userDir: Quickshell.env("HOME") + "/.config/lovelyrice/themes"

    function start() {}   // referenced from shell.qml so the auto-follow below is always active
    function note(title, body) { Quickshell.execDetached(["notify-send", "-a", "LovelyRice", title, body]) }

    function apply() {
        if (busy) return
        const p = Theme.wallpaper
        if (p === "") { note("No wallpaper yet", "Pick one with /wallpaper first"); return }
        busy = true
        reader.command = ["sh", "-c",
            'm=$(command -v magick || command -v convert) || exit 1; "$m" "$1[0]" -resize 40x40 -colorspace sRGB -depth 8 txt:-',
            "sh", p]
        reader.running = true
    }

    function finish(out) {
        const px = []
        for (const line of out.split("\n")) {
            const m = line.match(/#([0-9A-Fa-f]{6})/)
            if (m) px.push("#" + m[1])
        }
        if (px.length < 50) {
            busy = false
            note("Couldn't read the wallpaper", "Colors from the wallpaper need ImageMagick (magick or convert)")
            return
        }
        const obj = { name: "wallpaper", colors: CU.fromPixels(px, false), font: Theme.font,
                      opacity: Math.round(Theme.opacity * 100) / 100, shadow: Math.round(Theme.shadowOpacity * 100) / 100 }
        if (Theme.themeWallpaper !== "") obj.wallpaper = Theme.themeWallpaper
        saver.command = ["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$1/wallpaper.json"', "sh", userDir, JSON.stringify(obj, null, 2)]
        saver.running = true
    }

    Process {
        id: reader
        stdout: StdioCollector { onStreamFinished: root.finish(text) }
    }
    Process {
        id: saver
        onExited: code => {
            root.busy = false
            if (code !== 0) { root.note("Couldn't save the scheme", "Is ~/.config/lovelyrice writable?"); return }
            Theme.registerUser("wallpaper", root.userDir + "/wallpaper.json")
            Theme.select("wallpaper")
            Theme.save()
            Theme.rescan()
        }
    }

    Timer { id: follow; interval: 700; onTriggered: root.apply() }
    Connections {
        target: Theme
        function onWallpaperChanged() { if (Settings.wallpaperTheme && !root.busy) follow.restart() }
    }
}
