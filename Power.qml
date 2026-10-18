pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery helpers: time remaining (shown when you hover the battery icon) and low-battery warnings.
// Warnings are sent with notify-send, so they arrive as normal LovelyRice notifications; the last one is critical.
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice
    readonly property bool present: dev !== null && dev.isLaptopBattery
    readonly property real pct: present ? dev.percentage : 0      // 0..1
    readonly property bool charging: present && dev.state === UPowerDeviceState.Charging
    readonly property bool discharging: present && dev.state === UPowerDeviceState.Discharging
    readonly property real seconds: !present ? 0 : (charging ? dev.timeToFull : (discharging ? dev.timeToEmpty : 0))
    readonly property string timeText: seconds >= 60 ? fmt(seconds) : ""

    function fmt(s) {
        const m = Math.round(s / 60)
        if (m < 60) return m + "m"
        const r = m % 60
        return Math.floor(m / 60) + "h" + (r < 10 ? "0" : "") + r
    }

    property bool warned: false
    property bool warnedCritical: false
    readonly property int low: Settings.batteryLow
    readonly property int critical: Math.max(3, Math.floor(Settings.batteryLow / 2))

    function start() { check() }
    function check() {
        if (!present) return
        const p = Math.round(pct * 100)
        if (!discharging || p > low + 3) { warned = false; warnedCritical = false; return }   // reset once charging / recovered
        if (!Settings.batteryWarning) return
        if (p <= critical && !warnedCritical) {
            warned = true; warnedCritical = true
            warn(true, p)
        } else if (p <= low && !warned) {
            warned = true
            warn(false, p)
        }
    }
    function warn(isCritical, p) {
        Quickshell.execDetached(["notify-send", "-a", "Battery", "-u", isCritical ? "critical" : "normal",
            "-i", "battery-caution", isCritical ? "Battery critically low" : "Battery low",
            p + "% remaining" + (timeText !== "" ? "  ·  about " + timeText + " left" : "") + "  ·  plug in the charger"])
    }

    onPctChanged: check()
    onDischargingChanged: check()
    onPresentChanged: check()
}
