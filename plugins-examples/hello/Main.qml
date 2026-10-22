import QtQuick
import Quickshell

// Example LovelyRice plugin (docs: PLUGINS.md).
//
// The root must be a Scope with `property var api`: LovelyRice fills it in before anything else runs.
// Everything below is optional; a plugin only has to define the extension points it wants:
//   barModule        a Component shown in the utility bar        (id "plugin:<name>" in /settings -> Bar)
//   paletteCommands  [{ name, desc, icon, keywords, takesArgs, run(args) }]   typed as /<name> in the palette
//   dropdownCard     a Component shown as a tab in the dropdown   (dropdownTitle names the tab)
Scope {
    id: root
    property var api

    property string uptime: ""

    // ---- bar module ----
    // Give the item an implicitWidth/implicitHeight; LovelyRice puts it in a pill like the built-in modules.
    // api.horizontal is true on a top/bottom bar, so lay out along the bar.
    property Component barModule: Component {
        Item {
            implicitWidth: grid.implicitWidth
            implicitHeight: grid.implicitHeight
            Grid {
                id: grid
                anchors.centerIn: parent
                columns: root.api.horizontal ? 2 : 1
                spacing: 2
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter
                Text {
                    text: "☺"
                    color: root.api.accent
                    font { family: root.api.font; pixelSize: root.api.fs(16) }
                }
                Text {
                    text: root.api.get("clicks", 0)          // stored per plugin, survives restarts
                    color: root.api.fg
                    font { family: root.api.font; pixelSize: root.api.fs(12); bold: true }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: root.api.set("clicks", root.api.get("clicks", 0) + 1)
            }
        }
    }

    // ---- palette command: type /hello or /hello some text ----
    property var paletteCommands: [
        {
            name: "hello", icon: "☺", desc: "Example plugin: /hello [text] sends a notification",
            keywords: "example greeting", takesArgs: true,
            run: function (args) { root.api.notify("hello", args !== "" ? args : "Hello from a plugin!") }
        }
    ]

    // ---- dropdown tab ----
    // The card gets the panel's width; give it an implicitHeight.
    property string dropdownTitle: "hello"
    property Component dropdownCard: Component {
        Item {
            implicitHeight: col.implicitHeight
            Column {
                id: col
                width: parent.width
                spacing: 10
                Text {
                    text: "Bar clicks: " + root.api.get("clicks", 0)
                    color: root.api.fg
                    font { family: root.api.font; pixelSize: 14 }
                }
                Rectangle {
                    width: btn.implicitWidth + 28; height: 32; radius: root.api.radiusSmall
                    color: root.api.surface
                    border.color: root.api.accent
                    Text {
                        id: btn
                        anchors.centerIn: parent
                        text: "Run `uptime -p`"
                        color: root.api.accent
                        font { family: root.api.font; pixelSize: 13 }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.api.run(["uptime", "-p"], function (code, out) { root.uptime = out.trim() })
                    }
                }
                Text {
                    visible: root.uptime !== ""
                    text: root.uptime
                    color: root.api.dim
                    font { family: root.api.font; pixelSize: 13 }
                }
            }
        }
    }
}
