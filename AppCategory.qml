pragma Singleton
import QtQuick
import Quickshell

// Maps a window class to a generic kind of app. First by well-known class names,
// then by the freedesktop Categories of the app's .desktop entry.
Singleton {
    readonly property var rules: [
        ["browser",  /zen|firefox|chromium|chrome|brave|vivaldi|opera|librewolf|floorp|epiphany|falkon|qutebrowser|tor-?browser|waterfox|helium/],
        ["files",    /nautilus|thunar|dolphin|nemo|pcmanfm|caja|yazi|ranger|spacefm|krusader|\.files|^files$/],
        ["terminal", /kitty|alacritty|^foot|wezterm|konsole|gnome-terminal|xterm|ghostty|terminator|tilix|urxvt|^st-|rio|terminal|btop|htop/],
        ["game",     /steam|lutris|heroic|prismlauncher|minecraft|retroarch|gamescope|bottles|itch|godot|yuzu|ryujinx|dolphin-emu|pcsx|rpcs3|^game|\.exe$/],
        ["code",     /^code|vscodium|vscode|nvim|neovim|vim|jetbrains|idea|pycharm|clion|rider|webstorm|goland|zed|sublime|kate|emacs|helix|android-studio|cursor/],
        ["chat",     /discord|vesktop|legcord|armcord|telegram|signal|element|slack|teams|whatsapp|zulip|fractal|revolt|fluffychat|nheko/],
        ["mail",     /thunderbird|evolution|geary|mailspring|kmail|betterbird|proton-?mail/],
        ["music",    /spotify|rhythmbox|amberol|strawberry|cider|deadbeef|lollypop|ldmp|music|tidal|youtube-music|ncspot|elisa|audacious/],
        ["video",    /^mpv|vlc|celluloid|totem|obs|haruna|jellyfin|kdenlive|davinci|youtube|plex|smplayer|showtime|clapper/],
        ["image",    /gimp|inkscape|krita|blender|figma|aseprite|^imv|loupe|^eog|gwenview|^feh|darktable|rawtherapee|pinta|photopea|swayimg|upscayl/],
        ["docs",     /libreoffice|onlyoffice|evince|okular|zathura|obsidian|logseq|notion|writer|calibre|sioyek|xournal|papers|foliate|joplin|anytype|typora|zotero|^lmf/],
        ["system",   /pavucontrol|nm-connection|blueman|settings|control-center|mission-center|gnome-system|polkit|network|bluetooth|pwvucontrol|helvum|qpwgraph|nwg|systemsettings|lxappearance|kvantum|qt[56]ct/]
    ]

    // freedesktop Categories → kind (checked in this order)
    readonly property var catRules: [
        ["browser",  ["WebBrowser"]],
        ["files",    ["FileManager"]],
        ["terminal", ["TerminalEmulator"]],
        ["game",     ["Game"]],
        ["code",     ["IDE", "TextEditor", "Development"]],
        ["chat",     ["InstantMessaging", "Chat", "IRCClient", "VideoConference"]],
        ["mail",     ["Email"]],
        ["music",    ["Music", "Audio", "Player"]],
        ["video",    ["Video", "AudioVideo", "Recorder"]],
        ["image",    ["Graphics", "Photography", "2DGraphics", "3DGraphics", "RasterGraphics", "VectorGraphics"]],
        ["docs",     ["Office", "Viewer", "Publishing", "Education", "WordProcessor", "Spreadsheet", "Presentation"]],
        ["system",   ["Settings", "System", "Monitor", "HardwareSettings", "PackageManager"]]
    ]

    property var cache: ({})

    function kindFor(cls) {
        if (!cls) return "window"
        if (cache[cls] !== undefined) return cache[cls]
        const lc = cls.toLowerCase()
        let kind = ""
        for (let i = 0; i < rules.length; i++) {
            if (rules[i][1].test(lc)) { kind = rules[i][0]; break }
        }
        if (kind === "") {
            const e = DesktopEntries.heuristicLookup(cls)
            if (e && e.categories) {
                const have = {}
                for (let i = 0; i < e.categories.length; i++) have[e.categories[i]] = true
                outer:
                for (let i = 0; i < catRules.length; i++)
                    for (const k of catRules[i][1])
                        if (have[k]) { kind = catRules[i][0]; break outer }
            }
        }
        if (kind === "") kind = "window"
        cache[cls] = kind
        return kind
    }
}
