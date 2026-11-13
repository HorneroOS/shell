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

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Settings {
        id: pluginSettings
        pluginId: "example-clock"
    }

    Text {
        id: label
        text: Qt.formatDateTime(new Date(), pluginSettings.value("twentyFourHour", true) ? (root.hostCompact ? "HH:mm" : "ddd, HH:mm") : (root.hostCompact ? "h:mm ap" : "ddd, h:mm ap"))
        color: Theme.onSurface
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSize
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Notifications.toast("Example Clock", "This example uses the public PluginKit API.", "schedule")
    }
}
