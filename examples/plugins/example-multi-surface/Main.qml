import QtQuick
import Hornero.PluginKit

Item {
    Settings {
        id: pluginSettings
        pluginId: "example-multi-surface"
    }

    implicitWidth: label.implicitWidth + Theme.spacingSmall * 2
    implicitHeight: label.implicitHeight

    // Keyboard contract (#376): an actionable label is a UiButton,
    // not a mouse-only MouseArea over Text.
    UiButton {
        id: label
        anchors.centerIn: parent
        variant: "ghost"
        text: pluginSettings.value("label", "HorneroOS")
        tooltipText: "Example Multi-Surface: activate for details"
        onClicked: Notifications.toast("Example Multi-Surface", "Bar surface of a manifest v2 package; the same package also ships a dashboard card.", "extension")
    }
}
