import QtQuick
import Quickshell.Services.UPower

// Battery icon that fills with charge level; shows a lightning bolt and gently pulses while charging.
// Hover it to see the time remaining. Only appears on machines with a battery (and when enabled in /settings).
Item {
    id: root
    readonly property bool horizontal: Bar.horizontalFor(root)       // which way this bar runs (a split bar can have one of each)
    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.isLaptopBattery
    readonly property real pct: present ? dev.percentage : 0
    readonly property bool charging: present && dev.state === UPowerDeviceState.Charging
    readonly property color tint: charging ? Theme.accent2 : (pct <= 0.15 ? Theme.warn : Theme.fg)
    readonly property real bw: Theme.cell - 8
    readonly property real bh: Math.round(bw * 0.54)

    visible: present && Settings.showBattery
    implicitWidth: root.horizontal ? (visible ? stack.implicitWidth + 4 : 0) : Theme.cell
    implicitHeight: root.horizontal ? Theme.cell : (visible ? bh + Theme.fs(10) + 6 : 0)

    BarStack {
        id: stack
        anchors.centerIn: parent
        spacing: root.horizontal ? 5 : 2

        Item {
            width: root.bw + 4; height: root.bh

            Rectangle {   // body
                id: body
                width: root.bw; height: root.bh; radius: Math.round(root.bh * 0.25)
                color: "transparent"
                border.color: root.tint
                border.width: 1.5
                Behavior on border.color { ColorAnimation { duration: Theme.dur(300) } }

                Rectangle {   // fill
                    x: 2.5; y: 2.5
                    height: parent.height - 5
                    width: Math.max(2, (parent.width - 5) * root.pct)
                    radius: 2
                    color: root.tint
                    Behavior on width { NumberAnimation { duration: Theme.dur(500); easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: Theme.dur(300) } }
                    SequentialAnimation on opacity {
                        running: root.charging && Theme.animScale > 0
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.55; duration: Theme.dur(900); easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: Theme.dur(900); easing.type: Easing.InOutSine }
                    }
                }

                Canvas {   // lightning bolt
                    id: bolt
                    anchors.fill: parent
                    opacity: root.charging ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.dur(250) } }
                    onOpacityChanged: requestPaint()
                    Connections { target: Theme; function onFgChanged() { bolt.requestPaint() }
                                                 function onBgChanged() { bolt.requestPaint() } }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset()
                        const w = width, h = height
                        ctx.beginPath()
                        ctx.moveTo(w * .56, h * .10)
                        ctx.lineTo(w * .36, h * .56)
                        ctx.lineTo(w * .50, h * .56)
                        ctx.lineTo(w * .44, h * .92)
                        ctx.lineTo(w * .68, h * .42)
                        ctx.lineTo(w * .53, h * .42)
                        ctx.closePath()
                        ctx.lineWidth = 1.6
                        ctx.lineJoin = "round"
                        ctx.strokeStyle = Theme.bg
                        ctx.fillStyle = Theme.fg
                        ctx.stroke()
                        ctx.fill()
                    }
                }
            }
            Rectangle {   // terminal nub
                x: body.width + 1; y: root.bh * 0.3
                width: 3; height: root.bh * 0.4; radius: 1.5
                color: root.tint
                Behavior on color { ColorAnimation { duration: Theme.dur(300) } }
            }
        }
        Text {
            text: area.containsMouse && Power.timeText !== "" ? Power.timeText : Math.round(root.pct * 100) + "%"
            color: Theme.dim
            font { family: Theme.font; pixelSize: Theme.fs(10) }
        }
    }

    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true }   // hover: time remaining
}
