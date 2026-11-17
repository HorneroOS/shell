import QtQuick
import Hornero.PluginKit

// Control Center panel (PluginKit 4, RFC 0003 section 4.4): loaded only while
// the panel is open. Long content goes in a UiScrollArea.
Item {
    id: root

    property string hostSurface: "panel"
    property int hostAvailableWidth: 360

    implicitWidth: hostAvailableWidth
    implicitHeight: 160

    Settings {
        id: pluginSettings

        pluginId: "example-commands"
    }

    UiScrollArea {
        anchors.fill: parent
        accessibleName: "Tags"

        Column {
            width: parent.width
            spacing: Theme.spacing.smaller

            Repeater {
                model: pluginSettings.value("tags", [])

                UiText {
                    required property string modelData

                    width: parent.width
                    text: modelData
                }
            }
        }
    }
}
