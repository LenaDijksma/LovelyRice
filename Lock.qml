import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam

// Lock screen: Wayland session lock on every monitor, password checked through PAM.
// Lock with /lock, or from hypridle: lock_cmd = qs -c lovelyrice ipc call rice lock
// Also: caps-lock state (kernel LED), optional fingerprint unlock through fprintd (pam/lovelyrice-fp).
// Debug output: qs -c lovelyrice log
Scope {
    id: root
    property bool busy: false
    property string message: ""
    property string pending: ""
    property bool caps: false
    property bool fpActive: false
    property string fpHint: ""
    property int fpFails: 0
    signal failed()

    function lock() {
        if (sessionLock.locked) return
        message = ""; busy = false
        sessionLock.locked = true
    }
    function submit(pw) {
        if (busy || pw === "") return
        busy = true; message = ""; pending = pw
        if (!pam.start()) {
            // start() returned false: don't leave the field stuck on "Checking…"
            console.log("lock: pam.start() failed")
            pending = ""; busy = false
            message = "PAM could not start, check log"
            failed()
        }
    }

    // ---- caps lock: read the keyboard LED while locked ----
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*capslock/brightness 2>/dev/null | grep -q 1 && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.caps = text.trim() === "1" }
    }
    Timer {
        interval: 400; repeat: true; running: sessionLock.locked
        onTriggered: if (!capsProc.running) capsProc.running = true
    }

    // ---- fingerprint ----
    function startFp() {
        if (!Settings.lockFingerprint || !sessionLock.locked) return
        fpFails = 0; fpActive = true; fpHint = "Touch the fingerprint reader, or type your password"
        pamFp.start()
    }
    function stopFp() { fpActive = false; fpHint = ""; pamFp.abort() }
    Connections {
        target: sessionLock
        function onLockedChanged() { if (sessionLock.locked) root.startFp(); else root.stopFp() }
    }
    Timer { id: fpRetry; interval: 900; onTriggered: if (sessionLock.locked && root.fpActive) pamFp.start() }
    PamContext {
        id: pamFp
        config: "lovelyrice-fp"
        configDirectory: Quickshell.shellPath("pam")
        onPamMessage: if (pamFp.message !== "") root.fpHint = pamFp.message
        onCompleted: result => {
            console.log("lock: fingerprint result =", result)
            if (result === PamResult.Success) { root.message = ""; sessionLock.locked = false; return }
            root.fpFails++
            if (result === PamResult.Error || result === PamResult.MaxTries || root.fpFails >= 5) {
                root.fpActive = false; root.fpHint = ""          // no reader / no enrolled finger / too many tries
                if (result === PamResult.MaxTries) root.message = "Fingerprint locked, use your password"
                return
            }
            root.message = "Fingerprint not recognised"
            fpRetry.restart()
        }
        onError: error => { console.log("lock: fingerprint error =", error); root.fpActive = false; root.fpHint = "" }
    }

    PamContext {
        id: pam
        config: "lovelyrice"
        configDirectory: Quickshell.shellPath("pam")

        onPamMessage: {
            console.log("lock: PAM message:", pam.message, "| responseRequired:", pam.responseRequired)
            if (responseRequired) respond(root.pending)
        }
        onCompleted: result => {
            console.log("lock: PAM result =", result)
            root.pending = ""
            root.busy = false
            if (result === PamResult.Success) {
                sessionLock.locked = false
                root.message = ""
            } else {
                // Distinguish a broken PAM setup / faillock from a genuine wrong password
                root.message = result === PamResult.MaxTries ? "Too many attempts"
                             : result === PamResult.Error    ? "PAM error, check log"
                             : "Wrong password"
                root.failed()
            }
        }
        onError: error => {
            console.log("lock: PAM error =", error)
            root.pending = ""
            root.busy = false
            root.message = "Authentication error, check log"
            root.failed()
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: false
        WlSessionLockSurface {
            id: surface
            color: Theme.bg
            LockSurface { anchors.fill: parent; lock: root; screen: surface.screen }
        }
    }
}
