import QtQuick

// Sliding on/off switch for the dropdown tabs.
Item {
    id: root
    property bool on: false
    signal toggled()
    implicitWidth: 38
    implicitHeight: 20
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.on ? Theme.accent : Qt.alpha(Theme.dim, area.containsMouse ? 0.45 : 0.3)
        Behavior on color { ColorAnimation { duration: Theme.dur(140) } }
        Rectangle {
            y: 3; width: 14; height: 14; radius: 7
            x: root.on ? parent.width - width - 3 : 3
            color: root.on ? Theme.bg : Theme.fg
            Behavior on x { NumberAnimation { duration: Theme.dur(160); easing.type: Easing.OutCubic } }
        }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggled() }
}
