import QtQuick

// Square icon button for the bar.
Rectangle {
    id: btn
    property string glyph: ""
    signal clicked()

    implicitWidth: Theme.cell
    implicitHeight: Theme.cell
    radius: Theme.innerRadius
    color: area.containsMouse ? Theme.surface : "transparent"
    scale: area.pressed ? 0.88 : (area.containsMouse ? 1.1 : 1.0)

    Behavior on color { ColorAnimation { duration: Theme.dur(150) } }
    Behavior on scale { NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutBack } }

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        color: area.containsMouse ? Theme.accent : Theme.fg
        font { family: Theme.font; pixelSize: Math.round(Theme.cell * 0.5) }
        Behavior on color { ColorAnimation { duration: Theme.dur(150) } }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}
