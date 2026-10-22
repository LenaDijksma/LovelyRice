import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// One monitor's lock screen: wallpaper, big clock, and a password card.
Item {
    id: root
    required property var lock
    property var screen: null
    property real appear: 0
    property real shakeX: 0

    Component.onCompleted: { appear = 1; input.forceActiveFocus() }
    Behavior on appear { NumberAnimation { duration: Theme.dur(700); easing.type: Easing.OutCubic } }

    // ---- background ----
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.bg }
            GradientStop { position: 1.0; color: Theme.surface }
        }
        Rectangle {
            width: parent.width * 0.7; height: width; radius: width / 2
            x: parent.width * 0.55; y: -height * 0.35
            color: Qt.alpha(Theme.accent, 0.12)
        }
        Rectangle {
            width: parent.width * 0.6; height: width; radius: width / 2
            x: -width * 0.3; y: parent.height * 0.6
            color: Qt.alpha(Theme.accent2, 0.10)
        }
    }
    Image {
        anchors.fill: parent
        source: Theme.wallpaper !== "" && Theme.wallpaperKind(Theme.wallpaper) !== "video" ? "file://" + Theme.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.width, root.height)
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.dur(600) } }
    }
    // blurred screenshot of what was on screen (captured as the lock starts); the wallpaper shows until it arrives
    Loader {
        anchors.fill: parent
        active: Settings.lockBlur && root.screen !== null
        sourceComponent: ScreencopyView {
            captureSource: root.screen
            live: false
            opacity: hasContent ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.dur(500) } }
            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1.0
                blurMax: 48
                saturation: 0.1
            }
        }
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.5 * root.appear) }

    // ---- battery (top right) ----
    Text {
        visible: Power.present
        anchors { top: parent.top; right: parent.right; topMargin: 28; rightMargin: 36 }
        opacity: root.appear
        text: Math.round(Power.pct * 100) + "%" + (Power.charging ? "  charging" : "")
                + (Power.timeText !== "" ? "  ·  " + Power.timeText : "")
        color: !Power.charging && Power.pct <= 0.15 ? Theme.warn : Theme.dim
        font { family: Theme.font; pixelSize: 15 }
    }

    // ---- media controls (bottom) ----
    Rectangle {
        id: media
        visible: Music.player !== null
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
        width: 420; height: 56; radius: height / 2
        color: Qt.alpha(Theme.bg, 0.8)
        border.color: Qt.alpha(Theme.accent, 0.35); border.width: 1
        opacity: root.appear
        Column {
            anchors { left: parent.left; leftMargin: 24; right: controls.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            Text {
                width: parent.width
                text: Music.title !== "" ? Music.title : "Nothing playing"
                color: Theme.fg; elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 13; bold: true }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: Music.artist
                color: Theme.dim; elide: Text.ElideRight
                font { family: Theme.font; pixelSize: 11 }
            }
        }
        Row {
            id: controls
            anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
            Repeater {
                model: ["prev", "toggle", "next"]
                delegate: Rectangle {
                    id: mbtn
                    required property string modelData
                    width: 38; height: 34; radius: 17
                    color: mArea.containsMouse ? Theme.surface : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: mbtn.modelData === "prev" ? "«" : (mbtn.modelData === "next" ? "»" : (Music.playing ? "❚❚" : "▶"))
                        color: mbtn.modelData === "toggle" ? Theme.accent : Theme.fg
                        font { family: Theme.font; pixelSize: mbtn.modelData === "toggle" ? 14 : 18 }
                    }
                    MouseArea {
                        id: mArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (mbtn.modelData === "prev") Music.prev()
                            else if (mbtn.modelData === "next") Music.next()
                            else Music.toggle()
                            input.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // ---- clock ----
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Column {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: card.top; bottomMargin: 40 }
        opacity: root.appear
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.fg
            font { family: Theme.font; pixelSize: 120; bold: true }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd d MMMM")
            color: Theme.accent
            font { family: Theme.font; pixelSize: 20 }
        }
    }

    // ---- password card ----
    Card {
        id: card
        width: 380; height: 250
        x: (parent.width - width) / 2 + root.shakeX
        y: parent.height * 0.52 + (1 - root.appear) * 30
        opacity: root.appear
        radius: Theme.radius + 4
        color: Qt.alpha(Theme.bg, 0.92)
        borderColor: Qt.alpha(Theme.accent, 0.7)
        borderWidth: 2
        shadowY: 16

        Rectangle {   // avatar
            id: avatar
            width: 64; height: 64; radius: 32
            anchors { top: parent.top; topMargin: 26; horizontalCenter: parent.horizontalCenter }
            color: Qt.alpha(Theme.accent, 0.2)
            border.color: Theme.accent
            border.width: 2
            Text {
                anchors.centerIn: parent
                text: (Quickshell.env("USER") || "?")[0].toUpperCase()
                color: Theme.accent
                font { family: Theme.font; pixelSize: 28; bold: true }
            }
        }
        Text {
            anchors { top: avatar.bottom; topMargin: 10; horizontalCenter: parent.horizontalCenter }
            text: Quickshell.env("USER")
            color: Theme.fg
            font { family: Theme.font; pixelSize: 15; bold: true }
        }

        Rectangle {   // password field
            id: field
            anchors { left: parent.left; right: parent.right; leftMargin: 30; rightMargin: 30; bottom: parent.bottom; bottomMargin: 56 }
            height: 46
            radius: Theme.radiusSmall + 4
            color: Theme.surface
            border.width: 2
            border.color: root.lock.message !== "" ? Theme.warn : Qt.alpha(Theme.accent, input.activeFocus ? 0.9 : 0.4)
            Behavior on border.color { ColorAnimation { duration: Theme.dur(200) } }
            SequentialAnimation on opacity {
                running: root.lock.busy && Theme.animScale > 0
                loops: Animation.Infinite
                NumberAnimation { to: 0.5; duration: Theme.dur(450) }
                NumberAnimation { to: 1.0; duration: Theme.dur(450) }
            }

            Text {
                visible: input.text === ""
                anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                text: root.lock.busy ? "Checking…" : "Password"
                color: Theme.dim
                font { family: Theme.font; pixelSize: 15 }
            }
            TextInput {
                id: input
                anchors { fill: parent; leftMargin: 16; rightMargin: root.lock.caps ? 68 : 16 }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhHiddenText
                enabled: !root.lock.busy
                color: Theme.fg
                selectionColor: Theme.accent
                font { family: Theme.font; pixelSize: 18 }
                onAccepted: root.lock.submit(text)
                Keys.onEscapePressed: text = ""
            }
        }
        Rectangle {   // caps lock badge
            visible: root.lock.caps
            anchors { right: field.right; rightMargin: 10; verticalCenter: field.verticalCenter }
            width: capsText.implicitWidth + 14; height: 22; radius: 11
            color: Qt.alpha(Theme.warn, 0.2)
            border.color: Theme.warn; border.width: 1
            Text {
                id: capsText
                anchors.centerIn: parent
                text: "CAPS"
                color: Theme.warn
                font { family: Theme.font; pixelSize: 10; bold: true }
            }
        }
        Text {
            anchors { top: field.bottom; topMargin: 10; horizontalCenter: parent.horizontalCenter }
            width: parent.width - 40
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.lock.message !== "" ? root.lock.message : (root.lock.fpActive ? root.lock.fpHint : "")
            color: root.lock.message !== "" ? Theme.warn : Theme.dim
            font { family: Theme.font; pixelSize: 12 }
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "shakeX"; to: -18; duration: Theme.dur(60) }
        NumberAnimation { target: root; property: "shakeX"; to: 18;  duration: Theme.dur(90) }
        NumberAnimation { target: root; property: "shakeX"; to: -12; duration: Theme.dur(80) }
        NumberAnimation { target: root; property: "shakeX"; to: 8;   duration: Theme.dur(70) }
        NumberAnimation { target: root; property: "shakeX"; to: 0;   duration: Theme.dur(60) }
    }
    Connections {
        target: root.lock
        function onFailed() { input.text = ""; shake.restart(); input.forceActiveFocus() }
    }
}
