import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Overview (SUPER + TAB): every workspace that has windows (plus the current one) as a tile with live previews of its
// windows. Click a window to focus it, click a tile to switch to that workspace.
// ←/→/↑/↓ or Tab pick a workspace · Enter go · 1-9 go to that workspace · Esc close.
// Shows up to 9 workspaces. Previews use Hyprland's window capture; a window that can't be captured shows its title instead.
PanelWindow {
    id: win

    property bool open: false
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }

    property var tiles: []
    property int sel: 0
    property real monW: 1920
    property real monH: 1080
    readonly property int cols: Math.max(1, Math.min(tiles.length, 3))
    readonly property int rows: Math.max(1, Math.ceil(tiles.length / 3))
    readonly property real tileW: {
        const byW = (monW - 240 - (cols - 1) * 28) / cols
        const byH = ((monH - 200 - (rows - 1) * 28) / rows) * monW / monH
        return Math.floor(Math.min(520, byW, byH))
    }
    readonly property real tileH: tileW * monH / monW
    readonly property real s: tileW / monW

    onOpenChanged: Popups.report("overview", open)
    Connections {
        target: Popups
        function onCloseOthers(except) { if (except !== "overview" && win.open) win.hide() }
        function onCloseAll() { if (win.open) win.hide() }
    }

    function show() {
        Popups.claim("overview")
        Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels(); Hyprland.refreshMonitors()
        rebuild()
        console.log("LovelyRice: overview open,", tiles.length, "workspaces")
        open = true
        keys.forceActiveFocus()
        refresh.restart()
    }
    function hide() { open = false }
    function toggle() { open ? hide() : show() }
    Timer { id: refresh; interval: 250; onTriggered: if (win.open) win.rebuild() }

    function rebuild() {
        const mon = Hyprland.focusedMonitor
        const mo = mon && mon.lastIpcObject ? mon.lastIpcObject : {}
        const sc = mo.scale || 1
        const mx = mo.x || 0, my = mo.y || 0
        monW = (mo.width || 1920) / sc
        monH = (mo.height || 1080) / sc
        const byWs = {}
        const tl = Hyprland.toplevels.values
        for (let i = 0; i < tl.length; i++) {
            const t = tl[i]
            const ipc = t.lastIpcObject || {}
            const wsid = ipc.workspace ? ipc.workspace.id : undefined
            if (wsid === undefined || wsid <= 0) continue
            if (mon && ipc.monitor !== undefined && ipc.monitor !== mon.id) continue
            const at = ipc.at || [0, 0], size = ipc.size || [0, 0]
            if (!(size[0] > 0)) continue
            let addr = String(t.address || "")
            if (addr === "") continue
            if (addr.indexOf("0x") !== 0) addr = "0x" + addr
            ;(byWs[wsid] = byWs[wsid] || []).push({ address: addr, title: t.title || ipc.title || "", cls: ipc.class || "",
                                                    x: at[0] - mx, y: at[1] - my, w: size[0], h: size[1], handle: t.wayland })
        }
        const active = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
        let ids = Object.keys(byWs).map(Number)
        if (active > 0 && ids.indexOf(active) < 0) ids.push(active)
        ids.sort((a, b) => a - b)
        if (ids.length > 9) ids = ids.filter(id => id === active).concat(ids.filter(id => id !== active)).slice(0, 9).sort((a, b) => a - b)
        tiles = ids.map(id => ({ id: id, active: id === active, wins: byWs[id] || [] }))
        sel = Math.max(0, ids.indexOf(active))
    }

    // Closing gives the keyboard focus back, and Hyprland answers by refocusing the window it knew before, which
    // would pull you back to the old workspace. So close first and switch a moment later.
    property string pendingFocus: ""
    Timer {
        id: goTimer
        interval: 150
        onTriggered: { Quickshell.execDetached(["hyprctl", "dispatch", win.pendingFocus]); win.pendingFocus = "" }
    }
    function goWorkspace(id) {
        pendingFocus = 'hl.dsp.focus({ workspace = "' + id + '" })'
        hide(); goTimer.restart()
    }
    function goWindow(address) {
        Popups.exempt()
        pendingFocus = 'hl.dsp.focus({ window = "address:' + address + '" })'
        hide(); goTimer.restart()
    }
    function move(d) { if (tiles.length > 0) sel = (sel + d + tiles.length) % tiles.length }

    screen: {
        const m = Hyprland.focusedMonitor
        for (const sc of Quickshell.screens) if (m && sc.name === m.name) return sc
        return Quickshell.screens[0]
    }
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: progress > 0.001
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "lovelyrice-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.62 * win.progress) }
    MouseArea { anchors.fill: parent; onClicked: win.hide() }

    FocusScope {
        id: keys
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) win.hide()
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab) win.move(1)
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab) win.move(-1)
            else if (event.key === Qt.Key_Down) win.move(win.cols)
            else if (event.key === Qt.Key_Up) win.move(-win.cols)
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (win.tiles[win.sel]) win.goWorkspace(win.tiles[win.sel].id) }
            else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) win.goWorkspace(event.key - Qt.Key_0)
            else return
            event.accepted = true
        }

        Text {
            visible: win.tiles.length === 0
            anchors.centerIn: parent
            text: "No windows open"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 18 }
        }

        Grid {
            anchors.centerIn: parent
            columns: win.cols
            spacing: 28
            opacity: win.progress
            scale: 0.94 + 0.06 * win.progress
            Repeater {
                model: win.tiles
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    width: win.tileW; height: win.tileH
                    radius: Theme.radius
                    color: Qt.alpha(Theme.bg, 0.88)
                    clip: true
                    border.width: win.sel === index ? 3 : (modelData.active ? 2 : 1)
                    border.color: win.sel === index ? Theme.accent : (modelData.active ? Qt.alpha(Theme.accent, 0.5) : Qt.alpha(Theme.dim, 0.4))

                    Text {
                        anchors.centerIn: parent
                        text: tile.modelData.id
                        color: Qt.alpha(Theme.dim, 0.25)
                        font { family: Theme.font; pixelSize: Math.round(win.tileH * 0.5); bold: true }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: win.sel = tile.index
                        onClicked: win.goWorkspace(tile.modelData.id)
                    }
                    Repeater {
                        model: tile.modelData.wins
                        delegate: Rectangle {
                            id: w
                            required property var modelData
                            x: modelData.x * win.s; y: modelData.y * win.s
                            width: Math.max(8, modelData.w * win.s); height: Math.max(8, modelData.h * win.s)
                            color: Theme.surface
                            radius: 4
                            clip: true
                            border.width: wArea.containsMouse ? 2 : 1
                            border.color: wArea.containsMouse ? Theme.accent : Qt.alpha(Theme.dim, 0.5)
                            Loader {
                                anchors.fill: parent
                                active: win.visible && w.modelData.handle !== null && w.modelData.handle !== undefined
                                sourceComponent: ScreencopyView {
                                    captureSource: w.modelData.handle
                                    live: true
                                }
                            }
                            Text {   // title, shown over the preview on hover and instead of it when there is none
                                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 4 }
                                elide: Text.ElideRight
                                text: w.modelData.title !== "" ? w.modelData.title : w.modelData.cls
                                color: Theme.fg
                                visible: wArea.containsMouse || !w.modelData.handle
                                font { family: Theme.font; pixelSize: 11 }
                            }
                            MouseArea {
                                id: wArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: win.goWindow(w.modelData.address)
                            }
                        }
                    }
                }
            }
        }
    }
}
