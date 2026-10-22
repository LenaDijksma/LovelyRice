import QtQuick

// Quick settings: mic and do-not-disturb switches, output volume, audio devices (click to switch) and the power profile.
// The same things /control offers in the palette, as a card for the dropdown panel.
Item {
    id: root
    implicitWidth: 300
    implicitHeight: col.implicitHeight + 32

    onVisibleChanged: if (visible) Control.refresh()

    // next device in the list after the current default
    function cycle(list, isDefault, apply) {
        if (list.length < 2) return
        let i = -1
        for (let k = 0; k < list.length; k++) if (isDefault(list[k])) { i = k; break }
        apply(list[(i + 1) % list.length])
    }

    Column {
        id: col
        x: 16; y: 16
        width: root.width - 32
        spacing: 12

        Text {
            text: "quick settings"
            color: Theme.fg
            font { family: Theme.font; pixelSize: 12; bold: true }
        }

        // ---- switches ----
        Row {
            spacing: 8
            Repeater {
                model: [
                    { id: "mic", label: Control.micMuted ? "mic off" : "mic on", on: !Control.micMuted, avail: Control.micAvailable },
                    { id: "dnd", label: Notifs.dnd ? "dnd on" : "dnd off", on: Notifs.dnd, avail: true }
                ]
                delegate: Rectangle {
                    id: sw
                    required property var modelData
                    width: (col.width - 8) / 2; height: 38
                    radius: Theme.radiusSmall
                    opacity: modelData.avail ? 1 : 0.4
                    color: modelData.on ? Qt.alpha(Theme.accent, swArea.containsMouse ? 0.32 : 0.22)
                                        : Qt.alpha(Theme.fg, swArea.containsMouse ? 0.12 : 0.06)
                    border.width: 1
                    border.color: modelData.on ? Theme.accent : Qt.alpha(Theme.dim, 0.35)
                    Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                    Text {
                        anchors.centerIn: parent
                        text: sw.modelData.label
                        color: sw.modelData.on ? Theme.accent : Theme.fg
                        font { family: Theme.font; pixelSize: 12 }
                    }
                    MouseArea {
                        id: swArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: sw.modelData.avail
                        onClicked: sw.modelData.id === "mic" ? Control.toggleMic() : (Notifs.dnd = !Notifs.dnd)
                    }
                }
            }
        }

        // ---- output volume ----
        Item {
            width: parent.width; height: 26
            visible: Control.defaultSink !== null && Control.defaultSink.audio !== null
            readonly property real vol: visible ? Control.defaultSink.audio.volume : 0
            Text {
                id: vl
                anchors.verticalCenter: parent.verticalCenter
                text: "volume"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 11 }
            }
            Text {
                id: vp
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 36
                horizontalAlignment: Text.AlignRight
                text: Math.round(parent.vol * 100) + "%"
                color: Theme.fg
                font { family: Theme.font; pixelSize: 11 }
            }
            Rectangle {
                id: vtrack
                anchors { left: vl.right; right: vp.left; leftMargin: 10; rightMargin: 8; verticalCenter: parent.verticalCenter }
                height: 8; radius: 4
                color: Qt.alpha(Theme.dim, 0.3)
                Rectangle {
                    width: Math.max(parent.height, parent.width * Math.min(1, parent.parent.vol))
                    height: parent.height; radius: 4
                    color: Control.defaultSink && Control.defaultSink.audio && Control.defaultSink.audio.muted ? Theme.dim : Theme.accent
                }
            }
            MouseArea {
                anchors { left: vtrack.left; right: vtrack.right; top: parent.top; bottom: parent.bottom; leftMargin: -6; rightMargin: -6 }
                preventStealing: true
                function setFrom(mx) {
                    const f = Math.max(0, Math.min(1, mapToItem(vtrack, mx, 0).x / vtrack.width))
                    Control.defaultSink.audio.volume = f
                }
                onPressed: mouse => setFrom(mouse.x)
                onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
            }
        }

        // ---- devices ----
        Repeater {
            model: [
                { kind: "output", list: Control.sinks,   cur: Control.defaultSink },
                { kind: "input",  list: Control.sources, cur: Control.defaultSource }
            ]
            delegate: Rectangle {
                id: dev
                required property var modelData
                width: col.width; height: 40
                radius: Theme.radiusSmall
                color: Qt.alpha(Theme.fg, devArea.containsMouse && modelData.list.length > 1 ? 0.10 : 0.05)
                Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                Column {
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 12; rightMargin: 12 }
                    spacing: 1
                    Text {
                        text: dev.modelData.kind + (dev.modelData.list.length > 1 ? "  ·  click to switch" : "")
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 10 }
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: dev.modelData.cur ? Control.label(dev.modelData.cur) : "none"
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: 12 }
                    }
                }
                MouseArea {
                    id: devArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (dev.modelData.kind === "output")
                            root.cycle(Control.sinks, n => Control.isDefaultSink(n), n => Control.setSink(n))
                        else
                            root.cycle(Control.sources, n => Control.isDefaultSource(n), n => Control.setSource(n))
                    }
                }
            }
        }

        // ---- power profile ----
        Column {
            width: parent.width
            spacing: 6
            visible: Control.profiles.length > 0
            Text {
                text: "power profile"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 10 }
            }
            Row {
                spacing: 6
                Repeater {
                    model: Control.profiles
                    delegate: Rectangle {
                        id: pf
                        required property string modelData
                        readonly property bool on: Control.profile === modelData
                        width: (col.width - 6 * (Control.profiles.length - 1)) / Control.profiles.length
                        height: 30; radius: 15
                        color: on ? Qt.alpha(Theme.accent, 0.25) : Qt.alpha(Theme.fg, pfArea.containsMouse ? 0.12 : 0.06)
                        border.width: 1
                        border.color: on ? Theme.accent : Qt.alpha(Theme.dim, 0.35)
                        Behavior on color { ColorAnimation { duration: Theme.dur(120) } }
                        Text {
                            anchors.centerIn: parent
                            text: pf.modelData === "power-saver" ? "saver" : pf.modelData
                            color: pf.on ? Theme.accent : Theme.fg
                            font { family: Theme.font; pixelSize: 11 }
                        }
                        MouseArea { id: pfArea; anchors.fill: parent; hoverEnabled: true; onClicked: Control.setProfile(pf.modelData) }
                    }
                }
            }
        }
    }
}
