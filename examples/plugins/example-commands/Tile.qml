import QtQuick
import Hornero.PluginKit

// Quick-setting tile (PluginKit 4, RFC 0003 section 4.3): the host draws the
// tile; this Item reports state and implements toggle(). The state lives in
// a hidden setting, so it persists but never appears in the settings UI.
Item {
    id: root

    readonly property bool checked: pluginSettings.value("quiet", false)
    readonly property string subtitle: checked ? "On" : "Off"
    property bool busy: false

    function toggle() {
        pluginSettings.setValue("quiet", !checked);
    }

    Settings {
        id: pluginSettings

        pluginId: "example-commands"
    }
}
