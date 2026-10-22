import QtQuick

// Section label used inside the dropdown tabs: small spaced capitals and a hairline.
Item {
    id: root
    property string text: ""
    implicitHeight: 20
    Text {
        id: t
        anchors.verticalCenter: parent.verticalCenter
        text: root.text.toUpperCase()
        color: Theme.dim
        font { family: Theme.font; pixelSize: 10; letterSpacing: 1.6 }
    }
    Rectangle {
        anchors { left: t.right; leftMargin: 10; right: parent.right; verticalCenter: parent.verticalCenter }
        height: 1
        color: Qt.alpha(Theme.dim, 0.25)
    }
}
