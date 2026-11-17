pragma ComponentBehavior: Bound

import qs.components
import qs.components.clearink
import qs.services
import qs.config
import qs.modules.plugins
import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import Quickshell
import QtQuick
import QtQuick.Layouts

// One bar of the layout (docs/LAYOUTS.md): an edge, a style and three
// component groups. Strip styles (attached, inset) span the edge with the
// groups at start/center/end; content styles (floating, dock) are one
// content-sized pill; islands renders each non-empty group as its own pill.
Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    required property var spec

    readonly property string edge: spec.edge
    readonly property string style: spec.style
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property bool floating: style !== "attached"
    readonly property bool strip: style === "attached" || style === "inset"
    // Clear backdrop: no slab, no frame strip, no scrim; components sit on the
    // wallpaper with adaptive per-region ink (signal-visual-language §12).
    readonly property bool clear: spec.backdrop === "clear"
    // Narrow horizontal bars (laptop panels, split screens) tighten wide
    // components instead of letting groups collide. A width breakpoint, not
    // a content measurement, so compacting can never feed back into itself.
    readonly property bool compact: !vertical && width > 0 && width < 1500
    readonly property int edgePadding: Density.segmentPad
    // The bar body is exactly `spec.thickness` (density-scaled): no extra frame padding.
    readonly property int barPadding: 0
    // Cross-axis thickness of a pill (excludes the float gap)
    readonly property int pillThickness: Density.thickness(spec.thickness) + barPadding * 2
    readonly property int pillPadding: floating ? Appearance.padding.small : 0
    readonly property real floatGap: floating ? spec.margin : 0
    // Main-axis inset of strips: inset bars keep the float gap at both ends
    readonly property real stripInset: style === "inset" ? spec.margin : 0
    readonly property int groupSpacing: Appearance.spacing.normal
    // Segment anatomy (signal-visual-language §4.1/§4.2): 12 px horizontal
    // padding (8 px vertical in rails), rules inset 8 px from the edges.
    readonly property int segmentPadding: vertical ? Density.segmentPadRail : Density.segmentPad
    readonly property int segmentInset: 6
    // Adjacent icon-only entries share one segment with a 12 px gap.
    readonly property var clusterIds: ["quickActions", "statusIcons", "tray", "extensions"]
    // Kept for ActiveWindow compat (main-axis end padding)
    readonly property int vPadding: edgePadding

    readonly property var islandDefs: {
        const g = spec.groups;
        if (style === "islands") {
            const defs = [];
            for (const name of ["start", "center", "end"])
                if (g[name].some(e => e.enabled))
                    defs.push({align: name, groups: [name]});
            return defs;
        }
        return [{align: strip ? "fill" : "center", groups: ["start", "center", "end"]}];
    }

    readonly property list<Item> islands: {
        const out = [];
        for (let i = 0; i < islandRepeater.count; i++) {
            const it = islandRepeater.itemAt(i);
            if (it)
                out.push(it);
        }
        return out;
    }
    readonly property Item visualItem: islands.length > 0 ? islands[0] : null
    // All entry loaders across groups; ActiveWindow sizes itself from its
    // siblings through this shared grid layout.
    readonly property var entryLoaders: {
        const out = [];
        for (const island of islands)
            for (const g of island.groupItems)
                for (const c of g.layout.children)
                    out.push(c);
        return out;
    }
    readonly property var container: ({
            children: entryLoaders
        })
    // Island rectangles in bar coordinates (input mask, hit testing).
    readonly property var visualRects: islands.filter(i => i.visible && i.width > 0 && i.height > 0).map(i => ({
                x: i.x,
                y: i.y,
                width: i.width,
                height: i.height
            }))

    function mainLength(item: Item): real {
        return vertical ? item.height : item.width;
    }

    function containsPoint(lx: real, ly: real): bool {
        for (const r of visualRects)
            if (lx >= r.x && lx <= r.x + r.width && ly >= r.y && ly <= r.y + r.height)
                return true;
        return false;
    }

    function allGroups(): var {
        const out = [];
        for (const island of islands)
            for (const g of island.groupItems)
                out.push(g);
        return out;
    }

    // Loader of the component under a bar-local point, or null. Hit-tests
    // along the bar's main axis only (cross axis pinned to the group's
    // centre): moving from a trigger towards its popout crosses the bar
    // below/beside the glyph and must not count as leaving the component.
    function entryAt(lx: real, ly: real): var {
        for (const g of allGroups()) {
            if (!g.visible)
                continue;
            const pt = g.layout.mapFromItem(root, lx, ly);
            if (vertical)
                pt.x = g.layout.width / 2;
            else
                pt.y = g.layout.height / 2;
            const ch = g.layout.childAt(pt.x, pt.y);
            if (ch)
                return {loader: ch, layout: g.layout, pt: pt};
        }
        return null;
    }

    // Native islands enabled in this bar's layout (shell#439), as the bar
    // section names extension indicators can join.
    readonly property var presentSections: {
        const map = ({
                "statusIcons": "status",
                "quickActions": "actions",
                "clock": "clock",
                "extensions": "end"
            });
        const out = [];
        const groups = root.spec?.groups ?? ({});
        for (const name in groups)
            for (const entry of (groups[name] ?? []))
                if (entry && entry.enabled && map[entry.id])
                    out.push(map[entry.id]);
        return out;
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;
        for (const g of allGroups())
            for (let i = 0; i < g.repeater.count; i++) {
                const item = g.repeater.itemAt(i);
                if (item?.enabled && item.id === "tray" && item.item)
                    item.item.expanded = false;
            }
    }

    // Extensions islands (entry or legacy end-group instance) collapse like
    // the compact tray: on another entry, or when the pointer leaves the bar.
    function extensionIslandOf(entry: var): var {
        if (!entry)
            return null;
        if (entry.item && "fallbackSections" in entry.item && "expandIcon" in entry.item)
            return entry.item;
        if ("fallbackSections" in entry && "expandIcon" in entry)
            return entry;
        return null;
    }

    function closeExtensionIslands(keep: var): void {
        if (!Config.bar.extensions.compact)
            return;
        for (const g of allGroups())
            for (const c of g.layout.children) {
                const island = extensionIslandOf(c);
                if (island && island !== keep)
                    island.expanded = false;
            }
    }

    function resetPopout(): void {
        if (popouts.ownerSpec?.item === root)
            popouts.close();
        closeTray();
        closeExtensionIslands(null);
    }

    // This bar as the owner of an anchored surface (RFC 0001 §4): the
    // solver derives expansion direction, anchor line and attachment from
    // it; `item` is the live slab so the anchor line follows bar motion.
    readonly property var surfaceOwner: ({
            edge: root.edge,
            style: root.style,
            thickness: root.pillThickness,
            margin: root.floatGap,
            floating: root.floating,
            clear: root.clear,
            item: root
        })

    // Every bar popout goes through here: `how` is "hover", "click" or
    // "keyboard" (hover honours the intent delay; click/keyboard may take
    // focus).
    function openPopout(name: string, anchor: Item, how: string): void {
        popouts.openFor(name, anchor, root.surfaceOwner, how);
    }

    // Extension popouts (shell#449) share the native popout panel. A host
    // Loader advertises `hostPopoutContent`; only extensions with a popover
    // open one, and they follow exactly the native hover/claim flow.
    function pluginLoaderAt(container: Item, lx: real, ly: real): var {
        const stack = [container];
        while (stack.length > 0) {
            const it = stack.pop();
            if (!it)
                continue;
            if ("hostRegisterPopout" in it && it.visible) {
                const p = root.mapToItem(it, lx, ly);
                if (vertical ? (p.y >= 0 && p.y <= it.height) : (p.x >= 0 && p.x <= it.width))
                    return it;
            }
            for (const c of it.children)
                stack.push(c);
        }
        return null;
    }

    function isOwnLoader(loader: Item): bool {
        let p = loader;
        while (p) {
            if (p === root)
                return true;
            p = p.parent;
        }
        return false;
    }

    function openPluginPopout(loader: Item, how: string): void {
        if (!loader || !loader.hostPopoutContent)
            return;
        openPopout(loader.name, loader, how);
    }

    property Item openPluginLoader: null

    function syncPluginPopoutState(): void {
        const next = popouts.hasCurrent && String(popouts.currentName).startsWith("plugin:") ? popouts.currentAnchor : null;
        if (root.openPluginLoader === next)
            return;
        if (root.openPluginLoader)
            root.openPluginLoader.hostPopoutOpen = false;
        root.openPluginLoader = next;
        if (next)
            next.hostPopoutOpen = true;
    }

    Connections {
        target: Plugins

        function onPopoutRequested(loader: Item, open: bool): void {
            if (!root.isOwnLoader(loader))
                return;
            if (open)
                root.openPluginPopout(loader, FocusMode.keyboard ? "keyboard" : "click");
            else if (popouts.currentAnchor === loader)
                popouts.close();
        }
    }

    Connections {
        target: popouts

        function onHasCurrentChanged(): void {
            root.syncPluginPopoutState();
        }
        function onCurrentAnchorChanged(): void {
            root.syncPluginPopoutState();
        }
        function onCurrentNameChanged(): void {
            root.syncPluginPopoutState();
        }
    }

    function openStatusPopout(name: string, anchor: Item): void {
        if (!Config.bar.popouts.statusIcons || !anchor)
            return;
        openPopout(name, anchor, "keyboard");
    }

    // Popout trigger at a bar-local point.
    function checkPopoutAt(lx: real, ly: real): void {
        // Pointer hover is a fresh, non-keyboard intent even when it moves
        // between triggers without closing the currently visible popout.
        if (!popouts.isDetached)
            popouts.keyboardIntent = false;
        try {
            const hit = entryAt(lx, ly);
            const ch = hit?.loader ?? null;

            if (ch?.id !== "tray")
                closeTray();
            const extIsland = extensionIslandOf(ch);
            closeExtensionIslands(extIsland);

            if (!ch) {
                popouts.hoverLeave();
                return;
            }

            const id = ch.id;
            // Entries are Loaders (ch.item); the legacy Extensions island
            // (layouts without an "extensions" entry) is inserted directly.
            const item = ch.item ?? ch;
            // Extension indicators can sit in any island except the ones
            // with their own popout routing below (shell#449).
            const pluginHit = (id === "statusIcons" || id === "tray" || id === "activeWindow") ? null : pluginLoaderAt(item, lx, ly);
            const axisPos = vertical ? hit.pt.y : hit.pt.x;
            const start = vertical ? ch.y : ch.x;

            if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
                const items = item?.items;
                if (!items || typeof items.childAt !== "function")
                    return;
                const mapped = root.mapToItem(items, lx, ly);
                const icon = vertical ? items.childAt(items.width / 2, mapped.y) : items.childAt(mapped.x, items.height / 2);
                if (icon && "hostRegisterPopout" in icon) {
                    // Extension in the status island: native popout when it
                    // has a popover, nothing (like a popout-less icon) otherwise.
                    if (icon.hostPopoutContent)
                        openPluginPopout(icon, "hover");
                    else
                        popouts.hoverLeave();
                } else if (icon) {
                    openPopout(icon.name, icon, "hover");
                } else {
                    popouts.hoverLeave();
                }
            } else if (id === "tray" && Config.bar.popouts.tray) {
                if (!item || !item.expandIcon)
                    return;
                const overExpandIcon = item.expandIcon.contains(root.mapToItem(item.expandIcon, lx, ly));
                if (!Config.bar.tray.compact || (item.expanded && !overExpandIcon)) {
                    const layoutLength = vertical ? item.layout.implicitHeight : item.layout.implicitWidth;
                    const count = item.items?.count ?? 0;
                    const index = Math.floor(((axisPos - start - item.padding * 2 + item.spacing) / layoutLength) * count);
                    const trayItem = item.items?.itemAt(index) ?? null;
                    if (trayItem)
                        openPopout(`traymenu${index}`, trayItem, "hover");
                    else
                        popouts.hoverLeave();
                } else {
                    popouts.hoverLeave();
                    item.expanded = true;
                }
            } else if (pluginHit !== null || extIsland !== null || id === "clock" || id === "quickActions") {
                // Compact Extensions island: same flow as the compact tray —
                // the chevron (or a collapsed island) expands it first.
                if (extIsland && extIsland.compact) {
                    const overExpandIcon = extIsland.expandIcon.contains(root.mapToItem(extIsland.expandIcon, lx, ly));
                    if (!extIsland.expanded || overExpandIcon) {
                        popouts.hoverLeave();
                        extIsland.expanded = true;
                        return;
                    }
                }
                // Extensions in their own island or joined to a native one.
                if (pluginHit && pluginHit.hostPopoutContent)
                    openPluginPopout(pluginHit, "hover");
                else
                    popouts.hoverLeave();
            } else if (id === "activeWindow" && Config.bar.popouts.activeWindow) {
                if (!item)
                    return;
                openPopout(id.toLowerCase(), item, "hover");
            } else {
                popouts.hoverLeave();
            }
        } catch (e) {
            // During layout transitions the bar items may be temporarily undefined
            popouts.hoverLeave();
        }
    }

    function handleWheelAt(lx: real, ly: real, angleDelta: point): void {
        const ch = entryAt(lx, ly)?.loader ?? null;
        const pos = vertical ? ly : lx;
        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            if (Compositor.isNiri) {
                if (angleDelta.y !== 0)
                    Compositor.focusWorkspaceDirection(angleDelta.y > 0 ? -1 : 1);
                return;
            }
            const mon = (Config.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(`togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (Config.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(`workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (pos < mainLength(root) / 2 && Config.bar.scrollActions.volume) {
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            const monitor = Brightness.getMonitorForScreen(screen);
            if (!monitor?.available)
                return;
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + Config.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - Config.services.brightnessIncrement);
        }
    }

    onSpecChanged: resetPopout()
    onWidthChanged: pokeInk()
    onHeightChanged: pokeInk()

    // Cockpit Clear has no bar background at all (RFC 0001 §5.1): no scrim,
    // tint, slab, blur or backdrop shadow. Legibility comes only from the
    // per-region foreground ink and glyph halo of ClearInkField/ClearInkTone.
    ClearInkField {
        id: inkField

        active: root.clear
        screenWidth: root.screen.width
        screenHeight: root.screen.height
        source: Wallpapers.current
    }

    function pokeInk(): void {
        if (root.clear)
            inkField.poke();
    }

    Repeater {
        id: islandRepeater

        model: root.islandDefs

        Island {}
    }

    // One pill. Main-axis placement: strips span the edge; single content
    // pills centre; islands sit at start/center/end, the centre one truly
    // centred but clamped between its neighbours (hidden if it cannot fit).
    component Island: Item {
        id: island

        required property var modelData
        required property int index

        readonly property string align: modelData.align
        readonly property bool fill: align === "fill"
        readonly property list<Item> groupItems: [startGroup, centerGroup, endGroup]
        readonly property real contentLength: {
            let len = 0;
            let n = 0;
            for (const g of groupItems)
                // Geometry must follow the configured content, not the
                // effective visual visibility inherited from this island.
                // The island's own fit test depends on its contentLength;
                // feeding g.visible back into this calculation can create
                // a visibility → fit → size binding loop.
                if (g.active && g.entries.some(e => e.enabled)) {
                    len += root.vertical ? g.implicitHeight : g.implicitWidth;
                    n++;
                }
            return len + Math.max(0, n - 1) * root.groupSpacing;
        }
        readonly property real mainLen: fill ? root.mainLength(root) - root.stripInset * 2 : contentLength + root.pillPadding * 2 + root.edgePadding * 2

        function neighbour(which: string): Item {
            for (const it of root.islands)
                if (it.align === which)
                    return it;
            return null;
        }

        readonly property real mainPos: {
            const total = root.mainLength(root);
            const m = root.spec.margin;
            if (fill)
                return root.stripInset;
            if (align === "start")
                return m;
            if (align === "end")
                return total - mainLen - m;
            const ideal = Math.round((total - mainLen) / 2);
            if (root.style !== "islands")
                return ideal;
            const s = neighbour("start");
            const e = neighbour("end");
            const lo = s ? s.mainPos + s.mainLen + root.groupSpacing : m;
            const hi = (e ? e.mainPos - root.groupSpacing : total - m) - mainLen;
            return Math.max(lo, Math.min(ideal, hi));
        }
        readonly property bool fits: {
            if (align !== "center" || root.style !== "islands")
                return true;
            const e = neighbour("end");
            const hi = e ? e.mainPos - root.groupSpacing : root.mainLength(root) - root.spec.margin;
            return mainPos + mainLen <= hi + 0.5;
        }

        visible: fits
        width: root.vertical ? root.pillThickness : mainLen
        height: root.vertical ? mainLen : root.pillThickness
        x: root.vertical ? (root.edge === "left" ? root.floatGap : root.width - width - root.floatGap) : mainPos
        y: root.vertical ? mainPos : (root.edge === "top" ? root.floatGap : root.height - height - root.floatGap)

        // Own background unless an attached strip is backed by the frame or
        // the bar is clear
        // Floating, inset and island slabs carry a 1 px `rule` hairline all
        // round (Signal Bezel); an attached strip keeps the hairline on its
        // inner edge only, so it reads as a bezel, not a box.
        StyledRect {
            visible: !root.clear && (root.floating || !Config.border.frameEnabled)
            anchors.fill: parent
            color: Signal.surface(Signal.layer(Signal.palette.base, 1), "bar")
            radius: root.spec.radius >= 0 ? root.spec.radius : root.floating ? Appearance.rounding.small : 0
            border.width: root.floating ? 1 : 0
            border.color: Signal.palette.rule
        }
        Rectangle {
            visible: !root.clear && !root.floating && !Config.border.frameEnabled
            color: Signal.palette.rule
            x: root.vertical ? (root.edge === "left" ? parent.width - 1 : 0) : 0
            y: root.vertical ? 0 : (root.edge === "top" ? parent.height - 1 : 0)
            width: root.vertical ? 1 : parent.width
            height: root.vertical ? parent.height : 1
        }

        BarGroup {
            id: startGroup

            name: "start"
            active: island.modelData.groups.includes("start")
            x: root.vertical ? (island.width - width) / 2 : (island.fill ? root.edgePadding : root.pillPadding + root.edgePadding)
            y: root.vertical ? (island.fill ? root.edgePadding : root.pillPadding + root.edgePadding) : (island.height - height) / 2
        }

        BarGroup {
            id: centerGroup

            readonly property real ownLen: root.vertical ? implicitHeight : implicitWidth
            readonly property real afterStart: startGroup.visible ? (root.vertical ? startGroup.y + startGroup.height : startGroup.x + startGroup.width) + root.groupSpacing : 0
            readonly property real beforeEnd: endGroup.visible ? (root.vertical ? endGroup.y : endGroup.x) - root.groupSpacing : root.mainLength(island)
            readonly property real mainOffset: {
                if (!island.fill)
                    return afterStart > 0 ? afterStart : root.pillPadding + root.edgePadding;
                // Truly centred on the screen edge, clamped between neighbours.
                const ideal = (root.mainLength(root) - ownLen) / 2 - island.mainPos;
                return Math.max(afterStart, Math.min(ideal, beforeEnd - ownLen));
            }

            // Never draw over a neighbour: a centre group with no room left
            // between start and end hides, as islands do.
            readonly property bool hasRoom: !island.fill || beforeEnd - afterStart >= ownLen - 0.5

            name: "center"
            active: island.modelData.groups.includes("center")
            visible: active && entries.some(e => e.enabled) && hasRoom
            x: root.vertical ? (island.width - width) / 2 : mainOffset
            y: root.vertical ? mainOffset : (island.height - height) / 2
        }

        BarGroup {
            id: endGroup

            readonly property real ownLen: root.vertical ? implicitHeight : implicitWidth
            readonly property real mainOffset: {
                if (island.fill)
                    return root.mainLength(island) - root.edgePadding - ownLen;
                const prev = centerGroup.visible ? centerGroup : startGroup;
                if (!prev.visible)
                    return root.pillPadding + root.edgePadding;
                return (root.vertical ? prev.y + prev.height : prev.x + prev.width) + root.groupSpacing;
            }

            name: "end"
            active: island.modelData.groups.includes("end")
            x: root.vertical ? (island.width - width) / 2 : mainOffset
            y: root.vertical ? mainOffset : (island.height - height) / 2
        }
    }

    // A component group: typed entries laid out along the bar's main axis.
    component BarGroup: Item {
        id: group

        required property string name
        property bool active: true
        readonly property var entries: active ? (root.spec.groups[name] ?? []) : []
        readonly property alias layout: layout
        readonly property alias repeater: repeater
        // Main-axis positions of the 1 px rule between segments, in this
        // group's coordinates (signal-visual-language §4.1).
        property var separators: []

        // Reads the occupied segments in order, marks icon clusters (one
        // segment, 12 px gap, no rule inside) and rebuilds `separators`.
        function relayoutSegments(): void {
            const loaders = [];
            for (const c of layout.children)
                if (c.isSegment === true && c.visible && (root.vertical ? c.height : c.width) > 0)
                    loaders.push(c);
            loaders.sort((a, b) => a.index - b.index);
            const seps = [];
            for (let i = 0; i < loaders.length; i++) {
                const cur = loaders[i];
                const prev = i > 0 ? loaders[i - 1] : null;
                const next = i < loaders.length - 1 ? loaders[i + 1] : null;
                const joinPrev = prev !== null && root.clusterIds.includes(prev.id) && root.clusterIds.includes(cur.id);
                const joinNext = next !== null && root.clusterIds.includes(next.id) && root.clusterIds.includes(cur.id);
                if (cur.clusterPrev !== joinPrev)
                    cur.clusterPrev = joinPrev;
                if (cur.clusterNext !== joinNext)
                    cur.clusterNext = joinNext;
                if (prev && !joinPrev) {
                    const a = root.vertical ? prev.y + prev.height : prev.x + prev.width;
                    const b = root.vertical ? cur.y : cur.x;
                    seps.push((a + b) / 2);
                }
            }
            if (JSON.stringify(seps) !== JSON.stringify(group.separators))
                group.separators = seps;
        }

        Repeater {
            model: group.separators

            Rectangle {
                required property real modelData

                // 1 px `rule`, inset 8 px from the bar's cross-axis edges
                // (20 px tall in a 36 px rail).
                readonly property real inset: root.segmentInset
                x: root.vertical ? inset : modelData - 0.5
                y: root.vertical ? modelData - 0.5 : inset
                width: root.vertical ? group.width - inset * 2 : 1
                height: root.vertical ? 1 : group.height - inset * 2
                // Cockpit Clear draws no rules: nothing but the foreground.
                visible: !root.clear
                color: Signal.palette.rule
                z: -1
            }
        }

        visible: active && entries.some(e => e.enabled)
        onXChanged: root.pokeInk()
        onYChanged: root.pokeInk()
        implicitWidth: layout.implicitWidth
        implicitHeight: layout.implicitHeight
        width: implicitWidth
        height: implicitHeight

        GridLayout {
            id: layout

            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.vertical ? -1 : 1
            columns: root.vertical ? 1 : -1
            // Spacing lives in each segment's own padding (§4.1).
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                id: repeater

                model: group.entries

                DelegateChooser {
                    role: "id"

                    DelegateChoice {
                        roleValue: "logo"
                        delegate: WrappedLoader {
                            sourceComponent: OsIcon {}
                        }
                    }
                    DelegateChoice {
                        roleValue: "workspaces"
                        delegate: WrappedLoader {
                            id: workspacesLoader

                            sourceComponent: Workspaces {
                                screen: root.screen
                                vertical: root.vertical
                                edge: root.edge
                                options: workspacesLoader.options
                                clear: root.clear
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "activeWindow"
                        delegate: WrappedLoader {
                            sourceComponent: ActiveWindow {
                                bar: root
                                monitor: Brightness.getMonitorForScreen(root.screen)
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "tray"
                        delegate: WrappedLoader {
                            sourceComponent: Tray {
                                screen: root.screen
                                vertical: root.vertical
                                clear: root.clear
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "extensions"
                        delegate: WrappedLoader {
                            sourceComponent: ExtensionsIsland {
                                screen: root.screen
                                vertical: root.vertical
                                clear: root.clear
                                fallbackSections: ["status", "actions", "clock"].filter(s => !root.presentSections.includes(s))
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "clock"
                        delegate: WrappedLoader {
                            id: clockLoader

                            sourceComponent: Clock {
                                screen: root.screen
                                vertical: root.vertical
                                options: clockLoader.options
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "statusIcons"
                        delegate: WrappedLoader {
                            sourceComponent: StatusIcons {
                                screen: root.screen
                                vertical: root.vertical
                                clear: root.clear
                                onPopoutRequested: (name, anchor) => root.openStatusPopout(name, anchor)
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "audioSlider"
                        delegate: WrappedLoader {
                            id: audioLoader

                            sourceComponent: InlineSlider {
                                screen: root.screen
                                kind: "audio"
                                options: audioLoader.options
                                compact: root.compact
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "brightnessSlider"
                        delegate: WrappedLoader {
                            id: brightnessLoader

                            sourceComponent: InlineSlider {
                                screen: root.screen
                                kind: "brightness"
                                options: brightnessLoader.options
                                compact: root.compact
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "media"
                        delegate: WrappedLoader {
                            id: mediaLoader

                            sourceComponent: Media {
                                vertical: root.vertical
                                options: mediaLoader.options
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "resources"
                        delegate: WrappedLoader {
                            id: resourcesLoader

                            sourceComponent: Resources {
                                vertical: root.vertical
                                compact: root.compact
                                density: Experience.barDensity(root.spec.density)
                                options: resourcesLoader.options
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "kbLayout"
                        delegate: WrappedLoader {
                            sourceComponent: KbLayout {
                                vertical: root.vertical
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "modeIndicator"
                        delegate: WrappedLoader {
                            id: modeLoader

                            sourceComponent: ModeIndicator {
                                vertical: root.vertical
                                options: modeLoader.options
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "javiRadio"
                        delegate: WrappedLoader {
                            sourceComponent: RadioButton {
                                vertical: root.vertical
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "weather"
                        delegate: WrappedLoader {
                            sourceComponent: WeatherChip {
                                vertical: root.vertical
                                density: Experience.barDensity(root.spec.density)
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "pinnedApps"
                        delegate: WrappedLoader {
                            id: pinnedLoader

                            sourceComponent: PinnedApps {
                                vertical: root.vertical
                                options: pinnedLoader.options
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "quickActions"
                        delegate: WrappedLoader {
                            id: actionsLoader

                            sourceComponent: QuickActions {
                                vertical: root.vertical
                                options: actionsLoader.options
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "battery"
                        delegate: WrappedLoader {
                            sourceComponent: Battery {
                                vertical: root.vertical
                                density: Experience.barDensity(root.spec.density)
                            }
                        }
                    }
                    DelegateChoice {
                        roleValue: "power"
                        delegate: WrappedLoader {
                            sourceComponent: Power {
                                visibilities: root.visibilities
                            }
                        }
                    }
                }
            }

            // Community plugins with placement "bar" render at the end
            // of the end group, each in its own Loader (fault-isolated
            // through the Plugins service). Empty when none are enabled.
            // Layouts without an "extensions" entry get the same tray-like
            // island here (shell#441), never a bare stack of indicators,
            // so bar.extensions.* applies in every layout.
            ExtensionsIsland {
                Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter

                screen: root.screen
                vertical: root.vertical
                surfaceActive: group.name === "end" && !root.presentSections.includes("end")
                // Islands missing from this layout (shell#439): their
                // extension indicators render here rather than nowhere.
                fallbackSections: ["status", "actions", "clock"].filter(s => !root.presentSections.includes(s))
                // Responsive host context (#372), forwarded to the
                // island's plugin hosts.
                hostEdge: root.edge
                hostThickness: root.spec.thickness
                hostCompact: root.compact
                hostScreenName: root.screen.name
            }
        }
    }

    component WrappedLoader: Loader {
        id: wrapped

        required property bool enabled
        required property string id
        required property int index
        required property var options

        // Cockpit Clear: the tone of the wallpaper region under this entry.
        readonly property ClearInkTone regionTone: ClearInkTone {
            field: inkField
            target: wrapped
        }
        readonly property var tone: root.clear ? wrapped.regionTone : ClearInk.neutral

        // Segment: the unit of composition. Padding sits on the loader so
        // the layout needs no spacing; an icon cluster halves it between
        // its members (12 px gap in total).
        readonly property bool isSegment: true
        property bool clusterPrev: false
        property bool clusterNext: false
        readonly property real leadPad: wrapped.clusterPrev ? root.segmentPadding / 2 : root.segmentPadding
        readonly property real trailPad: wrapped.clusterNext ? root.segmentPadding / 2 : root.segmentPadding
        readonly property var segmentGroup: wrapped.parent?.parent ?? null

        Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        Layout.leftMargin: root.vertical ? 0 : wrapped.leadPad
        Layout.rightMargin: root.vertical ? 0 : wrapped.trailPad
        Layout.topMargin: root.vertical ? wrapped.leadPad : 0
        Layout.bottomMargin: root.vertical ? wrapped.trailPad : 0
        // Entries that can report there is nothing to show (e.g. a brightness
        // slider on a monitor without a backlight) leave the bar entirely.
        readonly property bool contentAvailable: item?.available ?? true
        visible: enabled && contentAvailable
        active: enabled

        // Glyph/text-only halo and shadow (never a box): the dilated
        // silhouette of the loaded entry, painted beneath it. Pixels more
        // than the tone's radius away from foreground stay transparent.
        ShaderEffect {
            id: halo

            readonly property var fx: wrapped.regionTone.effect
            readonly property real pad: halo.fx.pad
            property var source: haloSource
            property color haloOnLight: wrapped.regionTone.haloOnLight
            property color haloOnDark: wrapped.regionTone.haloOnDark
            property size texel: Qt.size(1 / Math.max(1, width), 1 / Math.max(1, height))
            property real outlinePx: halo.fx.outlinePx
            property real shadowPx: halo.fx.shadowPx
            property real haloAlpha: halo.fx.alpha
            property real shadowAlpha: halo.fx.shadowAlpha
            property real shadowDy: halo.fx.shadowDy

            visible: root.clear && wrapped.item !== null && halo.fx.enabled
            x: -halo.pad
            y: -halo.pad
            z: -1
            width: wrapped.width + halo.pad * 2
            height: wrapped.height + halo.pad * 2
            fragmentShader: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/shaders/clearinkhalo.frag.qsb`)

            ShaderEffectSource {
                id: haloSource

                sourceItem: wrapped.item
                sourceRect: Qt.rect(-halo.pad, -halo.pad, halo.width, halo.height)
                hideSource: false
                live: true
                visible: false
            }
        }

        onLoaded: {
            if (item && item.tone !== undefined)
                item.tone = Qt.binding(() => wrapped.tone);
        }
        onXChanged: wrapped.segmentChanged()
        onYChanged: wrapped.segmentChanged()
        onWidthChanged: wrapped.segmentChanged()
        onHeightChanged: wrapped.segmentChanged()
        onVisibleChanged: wrapped.segmentChanged()
        Component.onCompleted: wrapped.segmentChanged()

        function segmentChanged(): void {
            root.pokeInk();
            if (wrapped.segmentGroup?.relayoutSegments)
                wrapped.segmentGroup.relayoutSegments();
        }
    }
}
