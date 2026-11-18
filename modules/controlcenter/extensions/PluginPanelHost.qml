pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// One extension panel inside Control Center › Extensions (RFC 0003
// section 4.4, PluginKit 4): the `surfaces.panel` entrypoint, loaded only
// while the panel is open and unloaded on close, in its own asynchronous
// Loader. A failure is shown inline and marks that extension failed through
// the Plugins service; it never takes the pane down. The panel gets the
// standard host context (hostSurface "panel") and may use Settings, the data
// facades and the Ui kit; it cannot navigate or change other panes. In-
// process QML running as your user, unsandboxed, like every surface.
ColumnLayout {
    id: root

    required property string pluginId
    required property var panel
    property bool open: false

    readonly property bool available: root.open && Plugins.hasSurface(root.pluginId, "panel")
    readonly property bool loadFailed: pluginLoader.status === Loader.Error

    spacing: Appearance.spacing.small

    StyledText {
        Layout.fillWidth: true
        visible: root.available || root.loadFailed
        text: root.panel.title
        font.weight: Appearance.font.weight.medium
    }

    Loader {
        id: pluginLoader

        readonly property int hostAvailableWidth: root.width > 0 ? Math.round(root.width) : 0

        Layout.fillWidth: true
        clip: true
        palette.windowText: Signal.palette.ink
        active: root.available
        source: active ? Plugins.entrypointUrl(root.pluginId, Plugins.surfaceFor(Plugins.entryFor(root.pluginId), "panel").entrypoint) : ""
        asynchronous: true

        onStatusChanged: {
            if (status === Loader.Ready)
                Plugins.markLoaded(root.pluginId, "panel");
            else if (status === Loader.Error)
                Plugins.markFailed(root.pluginId, Plugins.loaderError(pluginLoader.errorString, pluginLoader.source) || "panel entrypoint failed to load (see shell log)", "panel");
        }

        Binding {
            target: pluginLoader.item
            property: "hostSurface"
            value: "panel"
            when: pluginLoader.item !== null && "hostSurface" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostAvailableWidth"
            value: pluginLoader.hostAvailableWidth
            when: pluginLoader.item !== null && "hostAvailableWidth" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostCompact"
            value: pluginLoader.hostAvailableWidth < 280
            when: pluginLoader.item !== null && "hostCompact" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostEdge"
            value: "none"
            when: pluginLoader.item !== null && "hostEdge" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostOrientation"
            value: "horizontal"
            when: pluginLoader.item !== null && "hostOrientation" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.loadFailed
        text: qsTr("This panel failed to load.")
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.alert
        wrapMode: Text.Wrap
    }
}
