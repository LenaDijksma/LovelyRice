import QtQuick
import Quickshell

// The utility bars of one monitor. A separate window exists for every (bar, edge) pair so changing a position in /settings
// never has to re-anchor a live window; only the windows that are wanted are visible. Bar 1 is the main bar; bar 2 only
// exists while the split is on (/settings -> Style -> Split bar).
Scope {
    id: root
    required property var modelData     // the screen
    signal launcherRequested()
    signal calendarRequested()
    signal networkRequested()
    signal bluetoothRequested()
    signal notificationsRequested()

    Variants {
        model: {
            const out = []
            for (const index of [1, 2])
                for (const position of ["left", "right", "top", "bottom"]) out.push({ index: index, position: position })
            return out
        }
        UtilityBarWindow {
            required property var modelData
            targetScreen: root.modelData
            barIndex: modelData.index
            position: modelData.position
            onLauncherRequested: root.launcherRequested()
            onCalendarRequested: root.calendarRequested()
            onNetworkRequested: root.networkRequested()
            onBluetoothRequested: root.bluetoothRequested()
            onNotificationsRequested: root.notificationsRequested()
        }
    }
}
