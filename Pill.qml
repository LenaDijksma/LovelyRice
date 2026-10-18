import QtQuick
import QtQuick.Layouts

// Tonal rounded container used to group sidebar widgets (Caelestia-style).
Rectangle {
    id: pill
    default property alias content: col.data
    property int padding: Theme.pillPad
    property int spacing: 6

    implicitHeight: col.implicitHeight + padding * 2
    color: Qt.alpha(Theme.surface, 0.8)
    radius: Theme.radiusSmall + 4

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: pill.padding }
        spacing: pill.spacing
    }
}
