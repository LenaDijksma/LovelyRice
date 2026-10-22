import QtQuick
import Quickshell

// Weather, CPU / memory / network graphs and a mini calendar. One body, two homes:
// the Dashboard popout (hover the bar clock) and the dropdown panel.
Item {
    id: root
    implicitWidth: 340
    implicitHeight: col.implicitHeight + 32

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
    Connections { target: Agenda; function onRevChanged() { if (root.visible) root.rebuild() } }

    function refresh() { Weather.ensure(); rebuild() }
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: rebuild()

    Column {
        id: col
        x: 16; y: 16
        width: root.width - 32
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
                            readonly property date d: root.dateAt(index)
                            readonly property bool today: root.dayKey(d) === root.dayKey(new Date())
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
                                visible: root.dayMap[root.dayKey(cell.d)] === true && !cell.today
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 0 }
                                width: 4; height: 4; radius: 2
                                color: Theme.accent2
                            }
                        }
                    }
                }
                Repeater {
                    model: root.todayEvents
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
