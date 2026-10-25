import QtQuick
import Hornero.PluginKit

Item {
    id: root

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Settings {
        id: pluginSettings
        pluginId: "example-clock"
    }

    Text {
        id: label
        text: Qt.formatDateTime(new Date(), pluginSettings.value("twentyFourHour", true) ? "ddd, HH:mm" : "ddd, h:mm ap")
        color: Theme.primary
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Notifications.toast("Example Clock", "This example uses the public PluginKit API.", "schedule")
    }
}
