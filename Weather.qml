pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Weather for the dashboard, from wttr.in. OPT-IN: it stays off until you enable it in /settings, because the request
// goes to a third-party service (which sees your IP address, and the location text if you set one).
// Location: automatic (by IP) unless ~/.config/lovelyrice/config.json has  { "weather": { "location": "Hengelo" } }.
// Units: /settings → metric or imperial. Refreshed when the dashboard opens (at most every 15 min).
Singleton {
    id: root
    property string status: "off"        // off | loading | ok | error
    property string place: ""
    property string temp: ""
    property string feels: ""
    property string desc: ""
    property string glyph: ""
    property string humidity: ""
    property string wind: ""
    property var days: []                // [{ day, hi, lo, glyph }]
    property string location: ""
    property double fetched: 0
    readonly property bool imperial: Settings.weatherUnits === "imperial"

    function glyphFor(code) {
        const c = parseInt(code)
        if (c === 113) return "☀"
        if (c === 116) return "◐"
        if (c === 119 || c === 122) return "☁"
        if (c === 143 || c === 248 || c === 260) return "≋"
        if (c === 200 || c === 386 || c === 389) return "ϟ"
        if ([179, 182, 185, 227, 230, 281, 284, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377, 392, 395].indexOf(c) >= 0) return "❄"
        return "☂"
    }
    function ensure() {
        if (!Settings.weather) { status = "off"; return }
        if (fetch.running) return
        if (Date.now() - fetched < 15 * 60 * 1000 && status === "ok") return
        status = "loading"
        fetch.command = ["sh", "-c", 'curl -sf --max-time 12 "https://wttr.in/$1?format=j1"', "sh", encodeURIComponent(location)]
        fetch.running = true
    }

    function parse(txt) {
        try {
            const j = JSON.parse(txt)
            const c = j.current_condition[0]
            const f = imperial
            temp = (f ? c.temp_F : c.temp_C) + "°"
            feels = (f ? c.FeelsLikeF : c.FeelsLikeC) + "°"
            desc = c.weatherDesc && c.weatherDesc[0] ? c.weatherDesc[0].value : ""
            glyph = glyphFor(c.weatherCode)
            humidity = c.humidity + "%"
            wind = f ? c.windspeedMiles + " mph" : c.windspeedKmph + " km/h"
            place = j.nearest_area && j.nearest_area[0] && j.nearest_area[0].areaName[0] ? j.nearest_area[0].areaName[0].value : ""
            days = j.weather.slice(0, 3).map(d => {
                const dt = new Date(d.date + "T12:00:00")
                const noon = d.hourly && d.hourly[4] ? d.hourly[4].weatherCode : c.weatherCode
                return { day: Qt.formatDate(dt, "ddd"), hi: (f ? d.maxtempF : d.maxtempC) + "°", lo: (f ? d.mintempF : d.mintempC) + "°", glyph: glyphFor(noon) }
            })
            fetched = Date.now()
            status = "ok"
        } catch (e) {
            console.warn("LovelyRice: weather parse failed:", e)
            status = "error"
        }
    }

    Process {
        id: fetch
        stdout: StdioCollector { onStreamFinished: { if (text.trim() === "") root.status = "error"; else root.parse(text) } }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/lovelyrice/config.json"
        printErrors: false
        onLoaded: {
            try { const c = JSON.parse(text()); root.location = (c.weather && c.weather.location) ? String(c.weather.location) : "" }
            catch (e) {}
        }
    }
    Connections {
        target: Settings
        function onWeatherUnitsChanged() { root.fetched = 0; if (root.status === "ok") root.ensure() }
        function onWeatherChanged() { if (!Settings.weather) root.status = "off" }
    }
    Timer { interval: 30 * 60 * 1000; repeat: true; running: Settings.weather && root.status === "ok"; onTriggered: root.ensure() }
}
