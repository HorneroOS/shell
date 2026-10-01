pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

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
    // Clear backdrop: no slab, no frame strip; a soft scrim keeps the
    // components legible on any wallpaper.
    readonly property bool clear: spec.backdrop === "clear"
    // Narrow horizontal bars (laptop panels, split screens) tighten wide
    // components instead of letting groups collide. A width breakpoint, not
    // a content measurement, so compacting can never feed back into itself.
    readonly property bool compact: !vertical && width > 0 && width < 1500
    readonly property int edgePadding: Appearance.padding.large
    readonly property int barPadding: Math.max(Appearance.padding.smaller, Config.border.thickness)
    // Cross-axis thickness of a pill (excludes the float gap)
    readonly property int pillThickness: spec.thickness + barPadding * 2
    readonly property int pillPadding: floating ? Appearance.padding.normal : 0
    readonly property real floatGap: floating ? spec.margin : 0
    // Main-axis inset of strips: inset bars keep the float gap at both ends
    readonly property real stripInset: style === "inset" ? spec.margin : 0
    readonly property int groupSpacing: Appearance.spacing.large
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
    // siblings through this (legacy name: the single GridLayout).
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

    function resetPopout(): void {
        popouts.hasCurrent = false;
        popouts.currentName = "";
        popouts.currentCenter = 0;
        closeTray();
    }

    function claimPopouts(): void {
        popouts.ownerEdge = root.edge;
        popouts.ownerStyle = root.style;
        popouts.ownerBackdrop = root.spec.backdrop;
    }

    function centerBinding(ref: Item, len: real): var {
        return Qt.binding(() => {
            try {
                if (!ref || typeof ref.mapToItem !== "function")
                    return 0;
                return root.vertical ? ref.mapToItem(null, 0, (len > 0 ? len : ref.implicitHeight) / 2).y : ref.mapToItem(null, (len > 0 ? len : ref.implicitWidth) / 2, 0).x;
            } catch (e) {
                return 0;
            }
        });
    }

    // Popout trigger at a bar-local point.
    function checkPopoutAt(lx: real, ly: real): void {
        try {
            const hit = entryAt(lx, ly);
            const ch = hit?.loader ?? null;

            if (ch?.id !== "tray")
                closeTray();

            if (!ch) {
                popouts.hasCurrent = false;
                return;
            }

            const id = ch.id;
            const item = ch.item;
            const axisPos = vertical ? hit.pt.y : hit.pt.x;
            const start = vertical ? ch.y : ch.x;
            const itemLength = vertical ? item.implicitHeight : item.implicitWidth;

            if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
                const items = item?.items;
                if (!items || typeof items.childAt !== "function")
                    return;
                const mapped = root.mapToItem(items, lx, ly);
                const icon = vertical ? items.childAt(items.width / 2, mapped.y) : items.childAt(mapped.x, items.height / 2);
                if (icon) {
                    claimPopouts();
                    popouts.currentName = icon.name;
                    popouts.currentCenter = centerBinding(icon, 0);
                    popouts.hasCurrent = true;
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
                    if (trayItem) {
                        claimPopouts();
                        popouts.currentName = `traymenu${index}`;
                        popouts.currentCenter = centerBinding(trayItem, 0);
                        popouts.hasCurrent = true;
                    } else {
                        popouts.hasCurrent = false;
                    }
                } else {
                    popouts.hasCurrent = false;
                    item.expanded = true;
                }
            } else if (id === "activeWindow" && Config.bar.popouts.activeWindow) {
                if (!item)
                    return;
                claimPopouts();
                popouts.currentName = id.toLowerCase();
                popouts.currentCenter = centerBinding(item, itemLength);
                popouts.hasCurrent = true;
            }
        } catch (e) {
            // During layout transitions the bar items may be temporarily undefined
            popouts.hasCurrent = false;
        }
    }

    function handleWheelAt(lx: real, ly: real, angleDelta: point): void {
        const ch = entryAt(lx, ly)?.loader ?? null;
        const pos = vertical ? ly : lx;
        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
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
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + Config.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - Config.services.brightnessIncrement);
        }
    }

    onSpecChanged: resetPopout()

    // Edge scrim for clear bars: holds its tone across the component band
    // (where the glyphs sit) and fades out past it, a vignette rather than
    // a slab. Strength follows the bar's transparency element so users can
    // soften or remove it from Appearance.
    Rectangle {
        id: scrim

        readonly property bool fromStart: root.edge === "top" || root.edge === "left"

        visible: root.clear
        anchors.fill: parent
        opacity: 0.62 * Colours.elementAlpha("bar")

        gradient: Gradient {
            orientation: root.vertical ? Gradient.Horizontal : Gradient.Vertical

            GradientStop {
                position: 0
                color: scrim.fromStart ? Colours.palette.m3surface : "transparent"
            }
            GradientStop {
                position: scrim.fromStart ? 0.65 : 0.35
                color: Colours.palette.m3surface
            }
            GradientStop {
                position: 1
                color: scrim.fromStart ? "transparent" : Colours.palette.m3surface
            }
        }
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
                if (g.visible) {
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
        // Clear bars: a soft halo in the surface colour behind every glyph,
        // so text stays legible on any wallpaper/scheme combination.
        layer.enabled: root.clear
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Colours.palette.m3surface
            shadowBlur: 1
            shadowOpacity: 1
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
        }
        width: root.vertical ? root.pillThickness : mainLen
        height: root.vertical ? mainLen : root.pillThickness
        x: root.vertical ? (root.edge === "left" ? root.floatGap : root.width - width - root.floatGap) : mainPos
        y: root.vertical ? mainPos : (root.edge === "top" ? root.floatGap : root.height - height - root.floatGap)

        // Own background unless an attached strip is backed by the frame or
        // the bar is clear
        StyledRect {
            visible: !root.clear && (root.floating || !Config.border.frameEnabled)
            anchors.fill: parent
            color: Colours.surface(Colours.layer(Colours.palette.m3surface, 1), "bar")
            radius: root.floating ? Appearance.rounding.full : 0
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

        visible: active && entries.some(e => e.enabled)
        implicitWidth: layout.implicitWidth
        implicitHeight: layout.implicitHeight
        width: implicitWidth
        height: implicitHeight

        GridLayout {
            id: layout

            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rows: root.vertical ? -1 : 1
            columns: root.vertical ? 1 : -1
            rowSpacing: Appearance.spacing.normal
            columnSpacing: Appearance.spacing.normal

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
                                density: root.spec.density
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
                        roleValue: "weather"
                        delegate: WrappedLoader {
                            sourceComponent: WeatherChip {
                                vertical: root.vertical
                                density: root.spec.density
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
                                density: root.spec.density
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
        }
    }

    component WrappedLoader: Loader {
        required property bool enabled
        required property string id
        required property int index
        required property var options

        Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: enabled
        active: enabled
    }
}
