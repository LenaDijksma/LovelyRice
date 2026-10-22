import QtQuick

// Bluetooth status icon: dim when off, accent when a device is connected. Click opens the device list.
Item {
    id: root
    readonly property bool horizontal: Bar.horizontalFor(root)       // which way this bar runs (a split bar can have one of each)
    signal clicked()
    visible: Settings.showBluetooth && Bt.available
    implicitWidth: root.horizontal ? (visible ? Theme.iconSize + 8 : 0) : Theme.cell
    implicitHeight: root.horizontal ? Theme.cell : (visible ? Theme.iconSize + 8 : 0)
    scale: area.pressed ? 0.9 : (area.containsMouse ? 1.1 : 1.0)
    Behavior on scale { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutBack } }

    Icon {
        anchors.centerIn: parent
        width: Theme.iconSize; height: Theme.iconSize
        kind: Bt.powered ? "bluetooth" : "bluetooth-off"
        color: !Bt.powered ? Theme.dim : (Bt.connectedCount > 0 ? Theme.accent : Theme.fg)
        Behavior on color { ColorAnimation { duration: Theme.dur(250) } }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
}
