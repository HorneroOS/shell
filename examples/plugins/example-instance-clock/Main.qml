import QtQuick
import Hornero.PluginKit

// Per-instance desktop widget (PluginKit 4, RFC 0003 section 6): the host
// injects hostInstanceId ("" for the main widget, an id for each extra
// instance) and Settings.instanceId makes every read and write use that
// instance's own values. Everything below is driven by the typed settings
// the Control Center generated controls edit, with a live preview.
Item {
    id: root

    property string hostSurface: "desktop"
    property string hostInstanceId: ""
    property int hostAvailableWidth: 260
    property int hostAvailableHeight: 0
    readonly property string widgetContext: pluginSettings.value("label", "Local").toUpperCase()

    implicitWidth: 260
    implicitHeight: column.implicitHeight

    Settings {
        id: pluginSettings

        pluginId: "example-instance-clock"
        instanceId: root.hostInstanceId
    }

    Column {
        id: column

        width: root.hostAvailableWidth > 0 ? root.hostAvailableWidth : root.implicitWidth
        spacing: Theme.spacing.smaller

        UiText {
            width: parent.width
            color: pluginSettings.value("accent", Theme.palette.cue)
            font.pointSize: pluginSettings.value("size", 32)
            text: pluginSettings.value("format", "24h") === "24h"
                ? Time.format(pluginSettings.value("showSeconds", false) ? "HH:mm:ss" : "HH:mm")
                : Time.format(pluginSettings.value("showSeconds", false) ? "h:mm:ss ap" : "h:mm ap")
        }

        UiText {
            width: parent.width
            visible: pluginSettings.value("showNote", false) && text.length > 0
            role: "caption"
            wrapMode: Text.Wrap
            text: pluginSettings.value("note", "")
        }
    }
}
