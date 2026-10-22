import QtQuick

// Dashboard tab of the dropdown: weather and calendar on the left, system graphs on the right (one column when narrow).
// Flat and hairline-ruled, with big numbers — deliberately not the look of the Dashboard popout.
Item {
    id: root
    readonly property bool wide: width >= 520
    readonly property real gapX: 28
    readonly property real colW: wide ? (width - gapX) / 2 : width
    implicitHeight: grid.implicitHeight

    // ---- calendar data ----
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
    onVisibleChanged: if (visible) { Weather.ensure(); rebuild() }
    Component.onCompleted: rebuild()

    Grid {
        id: grid
        columns: root.wide ? 2 : 1
        columnSpacing: root.gapX
        rowSpacing: 22

        // ---------- weather + calendar ----------
        Column {
            width: root.colW
            spacing: 12

            DropHeader { width: parent.width; text: "weather" }
            Text {
                visible: Weather.status !== "ok"
                width: parent.width
                elide: Text.ElideRight
                text: Weather.status === "off" ? "Weather is off · /settings → Weather (asks wttr.in)"
                    : Weather.status === "loading" ? "Loading the weather…" : "Couldn't load the weather"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 12 }
            }
            Column {
                visible: Weather.status === "ok"
                width: parent.width
                spacing: 10
                Row {
                    spacing: 14
                    Text { text: Weather.glyph; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter
                           font { family: Theme.font; pixelSize: 40 } }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: Weather.temp; color: Theme.fg; font { family: Theme.font; pixelSize: 38; bold: true } }
                        Text { text: Weather.desc; color: Theme.dim; font { family: Theme.font; pixelSize: 13 } }
                    }
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: (Weather.place !== "" ? Weather.place + "  ·  " : "") + "feels " + Weather.feels
                          + "  ·  " + Weather.humidity + "  ·  " + Weather.wind
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: 11 }
                }
                Row {
                    width: parent.width
                    Repeater {
                        model: Weather.days
                        delegate: Column {
                            required property var modelData
                            width: parent.width / 3
                            Text { text: modelData.day.toUpperCase(); color: Theme.dim
                                   font { family: Theme.font; pixelSize: 9; letterSpacing: 1.2 } }
                            Text { text: modelData.glyph + "  " + modelData.hi + " / " + modelData.lo; color: Theme.fg
                                   font { family: Theme.font; pixelSize: 12 } }
                        }
                    }
                }
            }

            DropHeader { width: parent.width; text: Qt.formatDate(new Date(), "MMMM yyyy") }
            Grid {
                columns: 7
                width: parent.width
                Repeater {
                    model: 7
                    delegate: Text {
                        required property int index
                        width: parent.width / 7; height: 18
                        horizontalAlignment: Text.AlignHCenter
                        text: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"][index]
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 8; letterSpacing: 1 }
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
                        width: parent.width / 7; height: 26
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 22; radius: 4
                            color: cell.today ? Theme.accent : "transparent"
                        }
                        Text {
                            anchors.centerIn: parent
                            text: cell.d.getDate()
                            color: cell.today ? Theme.bg : (cell.inMonth ? Theme.fg : Qt.alpha(Theme.dim, 0.45))
                            font { family: Theme.font; pixelSize: 11; bold: cell.today }
                        }
                        Rectangle {   // has events
                            visible: root.dayMap[root.dayKey(cell.d)] === true && !cell.today
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                            width: 12; height: 2; radius: 1
                            color: Theme.accent2
                        }
                    }
                }
            }
            Repeater {
                model: root.todayEvents
                delegate: Row {
                    required property var modelData
                    spacing: 10
                    Text { text: modelData.allDay ? "ALL DAY" : Qt.formatTime(modelData.start, "HH:mm"); color: Theme.accent2
                           font { family: Theme.font; pixelSize: 10; letterSpacing: 1 } }
                    Text { text: modelData.title; color: Theme.fg; elide: Text.ElideRight; width: root.colW - 80
                           font { family: Theme.font; pixelSize: 11 } }
                }
            }
        }

        // ---------- system ----------
        Column {
            width: root.colW
            spacing: 14

            DropHeader { width: parent.width; text: "system" }
            Repeater {
                model: [
                    { name: "cpu", vals: Stats.cpu, now: Stats.cpuNow + "%", max: 100, warn: Stats.cpuNow > 85, c2: false },
                    { name: "memory", vals: Stats.mem, now: Stats.memNow + "%", max: 100, warn: Stats.memNow > 90, c2: true },
                    { name: "network", vals: Stats.net, now: "↓ " + Stats.rate(Stats.rxRate) + "   ↑ " + Stats.rate(Stats.txRate), max: 0, warn: false, c2: false }
                ]
                delegate: Column {
                    id: g
                    required property var modelData
                    width: root.colW
                    spacing: 4
                    Item {
                        width: parent.width; height: 24
                        Text { anchors.verticalCenter: parent.verticalCenter; text: g.modelData.name.toUpperCase(); color: Theme.dim
                               font { family: Theme.font; pixelSize: 10; letterSpacing: 1.4 } }
                        Text { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                               text: g.modelData.now
                               color: g.modelData.warn ? Theme.warn : Theme.fg
                               font { family: Theme.font; pixelSize: g.modelData.name === "network" ? 13 : 20; bold: true } }
                    }
                    Spark {
                        width: parent.width; height: 44
                        values: g.modelData.vals
                        maxValue: g.modelData.max
                        points: Stats.keep
                        color: g.modelData.warn ? Theme.warn : (g.modelData.c2 ? Theme.accent2 : Theme.accent)
                    }
                }
            }
        }
    }
}
