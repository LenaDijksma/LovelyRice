import QtQuick

// A plugin's utility bar module, inside a pill like the built-in modules.
// The plugin's component should set an implicitWidth / implicitHeight; api.horizontal says which way the bar runs.
Pill {
    id: slot
    property string pluginName: ""
    Loader { sourceComponent: Plugins.barComponent(slot.pluginName) }
}
