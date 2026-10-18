import QtQuick

// Generic outline icons for kinds of apps (browser, files, terminal, ...), drawn with Canvas
// so they take the theme colors. Used instead of per-app icons.
Item {
    id: root
    property string kind: "window"
    property color color: Theme.fg
    implicitWidth: 26
    implicitHeight: 26

    onKindChanged: c.requestPaint()
    onColorChanged: c.requestPaint()

    Canvas {
        id: c
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            const w = width, h = height
            ctx.strokeStyle = root.color
            ctx.fillStyle = root.color
            ctx.lineWidth = w * 0.075
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            const poly = (pts, close) => {
                ctx.beginPath()
                ctx.moveTo(pts[0][0] * w, pts[0][1] * h)
                for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0] * w, pts[i][1] * h)
                if (close) ctx.closePath()
                ctx.stroke()
            }
            const line = (x1, y1, x2, y2) => poly([[x1, y1], [x2, y2]], false)
            const circle = (x, y, r, fill) => {
                ctx.beginPath(); ctx.arc(x * w, y * h, r * w, 0, Math.PI * 2)
                fill ? ctx.fill() : ctx.stroke()
            }

            switch (root.kind) {
            case "browser":      // globe
                circle(.5, .5, .38)
                ctx.beginPath(); ctx.ellipse(w * .34, h * .12, w * .32, h * .76); ctx.stroke()
                line(.12, .5, .88, .5)
                break
            case "files":        // folder
                poly([[.12, .26], [.38, .26], [.46, .38], [.88, .38], [.88, .78], [.12, .78]], true)
                break
            case "terminal":     // prompt in a box
                poly([[.10, .20], [.90, .20], [.90, .80], [.10, .80]], true)
                poly([[.24, .38], [.38, .50], [.24, .62]], false)
                line(.46, .64, .66, .64)
                break
            case "game":         // controller
                poly([[.16, .34], [.84, .34], [.92, .70], [.78, .74], [.66, .60], [.34, .60], [.22, .74], [.08, .70]], true)
                line(.30, .43, .30, .55); line(.24, .49, .36, .49)
                circle(.64, .45, .035, true); circle(.74, .51, .035, true)
                break
            case "code":         // < / >
                poly([[.34, .30], [.14, .50], [.34, .70]], false)
                poly([[.66, .30], [.86, .50], [.66, .70]], false)
                line(.56, .24, .44, .76)
                break
            case "chat":         // speech bubble
                poly([[.12, .20], [.88, .20], [.88, .66], [.52, .66], [.30, .82], [.32, .66], [.12, .66]], true)
                break
            case "mail":         // envelope
                poly([[.10, .26], [.90, .26], [.90, .74], [.10, .74]], true)
                poly([[.10, .26], [.50, .56], [.90, .26]], false)
                break
            case "music":        // beamed notes
                circle(.30, .72, .10); circle(.68, .64, .10)
                line(.40, .72, .40, .26); line(.78, .64, .78, .18); line(.40, .26, .78, .18)
                break
            case "video":        // play button in a frame
                poly([[.10, .24], [.90, .24], [.90, .76], [.10, .76]], true)
                poly([[.42, .38], [.64, .50], [.42, .62]], true)
                break
            case "image":        // picture
                poly([[.12, .20], [.88, .20], [.88, .80], [.12, .80]], true)
                circle(.34, .40, .06)
                poly([[.12, .72], [.38, .54], [.54, .68], [.68, .56], [.88, .74]], false)
                break
            case "docs":         // page with folded corner
                poly([[.26, .14], [.60, .14], [.76, .30], [.76, .86], [.26, .86]], true)
                line(.60, .14, .60, .30); line(.60, .30, .76, .30)
                line(.36, .54, .66, .54); line(.36, .68, .66, .68)
                break
            case "system":       // gear
                circle(.5, .5, .13)
                circle(.5, .5, .28)
                for (let i = 0; i < 8; i++) {
                    const a = i * Math.PI / 4
                    line(.5 + Math.cos(a) * .28, .5 + Math.sin(a) * .28, .5 + Math.cos(a) * .40, .5 + Math.sin(a) * .40)
                }
                break
            default:             // generic window
                poly([[.12, .20], [.88, .20], [.88, .80], [.12, .80]], true)
                line(.12, .36, .88, .36)
            }
        }
    }
}
