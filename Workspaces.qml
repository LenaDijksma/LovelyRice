import QtQuick
import Quickshell
import Quickshell.Hyprland

// Normal workspaces: a generic icon for the kind of app inside, with one highlight that slides to the
// active workspace. Special workspaces (scratchpads) follow, icon only, after a thin divider.
// While a special workspace is open the normal highlight fades out.
// Runs down a left/right bar and across a top/bottom bar.
Grid {
    id: root
    property string monitorName: ""
    columns: root.horizontal ? 3 : 1       // normal | divider | special, in one row or one column
    spacing: 0
    readonly property bool horizontal: Bar.horizontalFor(root)
    readonly property int gapY: 3                          // space between workspace cells
    readonly property int step: Theme.cell + gapY

    readonly property string special: Specials.byMonitor[monitorName] || ""
    readonly property var specialGlyphs: ({
        communication: "✉", music: "♪", todo: "✔", special: "✦",
        sysmon: "⚙", magic: "✦", scratchpad: "✦"
    })

    // The data comes from HyprSync (refreshes at startup and after every window / workspace event). The lists only
    // change when their contents do, so the icons are not rebuilt (and their animations replayed) on every refresh.
    Connections {
        target: Hyprland.workspaces
        ignoreUnknownSignals: true
        function onValuesChanged() { root.update() }
    }
    Connections { target: HyprSync; function onRefreshed() { root.update() } }
    Connections { target: Specials; function onByMonitorChanged() { root.update() } }
    Component.onCompleted: { HyprSync.refreshNow(); update() }

    // ---- helpers ----
    // class of the first window; `_rev` only makes bindings re-evaluate after a refresh
    function firstClass(ws, _rev) {
        const t = ws.toplevels.values
        for (let i = 0; i < t.length; i++) {
            const c = t[i].lastIpcObject && t[i].lastIpcObject.class ? t[i].lastIpcObject.class
                    : (t[i].wayland && t[i].wayland.appId ? t[i].wayland.appId : "")
            if (c) return c
        }
        return ""
    }
    function same(a, b) {
        if (a.length !== b.length) return false
        for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false
        return true
    }
    function update() {
        const w = listWorkspaces(), s = listSpecials()
        if (!same(w, wsList)) wsList = w
        if (!same(s, specList)) specList = s
    }
    function kindFor(cls) { return AppCategory.kindFor(cls) }
    function listWorkspaces() {
        const v = Hyprland.workspaces.values
        const out = []
        for (let i = 0; i < v.length; i++) if (v[i].id > 0) out.push(v[i])
        out.sort((a, b) => a.id - b.id)
        return out
    }
    function listSpecials() {
        const v = Hyprland.workspaces.values
        const out = []
        for (let i = 0; i < v.length; i++)
            if (v[i].id < 0 && (v[i].toplevels.values.length > 0 || v[i].name === special)) out.push(v[i])
        out.sort((a, b) => a.name.localeCompare(b.name))
        return out
    }
    function activeWorkspaceId() {
        const ms = Hyprland.monitors.values
        for (let i = 0; i < ms.length; i++)
            if (ms[i].name === monitorName && ms[i].activeWorkspace) return ms[i].activeWorkspace.id
        return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    }
    property var wsList: []       // filled by update(), only reassigned when the contents change
    property var specList: []
    readonly property int activeIndex: {
        const id = activeWorkspaceId()
        for (let i = 0; i < wsList.length; i++) if (wsList[i].id === id) return i
        return -1
    }

    // ---- normal workspaces ----
    Item {
        id: normalBox
        readonly property real len: Math.max(0, root.wsList.length * root.step - root.gapY)
        width: root.horizontal ? len : Theme.cell
        height: root.horizontal ? Theme.cell : len
        Behavior on width  { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.dur(260); easing.type: Easing.OutCubic } }

        Rectangle {   // the one highlight; slides between workspaces, fades out for special workspaces
            width: Theme.cell; height: Theme.cell
            radius: Theme.innerRadius
            visible: root.activeIndex >= 0
            x: root.horizontal ? Math.max(0, root.activeIndex) * root.step : 0
            y: root.horizontal ? 0 : Math.max(0, root.activeIndex) * root.step
            color: Qt.alpha(Theme.accent, 0.22)
            border.color: Theme.accent
            border.width: 1.5
            opacity: root.special === "" ? 1 : 0
            Behavior on x       { NumberAnimation { duration: Theme.dur(380); easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on y       { NumberAnimation { duration: Theme.dur(380); easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
            Behavior on opacity { NumberAnimation { duration: Theme.dur(220) } }
        }

        Item {   // the cells; each one places itself by its index
            anchors.fill: parent
            Repeater {
                model: root.wsList
                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool active: root.special === "" && root.activeIndex >= 0
                                                   && root.wsList[root.activeIndex].id === modelData.id
                    readonly property var wins: modelData.toplevels.values
                    readonly property string cls: root.firstClass(modelData, HyprSync.rev)
                    readonly property string kind: cls !== "" ? root.kindFor(cls) : ""
                    property real appear: 0

                    x: root.horizontal ? index * root.step : 0
                    y: root.horizontal ? 0 : index * root.step
                    width: Theme.cell; height: Theme.cell
                    opacity: appear
                    scale: (0.5 + 0.5 * appear) * (area.pressed ? 0.9 : (area.containsMouse ? 1.08 : 1.0))
                    Component.onCompleted: appear = 1
                    Behavior on appear { NumberAnimation { duration: Theme.dur(380); easing.type: Easing.OutBack } }
                    Behavior on scale  { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutCubic } }

                    Rectangle {   // hover
                        anchors.fill: parent
                        radius: Theme.innerRadius
                        color: area.containsMouse && !cell.active ? Theme.surface : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.dur(150) } }
                    }
                    CategoryIcon {
                        anchors.centerIn: parent
                        width: Theme.iconSize; height: Theme.iconSize
                        visible: cell.kind !== ""
                        kind: cell.kind
                        color: cell.active ? Theme.accent : Theme.fg
                        Behavior on color { ColorAnimation { duration: Theme.dur(200) } }
                    }
                    Rectangle {   // empty workspace: a dot
                        anchors.centerIn: parent
                        visible: cell.cls === ""
                        width: cell.active ? 9 : 5; height: width; radius: width / 2
                        color: cell.active ? Theme.accent : Theme.dim
                        Behavior on width { NumberAnimation { duration: Theme.dur(200); easing.type: Easing.OutBack } }
                    }
                    Rectangle {   // several windows
                        visible: cell.wins.length > 1
                        anchors { right: parent.right; bottom: parent.bottom }
                        width: Theme.fs(13); height: width; radius: width / 2
                        color: Theme.accent
                        Text {
                            anchors.centerIn: parent
                            text: cell.wins.length
                            color: Theme.bg
                            font { family: Theme.font; pixelSize: Theme.fs(8); bold: true }
                        }
                    }
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Quickshell.execDetached(["hyprctl", "dispatch",
                            'hl.dsp.focus({ workspace = "' + cell.modelData.id + '" })'])
                    }
                }
            }
        }
    }

    // ---- divider ----
    Item {
        property real thick: root.specList.length > 0 ? 12 : 0
        width: root.horizontal ? thick : Theme.cell
        height: root.horizontal ? Theme.cell : thick
        clip: true
        Behavior on thick { NumberAnimation { duration: Theme.dur(240); easing.type: Easing.OutCubic } }
        Rectangle {
            anchors.centerIn: parent
            width: root.horizontal ? 1 : Theme.cell * 0.5
            height: root.horizontal ? Theme.cell * 0.5 : 1
            color: Qt.alpha(Theme.dim, 0.5)
        }
    }

    // ---- special workspaces: icon only ----
    Item {
        readonly property real len: Math.max(0, root.specList.length * root.step - root.gapY)
        width: root.horizontal ? len : Theme.cell
        height: root.horizontal ? Theme.cell : len
        Repeater {
            model: root.specList
            delegate: Rectangle {
                id: sc
                required property var modelData
                required property int index
                readonly property string nm: modelData.name.replace(/^special:/, "")
                readonly property bool active: root.special === modelData.name
                readonly property string cls: root.firstClass(modelData, HyprSync.rev)
                readonly property string kind: cls !== "" ? root.kindFor(cls) : ""
                property real appear: 0

                x: root.horizontal ? index * root.step : 0
                y: root.horizontal ? 0 : index * root.step
                width: Theme.cell; height: Theme.cell
                radius: Theme.innerRadius
                color: active ? Theme.accent2 : (sa.containsMouse ? Theme.surface : "transparent")
                opacity: appear
                scale: (0.5 + 0.5 * appear) * (sa.pressed ? 0.9 : (sa.containsMouse ? 1.08 : 1.0))
                Component.onCompleted: appear = 1
                Behavior on appear { NumberAnimation { duration: Theme.dur(380); easing.type: Easing.OutBack } }
                Behavior on scale  { NumberAnimation { duration: Theme.dur(140); easing.type: Easing.OutCubic } }
                Behavior on color  { ColorAnimation { duration: Theme.dur(200) } }

                CategoryIcon {
                    anchors.centerIn: parent
                    width: Theme.iconSize; height: Theme.iconSize
                    visible: sc.kind !== ""
                    kind: sc.kind
                    color: sc.active ? Theme.bg : Theme.accent2
                    Behavior on color { ColorAnimation { duration: Theme.dur(200) } }
                }
                Text {   // empty special workspace: its symbol
                    anchors.centerIn: parent
                    visible: sc.kind === ""
                    text: root.specialGlyphs[sc.nm] || (sc.nm ? sc.nm[0].toUpperCase() : "")
                    color: sc.active ? Theme.bg : Theme.accent2
                    font { family: Theme.font; pixelSize: Math.round(Theme.iconSize * 0.9); bold: true }
                }
                MouseArea {
                    id: sa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Quickshell.execDetached(["hyprctl", "dispatch",
                        'hl.dsp.workspace.toggle_special("' + sc.nm + '")'])
                }
            }
        }
    }
}
