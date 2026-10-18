import QtQuick

// Small horizontal slider with a gradient track (hue rainbow, or three colour stops).
Item {
    id: root
    property string label: ""
    property real value: 0
    property real from: 0
    property real to: 100
    property bool rainbow: false
    property color c0: "black"
    property color c1: "gray"
    property color c2: "white"
    property string valueText: Math.round(value)
    signal moved(real v)

    implicitHeight: 34
    readonly property real frac: to > from ? (value - from) / (to - from) : 0

    Text {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: Theme.dim
        font { family: Theme.font; pixelSize: 11 }
    }
    Rectangle {
        id: track
        x: 70; width: parent.width - 70 - 46; height: 10; radius: 5
        anchors.verticalCenter: parent.verticalCenter
        border.color: Qt.alpha(Theme.dim, 0.4)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.000; color: root.rainbow ? "#ff0000" : root.c0 }
            GradientStop { position: 0.167; color: root.rainbow ? "#ffff00" : root.c0 }
            GradientStop { position: 0.333; color: root.rainbow ? "#00ff00" : root.c1 }
            GradientStop { position: 0.500; color: root.rainbow ? "#00ffff" : root.c1 }
            GradientStop { position: 0.667; color: root.rainbow ? "#0000ff" : root.c1 }
            GradientStop { position: 0.833; color: root.rainbow ? "#ff00ff" : root.c2 }
            GradientStop { position: 1.000; color: root.rainbow ? "#ff0000" : root.c2 }
        }
        Rectangle {
            x: parent.width * root.frac - 8; y: -3
            width: 16; height: 16; radius: 8
            color: Theme.fg
            border.color: Theme.bg; border.width: 2
        }
    }
    Text {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: root.valueText
        color: Theme.dim
        font { family: Theme.font; pixelSize: 11 }
    }
    MouseArea {
        anchors { left: track.left; right: track.right; top: parent.top; bottom: parent.bottom; leftMargin: -8; rightMargin: -8 }
        function setFrom(mx) {
            const f = Math.max(0, Math.min(1, mapToItem(track, mx, 0).x / track.width))
            root.moved(root.from + f * (root.to - root.from))
        }
        onPressed: mouse => setFrom(mouse.x)
        onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
    }
}
