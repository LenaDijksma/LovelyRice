import QtQuick

// Crisp vector icons drawn with Canvas: volume, muted, brightness, wifi, wifi-off, ethernet, bluetooth, bluetooth-off,
// mic, mic-off, bell, bell-off.
Item {
    id: root
    property string kind: "volume"
    property color color: Theme.fg
    property real level: 1             // 0..1: volume waves / wifi strength
    implicitWidth: 26
    implicitHeight: 26

    onKindChanged: c.requestPaint()
    onColorChanged: c.requestPaint()
    onLevelChanged: c.requestPaint()

    Canvas {
        id: c
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            ctx.fillStyle = root.color
            ctx.strokeStyle = root.color
            ctx.lineWidth = w * 0.09
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            const line = (x1, y1, x2, y2) => { ctx.beginPath(); ctx.moveTo(x1 * w, y1 * h); ctx.lineTo(x2 * w, y2 * h); ctx.stroke() }

            if (root.kind === "brightness") {
                const cx = w / 2, cy = h / 2
                ctx.beginPath(); ctx.arc(cx, cy, w * 0.19, 0, Math.PI * 2); ctx.fill()
                for (let i = 0; i < 8; i++) {
                    const a = i * Math.PI / 4
                    ctx.beginPath()
                    ctx.moveTo(cx + Math.cos(a) * w * 0.31, cy + Math.sin(a) * h * 0.31)
                    ctx.lineTo(cx + Math.cos(a) * w * 0.44, cy + Math.sin(a) * h * 0.44)
                    ctx.stroke()
                }
            } else if (root.kind === "mic" || root.kind === "mic-off") {
                ctx.beginPath()                                   // capsule
                ctx.arc(w * .5, h * .27, w * .12, Math.PI, 0)
                ctx.lineTo(w * .62, h * .45)
                ctx.arc(w * .5, h * .45, w * .12, 0, Math.PI)
                ctx.closePath()
                ctx.fill()
                ctx.beginPath(); ctx.arc(w * .5, h * .45, w * .22, 0, Math.PI); ctx.stroke()   // holder
                line(.5, .67, .5, .82); line(.36, .84, .64, .84)
                if (root.kind === "mic-off") line(.16, .14, .84, .86)
            } else if (root.kind === "bell" || root.kind === "bell-off") {
                ctx.beginPath()
                ctx.arc(w * .5, h * .42, w * .24, Math.PI, 0)
                ctx.lineTo(w * .74, h * .58); ctx.lineTo(w * .82, h * .70)
                ctx.lineTo(w * .18, h * .70); ctx.lineTo(w * .26, h * .58)
                ctx.closePath()
                ctx.stroke()
                line(.5, .12, .5, .18)
                ctx.beginPath(); ctx.arc(w * .5, h * .81, w * .06, 0, Math.PI * 2); ctx.fill()
                if (root.kind === "bell-off") line(.16, .14, .84, .86)
            } else if (root.kind === "wifi" || root.kind === "wifi-off") {
                const bars = root.kind === "wifi-off" ? 0 : (root.level > 0.66 ? 3 : (root.level > 0.33 ? 2 : (root.level > 0.05 ? 1 : 0)))
                ctx.beginPath(); ctx.arc(w * .5, h * .80, w * .06, 0, Math.PI * 2); ctx.fill()
                for (let n = 1; n <= 3; n++) {
                    ctx.globalAlpha = n <= bars ? 1.0 : 0.28
                    ctx.beginPath()
                    ctx.arc(w * .5, h * .80, w * (0.16 + 0.17 * n), -2.36, -0.78)
                    ctx.stroke()
                }
                ctx.globalAlpha = 1.0
                if (root.kind === "wifi-off") line(.16, .14, .84, .86)
            } else if (root.kind === "ethernet") {
                ctx.beginPath()
                ctx.rect(w * .22, h * .20, w * .56, h * .40)
                ctx.stroke()
                line(.36, .20, .36, .34); line(.50, .20, .50, .34); line(.64, .20, .64, .34)
                line(.50, .60, .50, .78); line(.30, .78, .70, .78)
            } else if (root.kind === "bluetooth" || root.kind === "bluetooth-off") {
                ctx.beginPath()
                ctx.moveTo(w * .32, h * .30); ctx.lineTo(w * .68, h * .64); ctx.lineTo(w * .50, h * .82)
                ctx.lineTo(w * .50, h * .18); ctx.lineTo(w * .68, h * .36); ctx.lineTo(w * .32, h * .70)
                ctx.stroke()
                if (root.kind === "bluetooth-off") line(.16, .14, .84, .86)
            } else {   // volume / muted
                ctx.beginPath()
                ctx.moveTo(w * .10, h * .38); ctx.lineTo(w * .28, h * .38); ctx.lineTo(w * .48, h * .20)
                ctx.lineTo(w * .48, h * .80); ctx.lineTo(w * .28, h * .62); ctx.lineTo(w * .10, h * .62)
                ctx.closePath(); ctx.fill()
                if (root.kind === "muted") {
                    line(.62, .38, .90, .62); line(.90, .38, .62, .62)
                } else {
                    const waves = root.level > 0.66 ? 3 : (root.level > 0.25 ? 2 : 1)
                    for (let n = 1; n <= waves; n++) {
                        ctx.beginPath()
                        ctx.arc(w * .46, h * .5, w * (0.14 + 0.13 * n), -0.75, 0.75)
                        ctx.stroke()
                    }
                }
            }
        }
    }
}
