pragma Singleton
import QtQuick
import Quickshell

// Lock and sleep requests from anywhere (palette, idle timers, ...).
Singleton {
    id: root
    signal lockRequested()

    function lock() { lockRequested() }
    function suspendNow() { Quickshell.execDetached(["systemctl", "suspend"]) }
    // Locks first (setting) so the screen is already locked when the machine wakes up.
    function sleep() {
        if (Settings.lockOnSleep) { lockRequested(); sleepTimer.restart() }
        else suspendNow()
    }
    Timer { id: sleepTimer; interval: 1200; onTriggered: root.suspendNow() }
}
