import QtQuick

// Control tab of the dropdown: output volume and every audio device as a list, microphone, do-not-disturb and power profile.
// Two columns when wide. Flat rows with switches and radio lists — not the look of the other popouts.
Item {
    id: root
    readonly property bool wide: width >= 520
    readonly property real gapX: 28
    readonly property real colW: wide ? (width - gapX) / 2 : width
    implicitHeight: grid.implicitHeight

    onVisibleChanged: if (visible) Control.refresh()

    Grid {
        id: grid
        columns: root.wide ? 2 : 1
        columnSpacing: root.gapX
        rowSpacing: 22

        // ---------- audio ----------
        Column {
            width: root.colW
            spacing: 8

            DropHeader { width: parent.width; text: "output" }
            Item {   // volume
                width: parent.width; height: 34
                visible: Control.defaultSink !== null && Control.defaultSink.audio !== null
                readonly property real vol: visible ? Control.defaultSink.audio.volume : 0
                readonly property bool muted: visible && Control.defaultSink.audio.muted
                Text {
                    id: vp
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    text: Math.round(parent.vol * 100) + "%"
                    color: parent.muted ? Theme.dim : Theme.fg
                    font { family: Theme.font; pixelSize: 22; bold: true }
                }
                Rectangle {
                    id: vtrack
                    anchors { left: vp.right; right: parent.right; verticalCenter: parent.verticalCenter }
                    height: 4; radius: 2
                    color: Qt.alpha(Theme.dim, 0.3)
                    Rectangle {
                        width: parent.width * Math.min(1, parent.parent.vol); height: parent.height; radius: 2
                        color: parent.parent.muted ? Theme.dim : Theme.accent
                    }
                    Rectangle {
                        width: 12; height: 12; radius: 3
                        x: parent.width * Math.min(1, parent.parent.vol) - width / 2; anchors.verticalCenter: parent.verticalCenter
                        color: Theme.fg
                    }
                }
                MouseArea {
                    anchors { left: vtrack.left; right: vtrack.right; top: parent.top; bottom: parent.bottom; leftMargin: -6; rightMargin: -6 }
                    preventStealing: true
                    function setFrom(mx) {
                        Control.defaultSink.audio.volume = Math.max(0, Math.min(1, mapToItem(vtrack, mx, 0).x / vtrack.width))
                    }
                    onPressed: mouse => setFrom(mouse.x)
                    onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
                }
            }
            Item {
                width: parent.width; height: 28
                visible: Control.defaultSink !== null && Control.defaultSink.audio !== null
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Mute output"; color: Theme.fg
                       font { family: Theme.font; pixelSize: 12 } }
                DropSwitch {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    on: Control.defaultSink !== null && Control.defaultSink.audio !== null && Control.defaultSink.audio.muted
                    onToggled: Control.defaultSink.audio.muted = !Control.defaultSink.audio.muted
                }
            }
            Repeater {
                model: Control.sinks
                delegate: DropOption {
                    required property var modelData
                    width: root.colW
                    label: Control.label(modelData)
                    selected: Control.isDefaultSink(modelData)
                    onClicked: Control.setSink(modelData)
                }
            }

            Item { width: 1; height: 6 }
            DropHeader { width: parent.width; text: "input" }
            Item {
                width: parent.width; height: 28
                opacity: Control.micAvailable ? 1 : 0.4
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Microphone"; color: Theme.fg
                       font { family: Theme.font; pixelSize: 12 } }
                DropSwitch {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    enabled: Control.micAvailable
                    on: !Control.micMuted
                    onToggled: Control.toggleMic()
                }
            }
            Repeater {
                model: Control.sources
                delegate: DropOption {
                    required property var modelData
                    width: root.colW
                    label: Control.label(modelData)
                    selected: Control.isDefaultSource(modelData)
                    onClicked: Control.setSource(modelData)
                }
            }
        }

        // ---------- system ----------
        Column {
            width: root.colW
            spacing: 8

            DropHeader { width: parent.width; text: "notifications" }
            Item {
                width: parent.width; height: 28
                Text { anchors.verticalCenter: parent.verticalCenter; text: "Do not disturb"; color: Theme.fg
                       font { family: Theme.font; pixelSize: 12 } }
                DropSwitch {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    on: Notifs.dnd
                    onToggled: Notifs.dnd = !Notifs.dnd
                }
            }

            Item { width: 1; height: 6; visible: Control.profiles.length > 0 }
            DropHeader { width: parent.width; text: "power profile"; visible: Control.profiles.length > 0 }
            Repeater {
                model: Control.profiles
                delegate: DropOption {
                    required property string modelData
                    width: root.colW
                    label: modelData === "power-saver" ? "Power saver" : modelData.charAt(0).toUpperCase() + modelData.slice(1)
                    selected: Control.profile === modelData
                    onClicked: Control.setProfile(modelData)
                }
            }
        }
    }
}
