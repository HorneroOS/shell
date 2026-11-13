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
        text: pluginSettings.value("label", "HorneroOS")
        color: Theme.onSurface
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Notifications.toast("Example Multi-Surface", "Bar surface of a manifest v2 package; the same package also ships a dashboard card.", "extension")
    }
}
