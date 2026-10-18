import QtQuick

// Small pill button for notification actions and the history panel header.
Rectangle {
    id: root
    property string label: ""
    property bool active: false
    signal clicked()

    implicitHeight: 26
    implicitWidth: txt.implicitWidth + 22
    radius: height / 2
    color: active ? Qt.alpha(Theme.accent, 0.25)
                  : Qt.alpha(Theme.fg, mouse.containsMouse ? 0.14 : 0.06)
    border.width: 1
    border.color: active ? Theme.accent : Qt.alpha(Theme.dim, 0.35)
    Behavior on color { ColorAnimation { duration: Theme.dur(120) } }

    Text {
        id: txt
        anchors.centerIn: parent
        text: root.label
        color: root.active ? Theme.accent : Theme.fg
        font { family: Theme.font; pixelSize: 11 }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
