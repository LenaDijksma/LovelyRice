import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Hot edge for the dropdown: a thin invisible strip along the middle of the dropdown's screen edge.
// Rest the pointer on it for a moment and the dropdown opens (it closes again when the pointer leaves it).
// Off by default: /settings → Dropdown → "Open when the pointer pushes against its edge".
PanelWindow {
    id: win
    required property var dropdown
    readonly property string pos: Settings.dropdownPosition
    readonly property bool horizontal: pos === "top" || pos === "bottom"

    screen: {
        const m = Hyprland.focusedMonitor
        for (const s of Quickshell.screens) if (m && s.name === m.name) return s
        return Quickshell.screens[0]
    }
    visible: Settings.dropdownHotEdge && !dropdown.open
    // the middle 40% of the edge, 2 px thick, so the corners and the ends of the bar stay clear
    anchors {
        left: pos !== "right"; right: pos !== "left"
        top: pos !== "bottom"; bottom: pos !== "top"
    }
    margins.left:   horizontal ? (win.screen ? win.screen.width * 0.3 : 600) : 0
    margins.right:  horizontal ? (win.screen ? win.screen.width * 0.3 : 600) : 0
    margins.top:    horizontal ? 0 : (win.screen ? win.screen.height * 0.3 : 300)
    margins.bottom: horizontal ? 0 : (win.screen ? win.screen.height * 0.3 : 300)
    implicitWidth: 2
    implicitHeight: 2
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "lovelyrice-dropdown-edge"
    WlrLayershell.layer: WlrLayer.Overlay

    Timer { id: dwell; interval: 250; onTriggered: win.dropdown.show(true) }
    Item {
        anchors.fill: parent
        HoverHandler { onHoveredChanged: hovered ? dwell.restart() : dwell.stop() }
    }
}
