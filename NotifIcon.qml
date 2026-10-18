import QtQuick
import Quickshell

// Notification icon: the notification's own image, else the app icon, else a letter badge.
Item {
    id: root
    property string image: ""
    property string icon: ""
    property string app: ""
    property color tint: Theme.accent
    implicitWidth: 40
    implicitHeight: 40

    readonly property string iconSource: {
        if (icon === "") return ""
        if (icon.startsWith("/")) return "file://" + icon
        if (icon.indexOf("://") > 0) return icon
        return Quickshell.iconPath(icon, true)       // theme icon name; "" if the theme has none
    }
    readonly property string src: image !== "" ? image : iconSource

    Rectangle {
        anchors.fill: parent
        visible: pic.status !== Image.Ready
        radius: Theme.radiusSmall + 2
        color: Qt.alpha(root.tint, 0.18)
        Text {
            anchors.centerIn: parent
            text: (root.app || "?")[0].toUpperCase()
            color: root.tint
            font { family: Theme.font; pixelSize: Math.round(root.height * 0.45); bold: true }
        }
    }
    Image {
        id: pic
        anchors.fill: parent
        visible: status === Image.Ready
        source: root.src
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        sourceSize: Qt.size(width * 2, height * 2)
    }
}
