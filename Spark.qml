import QtQuick

// Small area graph. `values` is a list of numbers, newest last; maxValue 0 = scale to the data.
Canvas {
    id: root
    property var values: []
    property real maxValue: 100
    property int points: 40
    property color color: Theme.accent
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        const n = values.length
        if (n < 2 || width <= 0) return
        let m = maxValue
        if (m <= 0) { m = 10240; for (let i = 0; i < n; i++) m = Math.max(m, values[i]) }
        const step = width / (points - 1)
        const xs = i => width - (n - 1 - i) * step
        const ys = v => height - 2 - Math.min(1, Math.max(0, v / m)) * (height - 4)
        ctx.beginPath()
        ctx.moveTo(xs(0), height)
        for (let i = 0; i < n; i++) ctx.lineTo(xs(i), ys(values[i]))
        ctx.lineTo(xs(n - 1), height)
        ctx.closePath()
        ctx.fillStyle = Qt.alpha(root.color, 0.18)
        ctx.fill()
        ctx.beginPath()
        for (let i = 0; i < n; i++) { if (i === 0) ctx.moveTo(xs(i), ys(values[i])); else ctx.lineTo(xs(i), ys(values[i])) }
        ctx.strokeStyle = root.color
        ctx.lineWidth = 1.6
        ctx.lineJoin = "round"
        ctx.stroke()
    }
}
