import Quickshell.Io
import QtQuick

JsonObject {
    // User-owned plugin data is namespaced by the manifest ID. Installed
    // packages and extension code never write the canonical shell config.
    property var settings: ({})
    property var desktopWidgetSlots: ({})
    // Persisted dashboard extension layout (shell#378):
    // {order: [pluginId], pinned: [pluginId], sizes: {pluginId:
    // "compact"|"standard"|"wide"}}. User-owned like settings above;
    // DashboardLayout.normalizeLayout tolerates any malformed shape,
    // so a stale or hand-edited value degrades to manifest order.
    property var dashboardLayout: ({})
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

    // Reset (shell#374): drop stored values so reads fall back to
    // the manifest defaults. Returns true only when storage changed
    // (and a save was requested); resetting an absent key is a no-op.
    function resetSetting(pluginId: string, key: string): bool {
        if (!validPluginId(pluginId) || !/^[a-z][a-zA-Z0-9]{0,47}$/.test(key))
            return false;

        const source = settings && typeof settings === "object" && !Array.isArray(settings) ? settings : ({});
        const stored = source[pluginId];
        if (!stored || typeof stored !== "object" || Array.isArray(stored)
                || !Object.prototype.hasOwnProperty.call(stored, key))
            return false;

        const next = JSON.parse(JSON.stringify(source));
        delete next[pluginId][key];
        if (Object.keys(next[pluginId]).length === 0)
            delete next[pluginId];
        settings = next;
        saveRequested();
        return true;
    }

    function resetSettings(pluginId: string): bool {
        if (!validPluginId(pluginId))
            return false;

        const source = settings && typeof settings === "object" && !Array.isArray(settings) ? settings : ({});
        if (!Object.prototype.hasOwnProperty.call(source, pluginId))
            return false;

        const next = JSON.parse(JSON.stringify(source));
        delete next[pluginId];
        settings = next;
        saveRequested();
        return true;
    }

    readonly property var allowedDashboardSizes: ["compact", "standard", "wide"]

    function dashboardLayoutSource(): var {
        return dashboardLayout && typeof dashboardLayout === "object" && !Array.isArray(dashboardLayout) ? dashboardLayout : ({});
    }

    function setDashboardLayout(next: var): void {
        dashboardLayout = next;
        saveRequested();
    }

    function setDashboardPinned(pluginId: string, pinned: bool): bool {
        if (!validPluginId(pluginId))
            return false;
        const next = JSON.parse(JSON.stringify(dashboardLayoutSource()));
        const current = Array.isArray(next.pinned) ? next.pinned.filter(id => id !== pluginId) : [];
        if (pinned)
            current.push(pluginId);
        next.pinned = current;
        setDashboardLayout(next);
        return true;
    }

    function setDashboardCardSize(pluginId: string, size: string): bool {
        if (!validPluginId(pluginId) || !allowedDashboardSizes.includes(size))
            return false;
        const next = JSON.parse(JSON.stringify(dashboardLayoutSource()));
        if (!next.sizes || typeof next.sizes !== "object" || Array.isArray(next.sizes))
            next.sizes = {};
        next.sizes[pluginId] = size;
        setDashboardLayout(next);
        return true;
    }

    // `order` is the full new visible order (DashboardLayout.
    // movedOrder computes it); only well-formed ids are stored.
    function setDashboardOrder(order: var): bool {
        if (!Array.isArray(order) || order.some(id => !validPluginId(id)))
            return false;
        const next = JSON.parse(JSON.stringify(dashboardLayoutSource()));
        next.order = order;
        setDashboardLayout(next);
        return true;
    }

    function validPluginId(pluginId: string): bool {
        return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(pluginId);
    }
}
