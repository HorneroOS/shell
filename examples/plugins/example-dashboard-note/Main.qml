import QtQuick
import Hornero.PluginKit

Item {
    Settings {
        id: pluginSettings
        pluginId: "example-dashboard-note"
    }

    implicitWidth: label.implicitWidth + Theme.spacingSmall * 2
    implicitHeight: label.implicitHeight

    // Keyboard contract (#376): an actionable label is a UiButton,
    // not a mouse-only MouseArea over Text.
    UiButton {
        id: label
        anchors.centerIn: parent
        variant: "ghost"
        text: pluginSettings.value("showGreeting", true) ? "El futuro se construye acá." : "HorneroOS"
        tooltipText: "Dashboard note: activate for details"
        onClicked: Notifications.toast("HorneroOS", "Desktop and dashboard extensions share the same public API.", "extension")
    }
}
