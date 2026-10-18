import QtQuick

Image {
    id: img
    property bool pending: false
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: false
    opacity: 0

    function reveal() { pending = false; fade.restart() }
    onStatusChanged: if (status === Image.Ready && pending) reveal()

    NumberAnimation { id: fade; target: img; property: "opacity"; from: 0; to: 1
                      duration: Theme.dur(800); easing.type: Easing.OutCubic }
}
