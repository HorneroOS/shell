pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// One extension quick-setting tile in the Utilities quick toggles (RFC 0003
// section 4.3, PluginKit 4). The host draws the tile (same geometry and
// state layer as the built-in toggles, host-provided accessible role and
// name); the extension owns only the state it reports and what toggle()
// does: its `surfaces.quickSetting` entrypoint exposes `bool checked`,
// optional `string subtitle` and `bool busy`, and `function toggle()`.
// The entrypoint loads asynchronously in its own Loader; a failure marks
// that extension failed and leaves the tile disabled, never the row.
// In-process QML running as your user, unsandboxed, like every surface.
IconButton {
    id: root

    required property var tile

    readonly property var state: pluginLoader.item
    readonly property bool ready: pluginLoader.status === Loader.Ready && !!root.state
    readonly property string subtitle: root.ready && typeof root.state.subtitle === "string" ? root.state.subtitle : ""

    Layout.fillWidth: true
    radius: Appearance.rounding.small
    inactiveColour: Signal.palette.lifted
    toggle: root.tile.kind !== "button"
    icon: root.tile.glyph
    checked: root.ready && root.state.checked === true
    enabled: root.ready && root.state.busy !== true
    accessibleName: root.subtitle !== "" ? `${root.tile.title}, ${root.subtitle}` : root.tile.title
    onClicked: {
        if (!root.ready || typeof root.state.toggle !== "function")
            return;
        try {
            root.state.toggle();
        } catch (e) {
            Plugins.logDiagnostic(root.tile.pluginId, "tile-failed", `${root.tile.id}: ${String(e)}`);
        }
    }

    Loader {
        id: pluginLoader

        asynchronous: true
        source: Plugins.entrypointUrl(root.tile.pluginId, root.tile.entrypoint)
        onStatusChanged: {
            if (status === Loader.Ready)
                Plugins.markLoaded(root.tile.pluginId, "quickSetting");
            else if (status === Loader.Error)
                Plugins.markFailed(root.tile.pluginId, Plugins.loaderError(pluginLoader.errorString, pluginLoader.source) || "quickSetting entrypoint failed to load (see shell log)", "quickSetting");
        }
    }
}
