pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.services
import QtQuick
import QtQuick.Layouts

// Custom settings surface host (shell#373/#374 follow-up): loads one
// enabled, installed plugin's `surfaces.settings` entrypoint inside
// Control Center › Extensions, alongside — never instead of — the
// generated typed-settings UI (PluginSettingsSection). Each plugin
// gets its own asynchronous Loader, so a settings entrypoint that
// fails to compile or instantiate is marked failed through the
// Plugins service (state + bounded, redacted diagnostics) and shows
// an inline error here; it never takes Control Center or another
// plugin down. Disabling the plugin (or safe mode) makes
// Plugins.hasSurface() false, which deactivates the Loader and
// unloads the entrypoint; hiding this section does the same.
//
// Honest trust note: this is in-process QML with exactly the same
// trust as every other surface — it runs as your user, unsandboxed.
// It is not a permission boundary and grants nothing new: the code
// is the same package the user already enabled.
ColumnLayout {
    id: root

    required property string pluginId
    required property string entrypoint

    // Live gate: enabled + installed + surface enabled + not safe
    // mode, straight from the service's effective-surfaces map.
    readonly property bool surfaceAvailable: Plugins.hasSurface(root.pluginId, "settings") && root.entrypoint !== ""
    readonly property bool loadFailed: pluginLoader.status === Loader.Error

    visible: root.surfaceAvailable || root.loadFailed
    spacing: Appearance.spacing.small

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Custom settings")
        font.weight: 500
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("This plugin's own settings UI runs in-process as your user, without a sandbox — the same trust as its other surfaces. Review its source before use.")
        font.pointSize: Appearance.font.size.small
        color: Colours.palette.m3outline
        wrapMode: Text.Wrap
    }

    Loader {
        id: pluginLoader

        readonly property int hostAvailableWidth: root.width > 0 ? Math.round(root.width) : 0
        readonly property int hostAvailableHeight: 0

        Layout.fillWidth: true
        clip: true
        palette.windowText: Colours.palette.m3onSurface
        active: root.surfaceAvailable && root.visible
        source: active ? `file://${Plugins.pluginsDir}/${root.pluginId}/${root.entrypoint}` : ""
        asynchronous: true

        onStatusChanged: {
            if (status === Loader.Ready)
                Plugins.logDiagnostic(root.pluginId, "settings-loaded", "");
            else if (status === Loader.Error)
                Plugins.markFailed(root.pluginId, pluginLoader.errorString || "settings entrypoint failed to load (see shell log)");
        }

        Binding {
            target: pluginLoader.item
            property: "hostOrientation"
            value: "horizontal"
            when: pluginLoader.item !== null && "hostOrientation" in pluginLoader.item
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
            property: "hostSurface"
            value: "settings"
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
            property: "hostAvailableHeight"
            value: pluginLoader.hostAvailableHeight
            when: pluginLoader.item !== null && "hostAvailableHeight" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostCompact"
            value: false
            when: pluginLoader.item !== null && "hostCompact" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
        Binding {
            target: pluginLoader.item
            property: "hostScreenName"
            value: ""
            when: pluginLoader.item !== null && "hostScreenName" in pluginLoader.item
            restoreMode: Binding.RestoreNone
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.loadFailed
        text: qsTr("This plugin's custom settings failed to load.")
        font.pointSize: Appearance.font.size.small
        color: Colours.palette.m3error
        wrapMode: Text.Wrap
    }
}
