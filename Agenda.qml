pragma Singleton
import QtQuick
import QtQml
import Quickshell
import Quickshell.Io

// Calendar data. Reads iCal feeds listed in ~/.config/lovelyrice/config.json:
//   { "calendars": [ { "name": "Personal", "url": "https://calendar.google.com/.../basic.ics", "color": "#7aa2f7" } ] }
// A Google Calendar "Secret address in iCal format" works directly (read-only, no login needed).
// Local .ics file paths work too. Recurring events (RRULE) are expanded.
Singleton {
    id: root

    property var sources: []          // [{ name, url, color }]
    property var parsed: ({})         // source index -> [event]
    property int rev: 0               // bumps whenever data changes
    property string status: "none"    // none | loading | ok | error
    property var lastSync: null

    readonly property string configPath: Quickshell.env("HOME") + "/.config/lovelyrice/config.json"
    readonly property var palette: [Theme.accent, Theme.accent2, Theme.warn, Theme.fg]

    function applyConfig(txt) {
        try {
            const c = JSON.parse(txt)
            const out = []
            for (const e of (c.calendars || [])) {
                if (typeof e === "string") out.push({ name: "", url: e, color: "" })
                else if (e && e.url) out.push({ name: e.name || "", url: e.url, color: e.color || "" })
            }
            parsed = ({})
            sources = out
            status = out.length > 0 ? "loading" : "none"
            rev++
        } catch (err) {
            console.warn("LovelyRice: bad config.json:", err)
            sources = []
            status = "error"
        }
    }

    function colorFor(i) {
        const s = sources[i]
        return s && s.color ? s.color : palette[i % palette.length]
    }

    function refresh() {
        if (sources.length === 0) return
        status = "loading"
        for (let i = 0; i < fetchers.count; i++) {
            const p = fetchers.objectAt(i)
            if (p) p.running = true
        }
    }

    function setRaw(i, txt) {
        const p = Object.assign({}, parsed)
        p[i] = parseICS(txt)
        parsed = p
        status = "ok"
        lastSync = new Date()
        rev++
    }

    FileView {
        path: root.configPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.applyConfig(text())
        onLoadFailed: { root.sources = []; root.status = "none" }
    }

    Instantiator {
        id: fetchers
        model: root.sources
        delegate: Process {
            id: proc
            required property var modelData
            required property int index
            running: true
            command: ["sh", "-c",
                'case "$1" in http*) curl -fsSL --max-time 25 "$1" ;; *) cat "$1" ;; esac',
                "sh", modelData.url]
            stdout: StdioCollector { onStreamFinished: root.setRaw(proc.index, text) }
            onExited: code => { if (code !== 0) root.status = "error" }
        }
    }
    Timer { interval: 15 * 60 * 1000; repeat: true; running: root.sources.length > 0; onTriggered: root.refresh() }

    // ---------------- iCal parsing ----------------
    function parseDate(v) {
        const m = v.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/)
        if (!m) return null
        if (m[4] === undefined) return new Date(+m[1], +m[2] - 1, +m[3])
        if (m[7]) return new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] || 0)))
        return new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] || 0))
    }
    function unescapeText(s) {
        return s.replace(/\\n/gi, " ").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\")
    }
    function parseRRule(v) {
        const r = { byday: [], bymonthday: [] }
        for (const part of v.split(";")) {
            const eq = part.indexOf("=")
            if (eq < 0) continue
            const k = part.slice(0, eq).toUpperCase(), val = part.slice(eq + 1)
            if (k === "FREQ") r.freq = val.toUpperCase()
            else if (k === "INTERVAL") r.interval = parseInt(val)
            else if (k === "COUNT") r.count = parseInt(val)
            else if (k === "UNTIL") {
                const d = parseDate(val)
                if (d) { if (val.indexOf("T") < 0) d.setHours(23, 59, 59); r.until = d }
            } else if (k === "BYDAY") {
                for (const b of val.split(",")) {
                    const m = b.match(/^([+-]?\d+)?(MO|TU|WE|TH|FR|SA|SU)$/)
                    if (m) r.byday.push({ n: m[1] ? parseInt(m[1]) : 0, day: ["SU","MO","TU","WE","TH","FR","SA"].indexOf(m[2]) })
                }
            } else if (k === "BYMONTHDAY") {
                for (const d of val.split(",")) r.bymonthday.push(parseInt(d))
            }
        }
        return r
    }
    function parseICS(txt) {
        const lines = txt.replace(/\r?\n[ \t]/g, "").split(/\r?\n/)
        const evs = []
        let cur = null
        for (const line of lines) {
            if (line === "BEGIN:VEVENT") { cur = { exdates: [] }; continue }
            if (line === "END:VEVENT") { if (cur && cur.start) evs.push(cur); cur = null; continue }
            if (!cur) continue
            const c = line.indexOf(":")
            if (c < 0) continue
            const left = line.slice(0, c), val = line.slice(c + 1)
            const semi = left.indexOf(";")
            const name = (semi < 0 ? left : left.slice(0, semi)).toUpperCase()
            const params = semi < 0 ? "" : left.slice(semi + 1).toUpperCase()
            if (name === "DTSTART") { cur.allDay = params.indexOf("VALUE=DATE") >= 0 && params.indexOf("DATE-TIME") < 0; cur.start = parseDate(val) }
            else if (name === "DTEND") cur.end = parseDate(val)
            else if (name === "SUMMARY") cur.title = unescapeText(val)
            else if (name === "LOCATION") cur.location = unescapeText(val)
            else if (name === "UID") cur.uid = val
            else if (name === "RRULE") cur.rrule = parseRRule(val)
            else if (name === "EXDATE") { for (const v of val.split(",")) { const d = parseDate(v); if (d) cur.exdates.push(d.getTime()) } }
            else if (name === "RECURRENCE-ID") cur.recId = parseDate(val)
            else if (name === "STATUS") cur.cancelled = val.toUpperCase() === "CANCELLED"
        }
        return evs
    }

    // ---------------- recurrence expansion ----------------
    function nthWeekday(y, m, wd, n) {
        if (n > 0) {
            const first = new Date(y, m, 1)
            return new Date(y, m, 1 + ((wd - first.getDay() + 7) % 7) + (n - 1) * 7)
        }
        const last = new Date(y, m + 1, 0)
        return new Date(y, m, last.getDate() - ((last.getDay() - wd + 7) % 7) + (n + 1) * 7)
    }

    function occurrences(ev, from, to, source) {
        const out = []
        let durMs = ev.end && ev.start ? ev.end - ev.start : 0
        let durDays = 1
        if (ev.allDay) {
            durDays = ev.end ? Math.max(1, Math.round(durMs / 86400000)) : 1
        }
        const push = s => {
            if (ev.exdates.indexOf(s.getTime()) >= 0) return
            if (ev.skip && ev.skip[s.getTime()]) return
            const e = ev.allDay ? new Date(s.getFullYear(), s.getMonth(), s.getDate() + durDays)
                                : new Date(s.getTime() + durMs)
            if (e > from && s < to)
                out.push({ title: ev.title || "(no title)", start: s, end: e, allDay: !!ev.allDay,
                           location: ev.location || "", source: source })
        }
        if (!ev.rrule || !ev.rrule.freq) { push(ev.start); return out }

        const r = ev.rrule
        const interval = r.interval || 1
        const sd = ev.start
        const mk = (y, m, d) => ev.allDay ? new Date(y, m, d)
                                          : new Date(y, m, d, sd.getHours(), sd.getMinutes(), sd.getSeconds())
        let count = 0
        const emit = s => {                       // false = stop
            if (s < sd) return true
            if (r.until && s > r.until) return false
            if (r.count && count >= r.count) return false
            count++
            push(s)
            return true
        }
        const Y = sd.getFullYear(), M = sd.getMonth(), D = sd.getDate()

        for (let k = 0; k < 3000; k++) {
            let batch = []
            if (r.freq === "DAILY") {
                batch = [mk(Y, M, D + k * interval)]
            } else if (r.freq === "WEEKLY") {
                const days = r.byday.length ? r.byday.map(b => b.day) : [sd.getDay()]
                days.sort((a, b) => ((a + 6) % 7) - ((b + 6) % 7))
                const monday = D - ((sd.getDay() + 6) % 7)
                for (const wd of days) batch.push(mk(Y, M, monday + k * interval * 7 + ((wd + 6) % 7)))
            } else if (r.freq === "MONTHLY") {
                const mo = M + k * interval
                const norm = new Date(Y, mo, 1)
                if (r.byday.length) {
                    for (const b of r.byday) {
                        if (b.n) {
                            const d = nthWeekday(norm.getFullYear(), norm.getMonth(), b.day, b.n)
                            if (d.getMonth() === norm.getMonth()) batch.push(mk(d.getFullYear(), d.getMonth(), d.getDate()))
                        } else {
                            for (let d = 1; d <= 31; d++) {
                                const x = new Date(norm.getFullYear(), norm.getMonth(), d)
                                if (x.getMonth() === norm.getMonth() && x.getDay() === b.day) batch.push(mk(x.getFullYear(), x.getMonth(), d))
                            }
                        }
                    }
                } else {
                    for (const md of (r.bymonthday.length ? r.bymonthday : [D])) {
                        const x = new Date(norm.getFullYear(), norm.getMonth(), md)
                        if (x.getMonth() === norm.getMonth()) batch.push(mk(x.getFullYear(), x.getMonth(), md))
                    }
                }
                batch.sort((a, b) => a - b)
            } else if (r.freq === "YEARLY") {
                const x = new Date(Y + k * interval, M, D)
                if (x.getMonth() === M) batch = [mk(Y + k * interval, M, D)]
            } else { push(ev.start); return out }

            if (batch.length && batch[0] >= to) break
            let stop = false
            for (const s of batch) {
                if (s >= to) { stop = true; break }
                if (!emit(s)) { stop = true; break }
            }
            if (stop) break
        }
        return out
    }

    function eventsInRange(from, to) {
        const all = []
        for (let i = 0; i < sources.length; i++) {
            const evs = parsed[i]
            if (!evs) continue
            const skip = {}
            for (const e of evs) if (e.recId && e.uid) { (skip[e.uid] = skip[e.uid] || {})[e.recId.getTime()] = true }
            for (const e of evs) {
                if (e.cancelled) continue
                if (e.uid && skip[e.uid] && !e.recId) e.skip = skip[e.uid]
                for (const o of occurrences(e, from, to, i)) all.push(o)
            }
        }
        all.sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start))
        return all
    }
}
