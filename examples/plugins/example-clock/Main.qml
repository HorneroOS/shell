import QtQuick
import Hornero.PluginKit

Item {
    id: root

    // Host context (#372): declaring these properties opts in to the
    // host injecting the real surface values; the defaults keep the
    // plugin working on hosts without host context. On a vertical
    // rail or narrow bar (hostCompact) the weekday is dropped so the
    // label fits the rail instead of being clipped.
    property string hostOrientation: "horizontal"
    property bool hostCompact: false

    implicitWidth: label.implicitWidth + Theme.spacingSmall * 2
    implicitHeight: label.implicitHeight

    Settings {
        id: pluginSettings
        pluginId: "example-clock"
    }

    // Keyboard contract (#376): the clock is an action (it posts a
    // toast), so it is a real UiButton — tab stop, Enter/Space
    // activation, visible focus and an accessible name/description
    // come from PluginKit instead of a mouse-only MouseArea.
    UiButton {
        id: label
        anchors.centerIn: parent
        variant: "ghost"
        text: Qt.formatDateTime(new Date(), pluginSettings.value("twentyFourHour", true) ? (root.hostCompact ? "HH:mm" : "ddd, HH:mm") : (root.hostCompact ? "h:mm ap" : "ddd, h:mm ap"))
        tooltipText: "Example Clock: activate for details"
        onClicked: Notifications.toast("Example Clock", "This example uses the public PluginKit API.", "schedule")
    }
}
