import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Notification popups: stacked cards in the top-right corner of the focused monitor.
// Hover pauses the timer · click runs the default action · right-click or ✕ dismisses.
// Critical notifications stay until dismissed. Server and history live in Notifs.qml.
PanelWindow {
    id: win
    readonly property int cardWidth: 360

    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    anchors { top: true; right: true }
    // keep clear of the bar(s) when one is on the right or along the top
    margins.right: Bar.insetOn("right")
    margins.top: Bar.insetOn("top")
    implicitWidth: cardWidth + Theme.gap + Theme.shadowPad
    implicitHeight: col.height + Theme.gap + Theme.shadowPad
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: Notifs.popups.values.length > 0
    mask: Region { item: col }
    WlrLayershell.namespace: "lovelyrice-notifications"
    WlrLayershell.layer: WlrLayer.Overlay

    Column {
        id: col
        x: parent.width - win.cardWidth - Theme.gap
        y: Theme.gap
        width: win.cardWidth
        spacing: 10

        Repeater {
            model: Notifs.popups
            delegate: Card {
                id: toast
                required property var modelData      // the Notification

                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property var buttons: {     // action buttons (the "default" action is the card click)
                    const out = []
                    const l = modelData.actions
                    for (let i = 0; i < l.length; i++)
                        if (l[i].identifier !== "default" && out.length < 3) out.push(l[i])
                    return out
                }
                readonly property real seconds: {    // 0 = stays until dismissed
                    let t = modelData.expireTimeout
                    if (t > 60) t = t / 1000         // tolerate milliseconds
                    if (t > 0) return t
                    return critical ? 0 : 6
                }

                property bool appeared: false
                property bool leaving: false
                property real shown: appeared && !leaving ? 1 : 0
                Behavior on shown { NumberAnimation { duration: Theme.dur(240); easing.type: Easing.OutCubic } }
                Component.onCompleted: appeared = true

                function close(dismissed) {
                    leaving = true
                    finish.dismissed = dismissed
                    finish.restart()
                }
                function activate() {
                    close(true)                      // before invoking: the server may close us at once
                    const l = modelData.actions
                    for (let i = 0; i < l.length; i++)
                        if (l[i].identifier === "default") { l[i].invoke(); break }
                }

                width: win.cardWidth
                height: Math.max(70, texts.height + 28)
                opacity: shown
                transform: Translate { x: (1 - toast.shown) * 60 }
                color: Qt.alpha(Theme.bg, 0.97)
                borderColor: critical ? Qt.alpha(Theme.warn, 0.9) : Qt.alpha(Theme.accent, 0.45)
                borderWidth: critical ? 2 : 1
                shadowY: 6

                Timer {
                    interval: toast.seconds * 1000
                    running: toast.seconds > 0 && !hover.hovered && !toast.leaving
                    onTriggered: toast.close(false)
                }
                Timer {
                    id: finish
                    property bool dismissed: false
                    interval: 260
                    onTriggered: dismissed ? toast.modelData.dismiss() : toast.modelData.expire()
                }
                HoverHandler { id: hover }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => mouse.button === Qt.RightButton ? toast.close(true) : toast.activate()
                }

                NotifIcon {
                    x: 14; y: 14; width: 40; height: 40
                    image: toast.modelData.image
                    icon: toast.modelData.appIcon
                    app: toast.modelData.appName
                    tint: toast.critical ? Theme.warn : Theme.accent
                }

                Column {
                    id: texts
                    x: 66; y: 14
                    width: parent.width - 66 - 34
                    spacing: 3

                    Text {
                        width: parent.width - (hover.hovered ? 44 : 0)
                        visible: text !== ""
                        text: toast.modelData.appName
                        color: Theme.dim
                        elide: Text.ElideRight
                        font { family: Theme.font; pixelSize: 11 }
                    }
                    Text {
                        width: parent.width
                        text: toast.modelData.summary
                        color: Theme.fg
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font { family: Theme.font; pixelSize: 14; bold: true }
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: toast.modelData.body
                        textFormat: Text.StyledText
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        color: Qt.alpha(Theme.fg, 0.8)
                        font { family: Theme.font; pixelSize: 12 }
                    }
                    Row {
                        visible: toast.buttons.length > 0
                        topPadding: 6
                        spacing: 6
                        Repeater {
                            model: toast.buttons
                            delegate: NotifButton {
                                required property var modelData
                                label: modelData.text
                                onClicked: { toast.close(true); modelData.invoke() }   // invoke last: it can destroy the card
                            }
                        }
                    }
                }

                Text {   // mute everything from this app (critical notifications still show)
                    anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 40 }
                    visible: hover.hovered && toast.modelData.appName !== ""
                    text: "mute"
                    color: muteArea.containsMouse ? Theme.fg : Theme.dim
                    font { family: Theme.font; pixelSize: 11 }
                    MouseArea {
                        id: muteArea
                        anchors { fill: parent; margins: -6 }
                        hoverEnabled: true
                        onClicked: { Notifs.mute(toast.modelData.appName); toast.close(true) }
                    }
                }
                Text {
                    anchors { top: parent.top; right: parent.right; topMargin: 10; rightMargin: 14 }
                    visible: hover.hovered
                    text: "✕"
                    color: closeArea.containsMouse ? Theme.fg : Theme.dim
                    font { family: Theme.font; pixelSize: 12 }
                    MouseArea {
                        id: closeArea
                        anchors { fill: parent; margins: -8 }
                        hoverEnabled: true
                        onClicked: toast.close(true)
                    }
                }
            }
        }
    }
}
