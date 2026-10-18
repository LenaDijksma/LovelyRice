import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Month grid + agenda for the selected day. Open with /calendar or by clicking the clock.
// ←/→ day · ↑/↓ week · PgUp/PgDn month · T today · R refresh · G open in Google Calendar · Esc close
PanelWindow {
    id: win

    property bool open: false
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(280); easing.type: Easing.OutCubic } }

    property date selected: new Date()
    property int viewYear: selected.getFullYear()
    property int viewMonth: selected.getMonth()
    property var dayMap: ({})
    onOpenChanged: Popups.report("calendar", open)
    Connections {
        target: Popups
        function onCloseOthers(except) { if (except !== "calendar" && win.open) win.hide() }
        function onCloseAll() { if (win.open) win.hide() }
    }

    function dayKey(d) { return d.getFullYear() + "-" + d.getMonth() + "-" + d.getDate() }
    function dateAt(i) {   // i-th cell of the 6x7 grid (Monday first)
        const first = new Date(viewYear, viewMonth, 1)
        const off = (first.getDay() + 6) % 7
        return new Date(viewYear, viewMonth, 1 - off + i)
    }
    function rebuild() {
        const from = dateAt(0), to = dateAt(42)
        const map = {}
        for (const e of Agenda.eventsInRange(from, to)) {
            const last = new Date(e.end.getTime() - 1)
            let d = new Date(Math.max(e.start.getTime(), from.getTime()))
            d = new Date(d.getFullYear(), d.getMonth(), d.getDate())
            for (let n = 0; n < 45 && d <= last; n++) {
                const k = dayKey(d)
                ;(map[k] = map[k] || []).push(e)
                d = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)
            }
        }
        dayMap = map
    }
    onViewMonthChanged: rebuild()
    onViewYearChanged: rebuild()
    Connections { target: Agenda; function onRevChanged() { win.rebuild() } }

    function select(d) {
        selected = new Date(d.getFullYear(), d.getMonth(), d.getDate())
        viewYear = selected.getFullYear()
        viewMonth = selected.getMonth()
    }
    function shiftDays(n) { select(new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() + n)) }
    function shiftMonths(n) {
        const d = new Date(selected.getFullYear(), selected.getMonth() + n, 1)
        const last = new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
        select(new Date(d.getFullYear(), d.getMonth(), Math.min(selected.getDate(), last)))
    }
    function show() {
        Popups.claim("calendar")
        select(new Date())
        if (!Agenda.lastSync || (new Date() - Agenda.lastSync) > 120000) Agenda.refresh()
        rebuild()
        open = true
        keys.forceActiveFocus()
    }
    function hide() { open = false }
    function toggle() { open ? hide() : show() }
    function openGoogle() {
        Quickshell.execDetached(["xdg-open", "https://calendar.google.com/calendar/u/0/r/day/"
            + selected.getFullYear() + "/" + (selected.getMonth() + 1) + "/" + selected.getDate()])
    }

    readonly property var todayEvents: dayMap[dayKey(selected)] || []

    visible: progress > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lovelyrice-calendar"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.4 * win.progress)
        MouseArea { anchors.fill: parent; onClicked: win.hide() }
    }

    Card {
        id: card
        width: 720
        height: 430
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 + (1 - win.progress) * 20
        opacity: win.progress
        scale: 0.94 + 0.06 * win.progress
        transformOrigin: Item.Center
        radius: Theme.radius + 4
        color: Qt.alpha(Theme.bg, 0.97)
        borderColor: Qt.alpha(Theme.accent, 0.8)
        borderWidth: 2
        shadowY: 18

        MouseArea { anchors.fill: parent }   // swallow clicks so the backdrop doesn't close us

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape)        win.hide()
                else if (e.key === Qt.Key_Left)     win.shiftDays(-1)
                else if (e.key === Qt.Key_Right)    win.shiftDays(1)
                else if (e.key === Qt.Key_Up)       win.shiftDays(-7)
                else if (e.key === Qt.Key_Down)     win.shiftDays(7)
                else if (e.key === Qt.Key_PageUp)   win.shiftMonths(-1)
                else if (e.key === Qt.Key_PageDown) win.shiftMonths(1)
                else if (e.key === Qt.Key_T || e.key === Qt.Key_Home) win.select(new Date())
                else if (e.key === Qt.Key_R)        Agenda.refresh()
                else if (e.key === Qt.Key_G)        win.openGoogle()
                else return
                e.accepted = true
            }
        }

        // ---------- left: month grid ----------
        Item {
            x: 24; y: 20; width: 7 * 46; height: parent.height - 60

            Text {
                x: 4; y: 0
                text: Qt.locale().monthName(win.viewMonth) + " " + win.viewYear
                color: Theme.fg
                font { family: Theme.font; pixelSize: 20; bold: true }
            }
            Row {
                anchors { right: parent.right; top: parent.top; topMargin: -4 }
                spacing: 2
                SideButton { glyph: "‹"; implicitWidth: 32; implicitHeight: 32; onClicked: win.shiftMonths(-1) }
                SideButton { glyph: "●"; implicitWidth: 32; implicitHeight: 32; onClicked: win.select(new Date()) }
                SideButton { glyph: "›"; implicitWidth: 32; implicitHeight: 32; onClicked: win.shiftMonths(1) }
            }

            Row {
                y: 42
                Repeater {
                    model: 7
                    delegate: Text {
                        required property int index
                        width: 46
                        horizontalAlignment: Text.AlignHCenter
                        text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat).slice(0, 2)
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 11 }
                    }
                }
            }

            Grid {
                y: 66
                columns: 7
                Repeater {
                    model: 42
                    delegate: Item {
                        id: cell
                        required property int index
                        readonly property date d: win.dateAt(index)
                        readonly property bool inMonth: d.getMonth() === win.viewMonth
                        readonly property bool isToday: win.dayKey(d) === win.dayKey(new Date())
                        readonly property bool isSel: win.dayKey(d) === win.dayKey(win.selected)
                        readonly property var evs: win.dayMap[win.dayKey(d)] || []
                        width: 46; height: 46

                        Rectangle {
                            anchors { fill: parent; margins: 2 }
                            radius: Theme.radiusSmall
                            color: cell.isSel ? Theme.accent : (ma.containsMouse ? Theme.surface : "transparent")
                            border.color: cell.isToday && !cell.isSel ? Theme.accent : "transparent"
                            border.width: 1.5
                            Behavior on color { ColorAnimation { duration: Theme.dur(150) } }
                            scale: ma.pressed ? 0.92 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.dur(120) } }

                            Text {
                                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
                                text: cell.d.getDate()
                                color: cell.isSel ? Theme.bg : (cell.inMonth ? Theme.fg : Theme.dim)
                                font { family: Theme.font; pixelSize: 14; bold: cell.isToday || cell.isSel }
                            }
                            Row {
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 5 }
                                spacing: 3
                                Repeater {
                                    model: Math.min(3, cell.evs.length)
                                    delegate: Rectangle {
                                        required property int index
                                        width: 5; height: 5; radius: 2.5
                                        color: cell.isSel ? Theme.bg : Agenda.colorFor(cell.evs[index].source)
                                    }
                                }
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: win.select(cell.d)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {   // divider
            x: 24 + 7 * 46 + 18; y: 24; width: 1; height: parent.height - 70
            color: Qt.alpha(Theme.dim, 0.35)
        }

        // ---------- right: agenda ----------
        Item {
            x: 24 + 7 * 46 + 38; y: 20
            width: parent.width - x - 24
            height: parent.height - 60

            Text {
                text: Qt.formatDate(win.selected, "dddd")
                color: Theme.accent
                font { family: Theme.font; pixelSize: 12 }
            }
            Text {
                y: 18
                text: Qt.formatDate(win.selected, "d MMMM")
                color: Theme.fg
                font { family: Theme.font; pixelSize: 20; bold: true }
            }

            ListView {
                y: 58
                width: parent.width
                height: parent.height - 58
                clip: true
                spacing: 8
                model: win.todayEvents
                boundsBehavior: Flickable.StopAtBounds
                populate: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.dur(200) }
                    NumberAnimation { property: "x"; from: 14; duration: Theme.dur(240); easing.type: Easing.OutCubic }
                }
                delegate: Rectangle {
                    id: ev
                    required property var modelData
                    width: ListView.view.width
                    height: evCol.implicitHeight + 16
                    radius: Theme.radiusSmall
                    color: Theme.surface
                    Rectangle {
                        x: 0; y: 8; width: 4; height: parent.height - 16; radius: 2
                        color: Agenda.colorFor(ev.modelData.source)
                    }
                    Column {
                        id: evCol
                        x: 16; y: 8
                        width: parent.width - 28
                        spacing: 2
                        Text {
                            text: ev.modelData.allDay ? "all day"
                                  : Qt.formatTime(ev.modelData.start, "HH:mm") + " – " + Qt.formatTime(ev.modelData.end, "HH:mm")
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: 11 }
                        }
                        Text {
                            width: parent.width
                            text: ev.modelData.title
                            color: Theme.fg
                            elide: Text.ElideRight
                            font { family: Theme.font; pixelSize: 14; bold: true }
                        }
                        Text {
                            visible: text !== ""
                            width: parent.width
                            text: ev.modelData.location
                            color: Theme.dim
                            elide: Text.ElideRight
                            font { family: Theme.font; pixelSize: 11 }
                        }
                    }
                }
            }

            Text {   // empty / not linked states
                anchors.centerIn: parent
                width: parent.width - 10
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                visible: win.todayEvents.length === 0
                color: Theme.dim
                font { family: Theme.font; pixelSize: 12 }
                text: Agenda.status === "none"
                      ? "No calendar linked.\nAdd an iCal URL to\n~/.config/lovelyrice/config.json\n(see config.example.json)"
                      : (Agenda.status === "error" ? "Could not load a calendar.\nCheck the URL in config.json."
                         : (Agenda.status === "loading" ? "Loading…" : "Nothing planned"))
            }
        }

        // ---------- footer ----------
        Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 12 }
            horizontalAlignment: Text.AlignHCenter
            text: "←↑↓→ move   pgup/pgdn month   t today   r refresh   g google calendar   esc close"
                  + (Agenda.lastSync ? "   ·   synced " + Qt.formatTime(Agenda.lastSync, "HH:mm") : "")
            color: Theme.dim
            font { family: Theme.font; pixelSize: 10 }
        }
    }
}
