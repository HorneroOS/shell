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
    // Extra instances of a plugin's desktop widget (RFC 0003 section 6):
    // {pluginId: [{id, label}]}. The primary instance (the widget every
    // enabled extension already has) is implicit and has the empty
    // instance id; its storage key is the plugin id, so no stored data
    // is migrated. An extra instance's key is `<pluginId>#<instanceId>`
    // and namespaces its settings, geometry and anchor like a plugin id.
    property var instances: ({})
    readonly property int maxInstances: 8
    // Extension quick-setting tiles the person placed in the quick toggles
    // (RFC 0003 section 4.3): ["<pluginId>:<tileId>"], in display order.
    // Tiles are off until added here; stale keys are ignored on read.
    property var quickTiles: []
    readonly property int maxQuickTiles: 12
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

    // Namespace for stored per-instance data: a plugin id, optionally
    // followed by `#<instanceId>` for an extra instance. Plugin ids and
    // instance ids are validated separately, so a key can never collide
    // with another plugin's id (`#` is not a plugin id character).
    function validPluginId(pluginId: string): bool {
        return /^[a-z0-9]+(?:-[a-z0-9]+)*(?:#[a-z0-9]{1,8})?$/.test(pluginId);
    }

    function validInstanceId(instanceId: string): bool {
        return /^[a-z0-9]{1,8}$/.test(instanceId);
    }

    function instanceKey(pluginId: string, instanceId: string): string {
        return instanceId ? `${pluginId}#${instanceId}` : pluginId;
    }

    // Values read from shell.json arrive as native variant lists whose
    // Array.isArray() is false; a JSON round trip yields plain JS arrays.
    function plain(value: var): var {
        try {
            return JSON.parse(JSON.stringify(value));
        } catch (e) {
            return null;
        }
    }

    function validTileKey(key: string): bool {
        return /^[a-z0-9]+(?:-[a-z0-9]+)*:[a-z][a-zA-Z0-9]{0,31}$/.test(key);
    }

    function quickTilesList(): var {
        const stored = plain(quickTiles);
        const list = Array.isArray(stored) ? stored : [];
        const result = [];
        for (const key of list) {
            if (typeof key === "string" && validTileKey(key) && !result.includes(key))
                result.push(key);
            if (result.length >= maxQuickTiles)
                break;
        }
        return result;
    }

    function setQuickTile(key: string, placed: bool): bool {
        if (!validTileKey(key))
            return false;
        const current = quickTilesList();
        const has = current.includes(key);
        if (placed === has)
            return true;
        if (placed && current.length >= maxQuickTiles)
            return false;
        quickTiles = placed ? current.concat([key]) : current.filter(k => k !== key);
        saveRequested();
        return true;
    }

    // Values read from shell.json arrive as native variant lists whose
    // Array.isArray() is false; a JSON round trip yields plain JS arrays.
    function plain(value: var): var {
        try {
            return JSON.parse(JSON.stringify(value));
        } catch (e) {
            return null;
        }
    }

    function instancesSource(): var {
        const source = plain(instances);
        return source && typeof source === "object" && !Array.isArray(source) ? source : ({});
    }

    // Normalised extra instances of one plugin: well-formed, unique,
    // bounded. Anything malformed in a hand-edited config is ignored.
    function instancesOf(pluginId: string): var {
        const list = instancesSource()[pluginId];
        if (!Array.isArray(list))
            return [];
        const seen = new Set();
        const result = [];
        for (const item of list) {
            if (!item || typeof item !== "object" || typeof item.id !== "string" || !validInstanceId(item.id) || seen.has(item.id))
                continue;
            seen.add(item.id);
            const label = typeof item.label === "string" ? item.label.trim().slice(0, 32) : "";
            result.push({
                id: item.id,
                label: label
            });
            if (result.length >= maxInstances)
                break;
        }
        return result;
    }

    // Adds an extra instance and returns its id ("" when refused). A new
    // instance starts from the declared defaults, or from a copy of the
    // stored settings of `copyFrom` (an instance key, e.g. the primary).
    function addInstance(pluginId: string, label: string, copyFrom: string): string {
        if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(pluginId))
            return "";
        const current = instancesOf(pluginId);
        if (current.length >= maxInstances)
            return "";
        let n = 1;
        while (current.some(item => item.id === `i${n}`))
            n++;
        const id = `i${n}`;
        const next = JSON.parse(JSON.stringify(instancesSource()));
        next[pluginId] = current.concat([{
                id: id,
                label: (label || "").trim().slice(0, 32)
            }]);
        instances = next;
        if (copyFrom && validPluginId(copyFrom)) {
            const source = settings && typeof settings === "object" && !Array.isArray(settings) ? settings : ({});
            const stored = source[copyFrom];
            if (stored && typeof stored === "object" && !Array.isArray(stored)) {
                const copy = JSON.parse(JSON.stringify(settings));
                copy[instanceKey(pluginId, id)] = JSON.parse(JSON.stringify(stored));
                settings = copy;
            }
        }
        saveRequested();
        return id;
    }

    function renameInstance(pluginId: string, instanceId: string, label: string): bool {
        const current = instancesOf(pluginId);
        if (!current.some(item => item.id === instanceId))
            return false;
        const next = JSON.parse(JSON.stringify(instancesSource()));
        next[pluginId] = current.map(item => item.id === instanceId ? {
                id: item.id,
                label: (label || "").trim().slice(0, 32)
            } : item);
        instances = next;
        saveRequested();
        return true;
    }

    // Removes an extra instance and everything stored for it: settings,
    // geometry and anchor on every display.
    function removeInstance(pluginId: string, instanceId: string): bool {
        const current = instancesOf(pluginId);
        if (!current.some(item => item.id === instanceId))
            return false;
        const key = instanceKey(pluginId, instanceId);
        const next = JSON.parse(JSON.stringify(instancesSource()));
        const kept = current.filter(item => item.id !== instanceId);
        if (kept.length > 0)
            next[pluginId] = kept;
        else
            delete next[pluginId];
        instances = next;
        const withoutKey = source => {
            if (!source || typeof source !== "object" || Array.isArray(source))
                return null;
            const copy = JSON.parse(JSON.stringify(source));
            let changed = false;
            if (Object.prototype.hasOwnProperty.call(copy, key)) {
                delete copy[key];
                changed = true;
            }
            return changed ? copy : null;
        };
        const withoutKeyPerScreen = source => {
            if (!source || typeof source !== "object" || Array.isArray(source))
                return null;
            const copy = JSON.parse(JSON.stringify(source));
            let changed = false;
            for (const screen of Object.keys(copy)) {
                if (copy[screen] && typeof copy[screen] === "object" && Object.prototype.hasOwnProperty.call(copy[screen], key)) {
                    delete copy[screen][key];
                    changed = true;
                }
            }
            return changed ? copy : null;
        };
        const nextSettings = withoutKey(settings);
        if (nextSettings)
            settings = nextSettings;
        const nextWidgets = withoutKeyPerScreen(desktopWidgets);
        if (nextWidgets)
            desktopWidgets = nextWidgets;
        const nextSlots = withoutKeyPerScreen(desktopWidgetSlots);
        if (nextSlots)
            desktopWidgetSlots = nextSlots;
        saveRequested();
        return true;
    }
}
