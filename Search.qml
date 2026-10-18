pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Web search for the palette (`?text`). The engine is chosen in /settings → Palette.
// Shortcuts: `?w hyprland` searches Wikipedia, `?aw hyprland` the Arch wiki, and so on (list below).
// ~/.config/lovelyrice/config.json can add your own:
//   "search": {
//     "url":   "https://example.org/search?q=%s",              // the "custom" engine (%s = the text; appended if missing)
//     "bangs": { "docs": "https://docs.example.org/?q=%s" }    // your own shortcuts: ?docs text
//   }
Singleton {
    id: root

    readonly property var engines: ({
        duckduckgo: { label: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
        google:     { label: "Google",     url: "https://www.google.com/search?q=" },
        brave:      { label: "Brave",      url: "https://search.brave.com/search?q=" },
        startpage:  { label: "Startpage",  url: "https://www.startpage.com/do/search?q=" },
        ecosia:     { label: "Ecosia",     url: "https://www.ecosia.org/search?q=" },
        kagi:       { label: "Kagi",       url: "https://kagi.com/search?q=" },
        bing:       { label: "Bing",       url: "https://www.bing.com/search?q=" }
    })
    readonly property var builtinBangs: ({
        g:    { label: "Google",         url: "https://www.google.com/search?q=" },
        ddg:  { label: "DuckDuckGo",     url: "https://duckduckgo.com/?q=" },
        w:    { label: "Wikipedia",      url: "https://en.wikipedia.org/w/index.php?search=" },
        aw:   { label: "the Arch wiki",  url: "https://wiki.archlinux.org/index.php?search=" },
        aur:  { label: "the AUR",        url: "https://aur.archlinux.org/packages?K=" },
        pac:  { label: "Arch packages",  url: "https://archlinux.org/packages/?q=" },
        gh:   { label: "GitHub",         url: "https://github.com/search?q=" },
        yt:   { label: "YouTube",        url: "https://www.youtube.com/results?search_query=" },
        map:  { label: "OpenStreetMap",  url: "https://www.openstreetmap.org/search?query=" }
    })

    property string customUrl: ""
    property var customBangs: ({})

    // what /settings offers ("custom" only when config.json defines a url)
    readonly property var names: Object.keys(engines).concat(customUrl !== "" ? ["custom"] : [])

    readonly property var current: {
        const e = Settings.searchEngine
        if (e === "custom" && customUrl !== "") return { label: "your search engine", url: customUrl }
        return engines[e] || engines.duckduckgo
    }

    function safe(u) {
        if (typeof u !== "string") return false
        const l = u.toLowerCase()
        return l.indexOf("http://") === 0 || l.indexOf("https://") === 0
    }
    function build(url, text) {
        const q = encodeURIComponent(text)
        return url.indexOf("%s") >= 0 ? url.split("%s").join(q) : url + q
    }

    // text after the `?` → { url, label, text } or null when there is nothing to search for
    function resolve(input) {
        const t = String(input).trim()
        if (t === "") return null
        const m = t.match(/^(\S+)\s+(.+)$/)
        if (m) {
            const key = m[1].toLowerCase()
            const b = (customBangs[key] !== undefined) ? { label: key, url: customBangs[key] } : builtinBangs[key]
            if (b) return { url: build(b.url, m[2]), label: b.label, text: m[2] }
        }
        return { url: build(current.url, t), label: current.label, text: t }
    }

    function load(text) {
        let c = {}
        try { c = JSON.parse(text) } catch (e) { return }
        const s = c.search || {}
        customUrl = safe(s.url) ? s.url : ""
        const b = {}
        if (s.bangs && typeof s.bangs === "object")
            for (const k in s.bangs) if (safe(s.bangs[k])) b[k.toLowerCase()] = s.bangs[k]
        customBangs = b
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/lovelyrice/config.json"
        printErrors: false
        onLoaded: root.load(text())
    }
}
