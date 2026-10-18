import QtQuick
import QtQuick.Effects

// Rounded surface with a soft drop shadow. Children go inside the card.
Item {
    id: root
    property color color: Theme.bg
    property real radius: Theme.radius
    property color borderColor: Qt.alpha(Theme.accent, 0.25)
    property real borderWidth: 1
    property real shadowX: 0
    property real shadowY: 10
    default property alias content: body.data

    Rectangle {
        id: shape
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.color: root.borderColor
        border.width: root.borderWidth
        visible: false
    }
    MultiEffect {
        anchors.fill: shape
        source: shape
        shadowEnabled: true
        shadowColor: "black"
        shadowOpacity: Theme.shadowOpacity
        shadowBlur: 1.0
        blurMax: 40
        shadowHorizontalOffset: root.shadowX
        shadowVerticalOffset: root.shadowY
    }
    Item { id: body; anchors.fill: parent }
}
