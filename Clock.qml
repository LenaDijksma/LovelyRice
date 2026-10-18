import QtQuick
import Quickshell

Item {
    id: root
    signal clicked()
    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight
    scale: area.pressed ? 0.94 : (area.containsMouse ? 1.05 : 1.0)
    Behavior on scale { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutBack } }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        id: col
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
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onEntered: { Stats.widgetY = root.mapToItem(null, 0, root.height / 2).y; Stats.hoverWidget = true }
        onExited: Stats.hoverWidget = false
        onClicked: root.clicked()
    }
}
