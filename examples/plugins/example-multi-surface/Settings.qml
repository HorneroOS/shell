import QtQuick
import Hornero.PluginKit

Item {
    Settings {
        id: pluginSettings
        pluginId: "example-multi-surface"
    }

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        text: "Custom settings surface: label is \"" + pluginSettings.value("label", "HorneroOS") + "\" (edit it in the generated Settings tab)."
        color: Theme.onSurface
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
    }
}
