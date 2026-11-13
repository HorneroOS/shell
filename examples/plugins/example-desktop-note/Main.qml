import QtQuick
import Hornero.PluginKit

Item {
    Settings {
        id: pluginSettings
        pluginId: "example-desktop-note"
    }

    implicitWidth: label.implicitWidth + Theme.spacingSmall * 2
    implicitHeight: label.implicitHeight

    // Keyboard contract (#376): an actionable label is a UiButton,
    // not a mouse-only MouseArea over Text.
    UiButton {
        id: label
        anchors.centerIn: parent
        variant: "ghost"
        text: pluginSettings.value("note", "El futuro se construye acá.")
        tooltipText: "Desktop note: activate for details"
        onClicked: Notifications.toast("Desktop note", `Position: ${Desktop.position("example-desktop-note", Screen.name)}`, "dashboard")
    }
}
