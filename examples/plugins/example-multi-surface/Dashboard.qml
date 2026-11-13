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
        text: "Dashboard surface: " + pluginSettings.value("label", "HorneroOS")
        color: Theme.onSurface
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
    }
}
