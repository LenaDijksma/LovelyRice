pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording with wf-recorder (and slurp for regions). Videos go to ~/Videos/Recordings.
Singleton {
    id: root
    readonly property bool active: proc.running
    property int elapsed: 0
    property string file: ""

    function start(region) {
        if (proc.running) return
        file = Quickshell.env("HOME") + "/Videos/Recordings/" + Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss") + ".mp4"
        elapsed = 0
        proc.command = ["sh", "-c",
            'mkdir -p "$(dirname "$1")"; sleep 0.4; ' +
            'if [ "$2" = region ]; then g=$(slurp) || exit 0; exec wf-recorder -g "$g" -f "$1"; ' +
            'else exec wf-recorder -f "$1"; fi', "sh", file, region ? "region" : "screen"]
        proc.running = true
    }
    function stop() { if (proc.running) proc.signal(2) }   // SIGINT lets wf-recorder finish the file

    Process {
        id: proc
        onExited: code => {
            if (root.elapsed >= 1)
                Quickshell.execDetached(["notify-send", "-a", "Recorder", "Recording saved", root.file])
            else if (code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "Recorder", "Recording failed",
                                         "Is wf-recorder installed? (sudo pacman -S wf-recorder slurp)"])
        }
    }
    Timer { interval: 1000; repeat: true; running: proc.running; onTriggered: root.elapsed++ }
}
