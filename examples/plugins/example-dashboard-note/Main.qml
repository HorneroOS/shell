import QtQuick
import Hornero.PluginKit

Item {
    Settings {
        id: pluginSettings
        pluginId: "example-dashboard-note"
    }

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        text: pluginSettings.value("showGreeting", true) ? "El futuro se construye acá." : "HorneroOS"
        color: Theme.primary
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Notifications.toast("HorneroOS", "Desktop and dashboard extensions share the same public API.", "extension")
    }
}
