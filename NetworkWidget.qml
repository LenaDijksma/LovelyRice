import QtQuick

// Wi-Fi / ethernet status icon. Click opens the network list in the palette.
Item {
    id: root
    signal clicked()
    visible: Settings.showNetwork
    implicitWidth: Theme.cell
    implicitHeight: visible ? Theme.iconSize + 8 : 0
    scale: area.pressed ? 0.9 : (area.containsMouse ? 1.1 : 1.0)
    Behavior on scale { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutBack } }

    Icon {
        anchors.centerIn: parent
        width: Theme.iconSize; height: Theme.iconSize
        kind: Net.connType === "ethernet" ? "ethernet" : (Net.connType === "wifi" && Net.wifiEnabled ? "wifi" : "wifi-off")
        level: Net.signal / 100
        color: Net.connType === "" ? Theme.dim : Theme.fg
        Behavior on color { ColorAnimation { duration: Theme.dur(250) } }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: root.clicked() }
}
