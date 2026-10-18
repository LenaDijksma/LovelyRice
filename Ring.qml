import QtQuick

// Animated circular gauge.
Item {
    id: root
    property real value: 0          // 0..1
    property string label: ""
    property color color: Theme.accent
    implicitWidth: Theme.cell
    implicitHeight: Theme.cell

    Behavior on value { NumberAnimation { duration: Theme.dur(600); easing.type: Easing.OutCubic } }
    onValueChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    Connections {
        target: Theme
        function onDimChanged() { canvas.requestPaint() }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const cx = width / 2, cy = height / 2, r = width / 2 - 3
            ctx.lineWidth = 3.5
            ctx.lineCap = "round"
            ctx.strokeStyle = Qt.alpha(Theme.dim, 0.3)
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
            ctx.strokeStyle = root.color
            ctx.beginPath()
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.03, Math.min(1, root.value)))
            ctx.stroke()
        }
    }
    Text {
        anchors.centerIn: parent
        text: root.label
        color: Theme.dim
        font { family: Theme.font; pixelSize: Math.max(7, Math.round(Theme.cell * 0.24)) }
    }
}
