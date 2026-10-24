import QtQuick
import Hornero.PluginKit

Item {
    Settings {
        id: pluginSettings
        pluginId: "example-desktop-note"
    }

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        text: pluginSettings.value("note", "El futuro se construye acá.")
        color: Theme.primary
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Notifications.toast("Desktop note", `Position: ${Desktop.position("example-desktop-note", Screen.name)}`, "dashboard")
    }
}
