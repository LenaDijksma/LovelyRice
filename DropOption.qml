import QtQuick

// One choice in a radio list (audio devices, power profile) in the dropdown tabs.
Item {
    id: root
    property string label: ""
    property bool selected: false
    signal clicked()
    implicitHeight: 28

    Rectangle {
        anchors.fill: parent
        radius: 4
        color: Qt.alpha(Theme.fg, area.containsMouse ? 0.07 : 0)
        Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
    }
    Rectangle {
        id: dot
        x: 6; anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14; radius: 7
        color: "transparent"
        border.width: 1.5
        border.color: root.selected ? Theme.accent : Qt.alpha(Theme.dim, 0.7)
        Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Theme.accent; visible: root.selected }
    }
    Text {
        anchors { left: dot.right; leftMargin: 10; right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
        text: root.label
        elide: Text.ElideRight
        color: root.selected ? Theme.fg : Theme.dim
        font { family: Theme.font; pixelSize: 12 }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
}
