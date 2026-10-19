import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Floating rounded sidebar with a drop shadow. Slides in on startup.
// Size, side, gap and which widgets appear are controlled from /settings.
// Only the card itself takes input; the transparent shadow margin is click-through.
PanelWindow {
    id: win
    required property var modelData
    required property string side         // "left" | "right" — one window per side, only one is visible
    screen: modelData
    property bool shown: false
    signal launcherRequested()
    signal calendarRequested()
    signal networkRequested()
    signal bluetoothRequested()
    signal notificationsRequested()

    visible: Settings.side === side
    anchors { top: true; bottom: true; left: side === "left"; right: side === "right" }
    implicitWidth: Theme.gap + Theme.barWidth + Theme.shadowPad
    exclusiveZone: Theme.barWidth + Theme.gap * 2
    color: "transparent"
    mask: Region { item: bar }
    WlrLayershell.namespace: "lovelyrice-sidebar"

    // slide in whenever this window becomes visible
    Timer { id: showTimer; interval: 80; running: true; onTriggered: win.shown = true }
    onVisibleChanged: { shown = false; if (visible) showTimer.restart() }

    Card {
        id: bar
        width: Theme.barWidth
        color: Qt.alpha(Theme.bg, Theme.opacity)
        shadowX: win.side === "left" ? 4 : -4
        shadowY: 6
        anchors { top: parent.top; bottom: parent.bottom; topMargin: Theme.gap; bottomMargin: Theme.gap }
        readonly property real hiddenOffset: -(Theme.barWidth + 40)
        x: win.side === "left" ? (win.shown ? Theme.gap : hiddenOffset)
                               : parent.width - width - (win.shown ? Theme.gap : hiddenOffset)
        Behavior on x { NumberAnimation { duration: Theme.dur(700); easing.type: Easing.OutBack; easing.overshoot: 1.15 } }

        ColumnLayout {
            anchors { fill: parent; topMargin: 10; bottomMargin: 10; leftMargin: Theme.sideMargin; rightMargin: Theme.sideMargin }
            spacing: 8

            // The modules, in the order chosen in /settings -> Sidebar. A module that is switched off (or has nothing
            // to show) is not loaded at all, so it leaves no gap.
            Repeater {
                model: Settings.sidebarOrder
                delegate: Loader {
                    id: slot
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: modelData === "spacer"
                    active: win.wanted(modelData)
                    visible: active
                    sourceComponent: win.parts[modelData]
                }
            }
        }
    }

    // ---- modules ----
    function wanted(id) {
        switch (id) {
        case "logo":       return Settings.showLogo
        case "workspaces": return Settings.showWorkspaces
        case "spacer":     return true
        case "media":      return Settings.showMedia && Music.player !== null
        case "status":     return Settings.showStats || Settings.showAudio || Settings.showBattery
                                  || Settings.showNetwork || Settings.showBluetooth || Settings.showNotifications
        case "brightness": return Brightness.available && Settings.showBrightness
        case "buttons":    return Settings.showButtons
        case "recording":  return Recorder.active
        case "clock":      return Settings.showClock
        }
        return false
    }
    readonly property var parts: ({
        logo: cLogo, workspaces: cWorkspaces, spacer: cSpacer, media: cMedia, status: cStatus,
        brightness: cBrightness, buttons: cButtons, recording: cRecording, clock: cClock
    })

    Component { id: cSpacer; Item {} }
    Component {
        id: cLogo
        Item {
            implicitHeight: logo.implicitHeight
            Logo { id: logo; anchors.horizontalCenter: parent.horizontalCenter }
        }
    }
    Component {
        id: cWorkspaces
        Pill {
            Workspaces { Layout.alignment: Qt.AlignHCenter; monitorName: win.modelData.name }
        }
    }
    Component { id: cMedia; Media {} }
    Component {
        id: cStatus
        Pill {
            SystemStats { Layout.alignment: Qt.AlignHCenter; visible: Settings.showStats }
            Audio       { Layout.alignment: Qt.AlignHCenter }
            Battery     { Layout.alignment: Qt.AlignHCenter }
            NetworkWidget   { Layout.alignment: Qt.AlignHCenter; onClicked: win.networkRequested() }
            BluetoothWidget { Layout.alignment: Qt.AlignHCenter; onClicked: win.bluetoothRequested() }
            NotifWidget     { Layout.alignment: Qt.AlignHCenter; onClicked: win.notificationsRequested() }
        }
    }
    Component {
        id: cBrightness
        Pill {
            BrightnessSlider { Layout.alignment: Qt.AlignHCenter; compact: win.height < 820 }
        }
    }
    Component {
        id: cButtons
        Pill {
            spacing: 2
            SideButton { Layout.alignment: Qt.AlignHCenter; glyph: "⊞"; onClicked: win.launcherRequested() }
            SideButton { Layout.alignment: Qt.AlignHCenter; glyph: "◐"; onClicked: Theme.next() }
        }
    }
    Component { id: cRecording; RecIndicator {} }
    Component {
        id: cClock
        Pill {
            Clock { Layout.alignment: Qt.AlignHCenter; onClicked: win.calendarRequested() }
        }
    }
}
