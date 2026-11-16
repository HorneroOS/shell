import Quickshell.Io
import QtQuick

JsonObject {
    // User-owned plugin data is namespaced by the manifest ID. Installed
    // packages and extension code never write the canonical shell config.
    property var settings: ({})
    // Desktop widget anchor per screen and plugin (one of the nine
    // allowedDesktopSlots): where a widget starts before it is moved.
    property var desktopWidgetSlots: ({})
    // Desktop widget geometry per screen and plugin (PluginKit 3):
    // {screen: {pluginId: {fx, fy, width, height}}}. fx/fy are the
    // widget's position as a fraction (0–1) of the free space on that
    // screen's widget area, so a resolution change keeps it in the same
    // relative place; width/height are logical pixels. Written only when
    // the person moves or resizes a widget in edit mode.
    property var desktopWidgets: ({})
    // Persisted dashboard extension layout (shell#378):
    // {order: [pluginId], pinned: [pluginId], sizes: {pluginId:
    // "compact"|"standard"|"wide"}}. User-owned like settings above;
    // DashboardLayout.normalizeLayout tolerates any malformed shape,
    // so a stale or hand-edited value degrades to manifest order.
    property var dashboardLayout: ({})
    // Safe recovery mode (shell#380): when true, no user extension
    // QML (and no plugin manifest) is loaded at all, so the Control
    // Center Extensions pane stays reachable to disable a broken
    // plugin. HORNERO_SAFE_MODE=1 at launch forces the same without
    // touching this persisted value.
    property bool safeMode: false
    signal saveRequested

    function setSafeMode(enabled: bool): bool {
        if (safeMode === enabled)
            return false;
        safeMode = enabled;
        saveRequested();
        return true;
    }

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
        // Choosing an anchor places the widget there: drop any saved
        // free position so the anchor takes effect (size is kept).
        const geometry = desktopWidgetGeometry(pluginId, screenName);
        if (geometry)
            setDesktopWidgetGeometry(pluginId, screenName, {
                width: geometry.width,
                height: geometry.height
            }, false);
        saveRequested();
        return true;
    }

    // Saved geometry or null. Malformed entries read as null.
    function desktopWidgetGeometry(pluginId: string, screenName: string): var {
        const source = desktopWidgets && typeof desktopWidgets === "object" && !Array.isArray(desktopWidgets) ? desktopWidgets : ({});
        const screenGeometry = source[screenName || "default"];
        const entry = screenGeometry && typeof screenGeometry === "object" && !Array.isArray(screenGeometry) ? screenGeometry[pluginId] : null;
        if (!entry || typeof entry !== "object" || Array.isArray(entry))
            return null;
        const result = {};
        for (const key of ["fx", "fy"]) {
            if (typeof entry[key] === "number" && isFinite(entry[key]))
                result[key] = Math.max(0, Math.min(1, entry[key]));
        }
        for (const key of ["width", "height"]) {
            if (Number.isInteger(entry[key]) && entry[key] >= 80 && entry[key] <= 4000)
                result[key] = entry[key];
        }
        return Object.keys(result).length > 0 ? result : null;
    }

    function setDesktopWidgetGeometry(pluginId: string, screenName: string, geometry: var, save: bool): bool {
        if (!validPluginId(pluginId) || !geometry || typeof geometry !== "object")
            return false;
        const clean = {};
        for (const key of ["fx", "fy"]) {
            if (typeof geometry[key] === "number" && isFinite(geometry[key]))
                clean[key] = Math.round(Math.max(0, Math.min(1, geometry[key])) * 10000) / 10000;
        }
        for (const key of ["width", "height"]) {
            if (typeof geometry[key] === "number" && isFinite(geometry[key]))
                clean[key] = Math.max(80, Math.min(4000, Math.round(geometry[key])));
        }
        const source = desktopWidgets && typeof desktopWidgets === "object" && !Array.isArray(desktopWidgets) ? desktopWidgets : ({});
        const next = JSON.parse(JSON.stringify(source));
        const screenId = screenName || "default";
        if (!next[screenId] || typeof next[screenId] !== "object" || Array.isArray(next[screenId]))
            next[screenId] = {};
        next[screenId][pluginId] = clean;
        desktopWidgets = next;
        if (save !== false)
            saveRequested();
        return true;
    }

    function resetDesktopWidgetGeometry(pluginId: string, screenName: string): bool {
        const source = desktopWidgets && typeof desktopWidgets === "object" && !Array.isArray(desktopWidgets) ? desktopWidgets : ({});
        const screenId = screenName || "default";
        if (!source[screenId] || !Object.prototype.hasOwnProperty.call(source[screenId], pluginId))
            return false;
        const next = JSON.parse(JSON.stringify(source));
        delete next[screenId][pluginId];
        desktopWidgets = next;
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
