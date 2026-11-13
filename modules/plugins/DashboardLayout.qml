import QtQuick

// Composable dashboard layout math (shell#378): the pure half of the
// dashboard Extensions layout, kept free of shell singletons so it is
// exercised directly by the offscreen probe
// (tests/qa/tst_dashboard_layout.qml). PluginDashboardCards.qml is
// the rendering half: it calls sectionsFor() once per model/layout
// change — never per card — so layout cost stays one O(n log n) pass
// even at the 33-plugin stress size.
//
// Inputs are plain data. `plugins` are the host copies from
// Plugins.dashboardPlugins() (id, name, cardSize, category, ...).
// `layout` is the user's persisted layout from
// Config.plugins.dashboardLayout: {order: [id], pinned: [id],
// sizes: {id: class}} — every part optional, malformed parts are
// ignored, and ids the user layout no longer knows simply sort by
// name. The manifest-declared category groups cards; pinning lifts a
// card into the reserved Pinned section; a user size overrides the
// manifest's preferred size class.
QtObject {
    id: root

    // Closed size-class set, mirrored by validate_plugin.py,
    // PluginHost and Plugins.normalizeSurfaces.
    readonly property var sizeClasses: ["compact", "standard", "wide"]
    // Card content widths per class; "standard" keeps the pre-#378
    // dashboard width contract (380) so existing cards are unchanged.
    readonly property var contentWidths: ({
            compact: 240,
            standard: 380,
            wide: 780
        })
    // Smallest card footprint drives the responsive column count.
    readonly property int minCardWidth: 260

    function sizeValid(size) {
        return root.sizeClasses.includes(size);
    }

    function contentWidth(size) {
        return root.contentWidths[root.sizeValid(size) ? size : "standard"];
    }

    function nextSize(size) {
        const index = root.sizeClasses.indexOf(size);
        return root.sizeClasses[(index < 0 ? 1 : index + 1) % root.sizeClasses.length];
    }

    // Responsive columns: as many minimum-width cards as fit in the
    // available width, at least one. Wide cards span two columns,
    // which GridLayout resolves back to one when a single column
    // fits, so nothing overflows a narrow dashboard.
    function columnsForWidth(availableWidth, spacing) {
        if (!(availableWidth > 0))
            return 1;
        return Math.max(1, Math.floor((availableWidth + spacing) / (root.minCardWidth + spacing)));
    }

    function columnSpan(size, columns) {
        return size === "wide" ? Math.min(2, Math.max(1, columns)) : 1;
    }

    function validIdList(value) {
        const seen = ({});
        const result = [];
        if (!Array.isArray(value))
            return result;
        for (const id of value) {
            if (typeof id === "string" && id !== "" && !seen[id]) {
                seen[id] = true;
                result.push(id);
            }
        }
        return result;
    }

    // Normalized view of the persisted layout for `ids`: unknown ids
    // dropped, size overrides restricted to the closed class set.
    function normalizeLayout(layout) {
        const source = layout && typeof layout === "object" && !Array.isArray(layout) ? layout : ({});
        const sizes = ({});
        const rawSizes = source.sizes && typeof source.sizes === "object" && !Array.isArray(source.sizes) ? source.sizes : ({});
        for (const id in rawSizes) {
            if (root.sizeValid(rawSizes[id]))
                sizes[id] = rawSizes[id];
        }
        return {
            order: root.validIdList(source.order),
            pinned: root.validIdList(source.pinned),
            sizes: sizes
        };
    }

    function effectiveSize(plugin, layout) {
        const declared = typeof plugin.cardSize === "string" ? plugin.cardSize : "standard";
        return layout.sizes[plugin.id] || declared;
    }

    function effectiveCategory(plugin) {
        const category = typeof plugin.category === "string" ? plugin.category.trim() : "";
        return category !== "" && category.toLowerCase() !== "pinned" ? category : "";
    }

    // One pass grouping + one sort per section. Section order is
    // observable contract: Pinned first (only when non-empty), named
    // categories alphabetically, uncategorized ("") last — the host
    // titles "" as "Other". Within a section, the persisted order
    // wins; plugins it does not name follow, sorted by name then id.
    function sectionsFor(plugins, rawLayout) {
        const layout = root.normalizeLayout(rawLayout);
        const orderIndex = ({});
        layout.order.forEach((id, i) => {
            orderIndex[id] = i;
        });
        const pinnedIds = ({});
        layout.pinned.forEach(id => {
            pinnedIds[id] = true;
        });
        const bySection = ({});
        const list = Array.isArray(plugins) ? plugins : [];
        for (const plugin of list) {
            if (!plugin || typeof plugin.id !== "string" || plugin.id === "")
                continue;
            const pinned = !!pinnedIds[plugin.id];
            const key = pinned ? "pinned" : root.effectiveCategory(plugin);
            if (!bySection[key])
                bySection[key] = [];
            bySection[key].push(Object.assign({}, plugin, {
                pinned: pinned,
                sizeClass: root.effectiveSize(plugin, layout)
            }));
        }
        const byOrder = (a, b) => {
            const ai = a.id in orderIndex ? orderIndex[a.id] : Number.MAX_SAFE_INTEGER;
            const bi = b.id in orderIndex ? orderIndex[b.id] : Number.MAX_SAFE_INTEGER;
            if (ai !== bi)
                return ai - bi;
            const an = (a.name || a.id).toLowerCase();
            const bn = (b.name || b.id).toLowerCase();
            return an === bn ? (a.id < b.id ? -1 : 1) : (an < bn ? -1 : 1);
        };
        const categories = Object.keys(bySection).filter(k => k !== "pinned" && k !== "")
            .sort((a, b) => a.toLowerCase() === b.toLowerCase() ? 0 : (a.toLowerCase() < b.toLowerCase() ? -1 : 1));
        const keys = (bySection.pinned ? ["pinned"] : []).concat(categories, bySection[""] ? [""] : []);
        return keys.map(key => ({
                    key: key,
                    category: key === "pinned" ? "" : key,
                    pinned: key === "pinned",
                    plugins: bySection[key].sort(byOrder)
                }));
    }

    // New order with `id` moved by `delta` among `visibleIds` (the
    // flattened section order the user sees). Unknown ids are seeded
    // from the visible order so the first keyboard move is never a
    // jump; moving past either end clamps.
    function movedOrder(order, visibleIds, id, delta) {
        const visible = root.validIdList(visibleIds);
        if (!visible.includes(id))
            return root.validIdList(order);
        const next = root.validIdList(order).filter(existing => visible.includes(existing));
        for (const existing of visible) {
            if (!next.includes(existing))
                next.push(existing);
        }
        const from = next.indexOf(id);
        const to = Math.max(0, Math.min(next.length - 1, from + delta));
        next.splice(from, 1);
        next.splice(to, 0, id);
        return next;
    }
}
