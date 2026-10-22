import QtQuick
import Quickshell

// Left/right bar: hours, minutes and the date stacked. Top/bottom bar: one line, "14:05  wed 22".
Item {
    id: root
    signal clicked()
    readonly property bool horizontal: Bar.horizontalFor(root)
    implicitWidth: horizontal ? row.implicitWidth : col.implicitWidth
    implicitHeight: horizontal ? Theme.cell : col.implicitHeight
    scale: area.pressed ? 0.94 : (area.containsMouse ? 1.05 : 1.0)
    Behavior on scale { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutBack } }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        id: col
        visible: !root.horizontal
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH")
            color: Theme.fg
            font { family: Theme.font; pixelSize: Math.round(Theme.cell * 0.62); bold: true }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "mm")
            color: Theme.accent
            font { family: Theme.font; pixelSize: Math.round(Theme.cell * 0.62); bold: true }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            topPadding: 2
            text: Qt.formatDateTime(clock.date, "ddd d").toLowerCase()
            color: Theme.dim
            font { family: Theme.font; pixelSize: Theme.fs(9) }
        }
    }

    Row {
        id: row
        visible: root.horizontal
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Row {
            anchors.verticalCenter: parent.verticalCenter
            Text {
                text: Qt.formatDateTime(clock.date, "HH")
                color: Theme.fg
                font { family: Theme.font; pixelSize: Math.round(Theme.cell * 0.55); bold: true }
            }
            Text {
                text: ":"
                color: Theme.dim
                font { family: Theme.font; pixelSize: Math.round(Theme.cell * 0.55); bold: true }
            }
            Text {
                text: Qt.formatDateTime(clock.date, "mm")
                color: Theme.accent
                font { family: Theme.font; pixelSize: Math.round(Theme.cell * 0.55); bold: true }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "ddd d").toLowerCase()
            color: Theme.dim
            font { family: Theme.font; pixelSize: Theme.fs(10) }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onEntered: {
            const p = root.mapToItem(null, root.width / 2, root.height / 2)
            Stats.widgetX = p.x; Stats.widgetY = p.y
            Stats.hoverWidget = true
        }
        onExited: Stats.hoverWidget = false
        onClicked: root.clicked()
    }
}
