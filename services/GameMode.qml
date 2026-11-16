pragma Singleton

import qs.services
import Quickshell
import QtQuick

// Hyprland tuning hook of the gaming experience mode (services/Experience.qml).
// It is no longer a separate toggle: `enabled` follows the active mode's
// `hooks.hyprlandTuning` field, and switching modes (Experience.toggle,
// `qs ipc call experience set gaming`) is the only way to turn it on.
// Separate from Feral GameMode (per-process) and from power profiles.
Singleton {
    id: root

    readonly property bool enabled: Experience.hyprlandTuning
    // Value restored by a hot reload from the retired standalone toggle;
    // read once by Experience's first-run migration.
    readonly property bool legacyEnabled: legacy.enabled

    function setDynamicConfs(): void {
        Hypr.extras.applyOptions({
            "animations:enabled": 0,
            "decoration:shadow:enabled": 0,
            "decoration:blur:enabled": 0,
            "general:gaps_in": 0,
            "general:gaps_out": 0,
            "general:border_size": 1,
            "decoration:rounding": 0,
            "general:allow_tearing": 1
        });
    }

    onEnabledChanged: {
        if (enabled)
            setDynamicConfs();
        else
            Hypr.extras.message("reload");
    }

    Component.onCompleted: {
        if (enabled)
            setDynamicConfs();
    }

    PersistentProperties {
        id: legacy

        property bool enabled: false

        reloadableId: "gameMode"
    }

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            if (root.enabled)
                root.setDynamicConfs();
        }
    }
}
