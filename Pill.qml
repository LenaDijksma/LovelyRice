import QtQuick

// Rounded container used to group bar widgets (Caelestia-style). Lays its children out along the bar, whichever way the bar runs.
// What it looks like is /settings -> Style -> Module pills: filled | outline | glass | none, its own rounding and opacity.
Rectangle {
    id: pill
    default property alias content: stack.data
    property int padding: Theme.pillPad
    property int spacing: 6
    readonly property string look: Settings.pillStyle

    implicitWidth: stack.implicitWidth + padding * 2
    implicitHeight: stack.implicitHeight + padding * 2
    color: look === "filled" ? Qt.alpha(Theme.surface, Settings.pillOpacity / 100) : "transparent"
    radius: Theme.pillRadius
    border.width: look === "outline" ? 1 : 0
    border.color: Qt.alpha(Theme.accent, 0.55)

    Loader {                    // glass pill: its own piece of glass behind the content
        anchors.fill: parent
        active: pill.look === "glass"
        sourceComponent: GlassSurface {
            backdrop: Bar.backdropFor(pill)
            radius: pill.radius
            tintColor: Theme.surface
        }
    }

    BarStack {
        id: stack
        anchors.centerIn: parent
        spacing: pill.spacing
    }
}
