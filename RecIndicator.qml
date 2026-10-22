import QtQuick

// Shows in the bar while a screen recording is running. Click to stop.
Rectangle {
    id: root
    readonly property bool horizontal: Bar.horizontalFor(root)       // which way this bar runs (a split bar can have one of each)
    visible: Recorder.active
    implicitWidth: root.horizontal ? (visible ? stack.implicitWidth + 16 : 0) : 0
    implicitHeight: root.horizontal ? 0 : (visible ? stack.implicitHeight + 12 : 0)
    radius: Theme.pillRadius
    color: Qt.alpha("#ff4d4d", 0.16)
    border.width: 1
    border.color: Qt.alpha("#ff4d4d", 0.6)

    BarStack {
        id: stack
        anchors.centerIn: parent
        spacing: root.horizontal ? 6 : 3
        Rectangle {
            width: 10; height: 10; radius: 5
            color: "#ff4d4d"
            SequentialAnimation on opacity {
                running: root.visible && Theme.animScale > 0
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: Theme.dur(600); easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0;  duration: Theme.dur(600); easing.type: Easing.InOutSine }
            }
        }
        Text {
            readonly property int m: Math.floor(Recorder.elapsed / 60)
            readonly property int s: Recorder.elapsed % 60
            text: (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
            color: Theme.fg
            font { family: Theme.font; pixelSize: Theme.fs(10); bold: true }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Recorder.stop() }
}
