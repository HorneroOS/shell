import QtQuick
import Hornero.PluginKit

// Minimal desktop widget (PluginKit 3): the host draws the module frame,
// header and shadow and owns position/size/edit mode; this entrypoint
// only lays out its content in the host's content box.
Item {
    id: root

    // Host context: the desktop host injects the content box.
    property string hostSurface: "desktop"
    property int hostAvailableWidth: 280
    property int hostAvailableHeight: 0
    // Optional header context eyebrow drawn by the host frame.
    readonly property string widgetContext: "Note"

    implicitWidth: 280
    implicitHeight: column.implicitHeight

    Settings {
        id: pluginSettings
        pluginId: "example-desktop-note"
    }

    Column {
        id: column

        width: root.hostAvailableWidth > 0 ? root.hostAvailableWidth : root.implicitWidth
        spacing: Theme.spacing.smaller

        UiText {
            width: parent.width
            role: "subtitle"
            text: pluginSettings.value("note", "El futuro se construye acá.")
        }

        // Keyboard contract (#376): an action is a UiButton.
        UiButton {
            text: "Where am I?"
            glyph: "map-pin"
            tooltipText: "Desktop note: show this widget's anchor"
            onClicked: Notifications.toast("Desktop note", `Anchor: ${Desktop.anchor("example-desktop-note", Screen.name)}`, "map-pin")
        }
    }
}
