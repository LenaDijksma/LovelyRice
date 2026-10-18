pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Backend for /control: audio output/input devices, microphone mute, power profile.
// (Do-not-disturb lives in Notifs.) Power profiles use powerprofilesctl (power-profiles-daemon).
Singleton {
    id: root

    // ---- audio devices ----
    // Every node has to be tracked before its `audio` part is usable.
    PwObjectTracker { objects: Pipewire.nodes.values }

    function nodeList() {
        const v = Pipewire.nodes.values, out = []
        for (let i = 0; i < v.length; i++) out.push(v[i])
        return out
    }
    readonly property var sinks:   nodeList().filter(n => n.audio && !n.isStream && n.isSink)
    readonly property var sources: nodeList().filter(n => n.audio && !n.isStream && !n.isSink)
    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    function label(n) { return n.description || n.nickname || n.name || "Unknown device" }
    function isDefaultSink(n)   { return defaultSink !== null && defaultSink.id === n.id }
    function isDefaultSource(n) { return defaultSource !== null && defaultSource.id === n.id }
    // wpctl ships with WirePlumber and works on every Quickshell version
    function setSink(n)   { Quickshell.execDetached(["wpctl", "set-default", String(n.id)]) }
    function setSource(n) { Quickshell.execDetached(["wpctl", "set-default", String(n.id)]) }

    // ---- microphone ----
    readonly property bool micAvailable: defaultSource !== null && defaultSource.audio !== null
    readonly property bool micMuted: micAvailable && defaultSource.audio.muted
    function toggleMic() { if (micAvailable) defaultSource.audio.muted = !defaultSource.audio.muted }

    // ---- power profile ----
    property var profiles: []            // available ones, in the order power-saver, balanced, performance
    property string profile: ""
    readonly property var profileOrder: ["power-saver", "balanced", "performance"]

    function refresh() { profList.running = true }
    function setProfile(name) {
        if (profiles.indexOf(name) < 0) return
        profile = name
        profSet.command = ["powerprofilesctl", "set", name]
        profSet.running = true
    }
    function cycleProfile() {
        if (profiles.length === 0) return
        setProfile(profiles[(profiles.indexOf(profile) + 1) % profiles.length])
    }

    Process {
        id: profList
        command: ["powerprofilesctl", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = []
                let cur = ""
                for (const line of text.split("\n")) {
                    const m = line.match(/^\s*(\*)?\s*([a-z-]+):\s*$/)
                    if (!m) continue
                    found.push(m[2])
                    if (m[1]) cur = m[2]
                }
                root.profiles = root.profileOrder.filter(p => found.indexOf(p) >= 0)
                root.profile = cur
            }
        }
    }
    Process { id: profSet; onExited: root.refresh() }
    Component.onCompleted: refresh()
}
