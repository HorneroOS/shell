import Quickshell.Io
import QtQuick

JsonObject {
    // User-owned plugin data is namespaced by the manifest ID. Installed
    // packages and extension code never write the canonical shell config.
    property var settings: ({})
    property var desktopWidgetSlots: ({})
    signal saveRequested

    readonly property var allowedDesktopSlots: [
        "top-left", "top-center", "top-right",
        "middle-left", "middle-center", "middle-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]

    function desktopWidgetSlot(pluginId: string, screenName: string): string {
        const source = desktopWidgetSlots && typeof desktopWidgetSlots === "object" && !Array.isArray(desktopWidgetSlots) ? desktopWidgetSlots : ({});
        const screenSlots = source[screenName || "default"];
        const pluginSlots = screenSlots && typeof screenSlots === "object" && !Array.isArray(screenSlots) ? screenSlots : ({});
        const slot = pluginSlots[pluginId] || "bottom-right";
        return allowedDesktopSlots.includes(slot) ? slot : "bottom-right";
    }

    function setDesktopWidgetSlot(pluginId: string, screenName: string, slot: string): bool {
        if (!validPluginId(pluginId) || !allowedDesktopSlots.includes(slot))
            return false;

        const source = desktopWidgetSlots && typeof desktopWidgetSlots === "object" && !Array.isArray(desktopWidgetSlots) ? desktopWidgetSlots : ({});
        const next = JSON.parse(JSON.stringify(source));
        const screenId = screenName || "default";
        if (!next[screenId] || typeof next[screenId] !== "object" || Array.isArray(next[screenId]))
            next[screenId] = {};
        next[screenId][pluginId] = slot;
        desktopWidgetSlots = next;
        saveRequested();
        return true;
    }

    function setSetting(pluginId: string, key: string, value: var): bool {
        if (!validPluginId(pluginId) || !/^[a-z][a-zA-Z0-9]{0,47}$/.test(key))
            return false;

        const source = settings && typeof settings === "object" && !Array.isArray(settings) ? settings : ({});
        const next = JSON.parse(JSON.stringify(source));
        if (!next[pluginId] || typeof next[pluginId] !== "object" || Array.isArray(next[pluginId]))
            next[pluginId] = {};
        next[pluginId][key] = value;
        settings = next;
        saveRequested();
        return true;
    }

    function validPluginId(pluginId: string): bool {
        return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(pluginId);
    }
}
