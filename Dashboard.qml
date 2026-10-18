import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Dashboard: weather, CPU / memory / network graphs and a mini calendar. It flies out of the sidebar while you
// hover the clock (click the clock for the full calendar). `qs -c lovelyrice ipc call rice dashboard` shows it for a few seconds.
// Weather is opt-in (/settings), see Weather.qml.
PanelWindow {
    id: win

    property bool peeked: false
    property bool hoverShown: false
    readonly property bool hovering: Stats.hoverWidget || Stats.hoverCard
    readonly property bool wanted: Settings.dashboard && !Popups.anyOpen && (peeked || hoverShown)
    property real progress: wanted ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(420); easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

    function peek() { peeked = true; peekTimer.restart() }
    Timer { id: peekTimer; interval: 6000; onTriggered: win.peeked = false }
    Timer { id: hoverTimer; interval: win.hovering ? 350 : 450; onTriggered: win.hoverShown = win.hovering }
    onHoveringChanged: hoverTimer.restart()
    onVisibleChanged: if (!visible) Stats.hoverCard = false
    onWantedChanged: if (wanted) { Weather.ensure(); win.rebuild() }

    // ---- mini calendar ----
    property var dayMap: ({})
    property var todayEvents: []
    function dayKey(d) { return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate() }
    function dateAt(i) {
        const now = new Date()
        const first = new Date(now.getFullYear(), now.getMonth(), 1)
        const off = (first.getDay() + 6) % 7
        return new Date(now.getFullYear(), now.getMonth(), 1 - off + i)
    }
    function rebuild() {
        const map = {}, today = []
        const tk = dayKey(new Date())
        for (const e of Agenda.eventsInRange(dateAt(0), dateAt(42))) {
            const k = dayKey(e.start)
            map[k] = true
            if (k === tk && today.length < 3) today.push(e)
        }
        dayMap = map
        todayEvents = today
    }
    Connections { target: Agenda; function onRevChanged() { if (win.visible) win.rebuild() } }

    // ---- window ----
    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    anchors { left: true; top: true }
    margins.left: Settings.side === "left"
        ? Theme.gap * 2 + Theme.barWidth
        : Math.max(0, (win.screen ? win.screen.width : 1920) - (Theme.gap * 2 + Theme.barWidth) - implicitWidth)
    margins.top: {
        const h = win.screen ? win.screen.height : 1080
        const bottom = Stats.widgetY >= 0 ? Stats.widgetY + 40 : h - 40
        return Math.max(0, Math.min(h - implicitHeight, bottom - implicitHeight))
    }
    implicitWidth: card.width + 24 + Theme.shadowPad
    implicitHeight: card.height + Theme.shadowPad * 2
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: progress > 0.001
    mask: Region { item: card }
    WlrLayershell.namespace: "lovelyrice-dashboard"

    Card {
        id: card
        width: 340
        height: col.implicitHeight + 32
        anchors.verticalCenter: parent.verticalCenter
        x: Settings.side === "left" ? -width + (width + 14) * win.progress
                                    : parent.width - (width + 14) * win.progress
        opacity: Math.min(1, win.progress * 1.5)
        color: Qt.alpha(Theme.bg, 0.97)
        radius: Theme.radius
        shadowX: Settings.side === "left" ? 4 : -4
        shadowY: 6
        HoverHandler { onHoveredChanged: Stats.hoverCard = hovered }

        Column {
            id: col
            x: 16; y: 16
            width: card.width - 32
            spacing: 14

            // ---------- weather ----------
            Item {
                width: parent.width
                height: Weather.status === "ok" ? 88 : 28
                Text {
                    visible: Weather.status !== "ok"
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    elide: Text.ElideRight
                    text: Weather.status === "off" ? "Weather is off · /settings → Weather (asks wttr.in)"
                        : Weather.status === "loading" ? "Loading the weather…" : "Couldn't load the weather"
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: 12 }
                }
                Item {
                    visible: Weather.status === "ok"
                    anchors.fill: parent
                    Text {
                        id: wg
                        text: Weather.glyph
                        color: Theme.accent
                        font { family: Theme.font; pixelSize: 38 }
                    }
                    Column {
                        anchors { left: wg.right; leftMargin: 12; top: parent.top; right: parent.right }
                        Text {
                            text: Weather.temp + "   " + Weather.desc
                            width: parent.width; elide: Text.ElideRight
                            color: Theme.fg
                            font { family: Theme.font; pixelSize: 17; bold: true }
                        }
                        Text {
                            text: (Weather.place !== "" ? Weather.place + "  ·  " : "") + "feels " + Weather.feels
                                  + "  ·  " + Weather.humidity + "  ·  " + Weather.wind
                            width: parent.width; elide: Text.ElideRight
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: 11 }
                        }
                    }
                    Row {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        Repeater {
                            model: Weather.days
                            delegate: Text {
                                required property var modelData
                                width: parent.width / 3
                                text: modelData.day + " " + modelData.glyph + " " + modelData.hi + "/" + modelData.lo
                                color: Theme.dim
                                font { family: Theme.font; pixelSize: 11 }
                            }
                        }
                    }
                }
            }

            // ---------- graphs ----------
            Repeater {
                model: [
                    { name: "cpu", vals: Stats.cpu, now: Stats.cpuNow + "%", max: 100, warn: Stats.cpuNow > 85, c2: false },
                    { name: "mem", vals: Stats.mem, now: Stats.memNow + "%", max: 100, warn: Stats.memNow > 90, c2: true },
                    { name: "net", vals: Stats.net, now: "↓ " + Stats.rate(Stats.rxRate) + "  ↑ " + Stats.rate(Stats.txRate), max: 0, warn: false, c2: false }
                ]
                delegate: Item {
                    id: g
                    required property var modelData
                    width: col.width
                    height: 44
                    Text {
                        id: gl
                        text: g.modelData.name
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 11 }
                    }
                    Text {
                        anchors.right: parent.right
                        text: g.modelData.now
                        color: g.modelData.warn ? Theme.warn : Theme.fg
                        font { family: Theme.font; pixelSize: 11 }
                    }
                    Spark {
                        anchors { left: parent.left; right: parent.right; top: gl.bottom; topMargin: 3; bottom: parent.bottom }
                        values: g.modelData.vals
                        maxValue: g.modelData.max
                        points: Stats.keep
                        color: g.modelData.warn ? Theme.warn : (g.modelData.c2 ? Theme.accent2 : Theme.accent)
                    }
                }
            }

            // ---------- mini calendar ----------
            Column {
                width: parent.width
                spacing: 4
                Text {
                    text: Qt.formatDate(new Date(), "MMMM yyyy").toLowerCase()
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: 12; bold: true }
                }
                Grid {
                    columns: 7
                    width: parent.width
                    Repeater {
                        model: 7
                        delegate: Text {
                            required property int index
                            width: col.width / 7; height: 16
                            horizontalAlignment: Text.AlignHCenter
                            text: ["M", "T", "W", "T", "F", "S", "S"][index]
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: 10 }
                        }
                    }
                    Repeater {
                        model: 42
                        delegate: Item {
                            id: cell
                            required property int index
                            readonly property date d: win.dateAt(index)
                            readonly property bool today: win.dayKey(d) === win.dayKey(new Date())
                            readonly property bool inMonth: d.getMonth() === new Date().getMonth()
                            width: col.width / 7; height: 20
                            Rectangle {
                                anchors.centerIn: parent
                                width: 20; height: 20; radius: 10
                                color: cell.today ? Theme.accent : "transparent"
                            }
                            Text {
                                anchors.centerIn: parent
                                text: cell.d.getDate()
                                color: cell.today ? Theme.bg : (cell.inMonth ? Theme.fg : Qt.alpha(Theme.dim, 0.5))
                                font { family: Theme.font; pixelSize: 11; bold: cell.today }
                            }
                            Rectangle {   // has events
                                visible: win.dayMap[win.dayKey(cell.d)] === true && !cell.today
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 0 }
                                width: 4; height: 4; radius: 2
                                color: Theme.accent2
                            }
                        }
                    }
                }
                Repeater {
                    model: win.todayEvents
                    delegate: Text {
                        required property var modelData
                        width: col.width
                        elide: Text.ElideRight
                        text: (modelData.allDay ? "all day" : Qt.formatTime(modelData.start, "HH:mm")) + "  " + modelData.title
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }
            }
        }
    }
}
