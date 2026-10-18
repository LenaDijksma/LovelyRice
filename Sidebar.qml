import QtQuick
import Quickshell

// One sidebar per monitor. A separate window exists for each side so switching sides in /settings
// never has to re-anchor a live window; only the matching one is visible.
Scope {
    id: root
    required property var modelData
    signal launcherRequested()
    signal calendarRequested()
    signal networkRequested()
    signal bluetoothRequested()
    signal notificationsRequested()

    SidebarWindow {
        side: "left"; modelData: root.modelData
        onLauncherRequested: root.launcherRequested()
        onCalendarRequested: root.calendarRequested()
        onNetworkRequested: root.networkRequested()
        onBluetoothRequested: root.bluetoothRequested()
        onNotificationsRequested: root.notificationsRequested()
    }
    SidebarWindow {
        side: "right"; modelData: root.modelData
        onLauncherRequested: root.launcherRequested()
        onCalendarRequested: root.calendarRequested()
        onNetworkRequested: root.networkRequested()
        onBluetoothRequested: root.bluetoothRequested()
        onNotificationsRequested: root.notificationsRequested()
    }
}
