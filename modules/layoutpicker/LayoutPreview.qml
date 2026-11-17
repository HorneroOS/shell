pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick

// Miniature desktop for one layout preset: every bar of the preset's
// topology (`bars` from `horneroctl shell preset list --full`) drawn in its
// style — strip, inset strip, floating pill, three islands, dock, clear —
// with one dot per enabled component at start/center/end, plus two windows
// filling the work area the bars leave (so reserving vs overlaying shows).
// Theme tokens only, so it follows Dark/Light/Pampa.
Item {
    id: root

    property var bars: []
    // Raw preset bars (`bar.bars` of the preset JSON: thickness, margin and the
    // entry ids of every group). When present the miniature is drawn from the
    // real geometry and components; otherwise from the CLI's group counts.
    property var specs: []
    property bool highlighted: false

    // Normalised topology: [{edge, style, backdrop, reserve, groups}]
    readonly property var topology: {
        // QML hands var lists over as QVariantList (Array.isArray is false).
        const src = Array.from(bars ?? []);
        // Group sizes as counts: horneroctl sends numbers; raw preset groups
        // (arrays of {id, enabled}) count their enabled entries.
        const count = v => typeof v === "number" ? v : (v && v.length !== undefined ? Array.from(v).filter(e => e && e.enabled !== false && e.id !== "spacer").length : 0);
        const raw = Array.from(specs ?? []);
        const ids = (b, name) => b ? Array.from(b.groups?.[name] ?? []).filter(e => e && e.enabled !== false && e.id !== "spacer").map(e => e.id) : [];
        return src.map(b => ({
                    spec: raw.find(r => r.edge === b.edge) ?? null,
                    edge: b.edge ?? "left",
                    style: b.style ?? "attached",
                    backdrop: b.backdrop ?? "solid",
                    reserve: typeof b.reserve === "boolean" ? b.reserve : (b.style === "attached" || b.style === "inset" || b.style === "dock"),
                    groups: {
                        start: count(b.groups?.start),
                        center: count(b.groups?.center),
                        end: count(b.groups?.end)
                    },
                    entries: (() => {
                            const r = raw.find(x => x.edge === b.edge) ?? null;
                            return {start: ids(r, "start"), center: ids(r, "center"), end: ids(r, "end")};
                        })()
                }));
    }

    // Preview metrics (px): bar thickness, inset margin, dot size/pitch.
    // The miniature is 0.26 of the real bar (clamped), margin 0.5.
    readonly property real barT: 9
    readonly property real dockT: 12
    readonly property real gapM: 4
    readonly property real dot: 3
    readonly property real pitch: 6

    function thicknessOf(b: var): real {
        const th = b?.spec?.thickness;
        if (typeof th !== "number")
            return b?.style === "dock" ? dockT : barT;
        return Math.max(6, Math.min(14, Math.round(th * 0.26)));
    }

    function marginOf(b: var): real {
        const mg = b?.spec?.margin;
        if (b?.style === "attached")
            return 0;
        return typeof mg === "number" ? Math.max(2, Math.min(6, Math.round(mg * 0.5))) : gapM;
    }

    // Shape of one bar entry in the miniature: along-axis length and kind.
    function shapeOf(id: string): var {
        switch (id) {
        case "logo":
            return {len: 4, kind: "mark"};
        case "workspaces":
            return {len: 22, kind: "cells"};
        case "clock":
            return {len: 14, kind: "clock"};
        case "weather":
            return {len: 7, kind: "dots"};
        case "activeWindow":
        case "media":
            return {len: 18, kind: "title"};
        case "audioSlider":
        case "brightnessSlider":
            return {len: 13, kind: "track"};
        case "resources":
            return {len: 17, kind: "meters"};
        case "pinnedApps":
            return {len: 20, kind: "tiles"};
        case "power":
            return {len: 4, kind: "dot"};
        default:
            return {len: 11, kind: "dots"};
        }
    }

    function barOn(edge: string): var {
        return topology.find(b => b.edge === edge) ?? null;
    }

    function stripDepth(b: var): real {
        if (!b)
            return 0;
        const t = thicknessOf(b);
        return b.style === "attached" ? t : t + marginOf(b);
    }

    function reserved(edge: string): real {
        const b = barOn(edge);
        return b && b.reserve ? stripDepth(b) : 0;
    }

    implicitWidth: 188
    implicitHeight: 110

    // Wallpaper
    StyledRect {
        id: screen

        anchors.fill: parent
        radius: Appearance.rounding.small
        clip: true
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Signal.layer(Signal.palette.lifted, 1)
            }
            GradientStop {
                position: 1
                color: Signal.layer(Signal.palette.cueWell, 1)
            }
        }

        // Work area: two tiled windows inside what the bars reserve
        Item {
            id: work

            x: root.reserved("left") + 5
            y: root.reserved("top") + 5
            width: parent.width - x - root.reserved("right") - 5
            height: parent.height - y - root.reserved("bottom") - 5

            Repeater {
                model: 2

                StyledRect {
                    required property int index

                    x: index === 0 ? 0 : work.width * 0.55 + 3
                    y: 0
                    width: index === 0 ? work.width * 0.55 : work.width * 0.45 - 3
                    height: work.height
                    radius: 3
                    color: Signal.layer(Signal.palette.base, 2)
                    border.width: 1
                    border.color: Qt.alpha(Signal.palette.ruleStrong, 0.35)

                    // Title line
                    StyledRect {
                        x: 4
                        y: 4
                        width: parent.width * 0.4
                        height: 2
                        radius: 1
                        color: Qt.alpha(Signal.palette.inkMuted, 0.35)
                    }
                }
            }
        }

        Repeater {
            model: root.topology

            Bar {}
        }

        StyledRect {
            anchors.fill: parent
            visible: root.topology.length === 0
            color: Signal.layer(Signal.palette.base, 2)

            StyledText {
                anchors.centerIn: parent
                text: qsTr("Preview unavailable")
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.smaller
            }
        }
    }

    // One bar of the topology, positioned on its edge. Horizontal bars span
    // the width; vertical bars sit between them, as in the shell.
    component Bar: Item {
        id: bar

        required property var modelData

        readonly property bool vertical: modelData.edge === "left" || modelData.edge === "right"
        readonly property string style: modelData.style
        readonly property bool clear: modelData.backdrop === "clear"
        readonly property real t: root.thicknessOf(modelData)
        readonly property real m: root.marginOf(modelData)
        readonly property var g: modelData.groups
        readonly property var entries: modelData.entries
        readonly property bool hasSpec: modelData.spec !== null
        readonly property int total: (g.start ?? 0) + (g.center ?? 0) + (g.end ?? 0)
        readonly property real topSkip: vertical ? root.stripDepth(root.barOn("top")) : 0
        readonly property real bottomSkip: vertical ? root.stripDepth(root.barOn("bottom")) : 0
        // Main-axis length of the edge this bar lives on
        readonly property real edgeLen: vertical ? screen.height - topSkip - bottomSkip : screen.width

        // Along-axis length of one group: real entries when the preset JSON
        // is known, otherwise the CLI's component count.
        function groupLen(name: string): real {
            if (hasSpec) {
                const ids = entries[name] ?? [];
                return ids.length > 0 ? ids.reduce((n, id) => n + root.shapeOf(id).len + 4, 0) : 0;
            }
            const n = Math.min(8, g[name] ?? 0);
            return n > 0 ? n * root.pitch + root.pitch : 0;
        }

        x: vertical ? (modelData.edge === "left" ? m : screen.width - t - m) : 0
        y: vertical ? topSkip : (modelData.edge === "top" ? m : screen.height - t - m)
        width: vertical ? t : screen.width
        height: vertical ? edgeLen : t

        // Pills: strips are one full-length pill (inset trims the ends),
        // floating/dock one content-sized centred pill, islands one per group.
        readonly property var pills: {
            const L = edgeLen;
            const content = Math.min(L * 0.92, groupLen("start") + groupLen("center") + groupLen("end") + 10);
            if (style === "attached")
                return [{pos: 0, len: L, groups: ["start", "center", "end"]}];
            if (style === "inset")
                return [{pos: root.gapM, len: L - root.gapM * 2, groups: ["start", "center", "end"]}];
            if (style === "islands") {
                const out = [];
                for (const name of ["start", "center", "end"]) {
                    const n = groupLen(name);
                    if (n <= 0)
                        continue;
                    const len = n + 6;
                    out.push({pos: name === "start" ? root.gapM : name === "center" ? (L - len) / 2 : L - len - root.gapM, len: len, groups: [name]});
                }
                return out;
            }
            return [{pos: (L - content) / 2, len: content, groups: ["start", "center", "end"], packed: true}];
        }

        Repeater {
            model: bar.pills

            // Slab: `base` with a 1 px hairline, as the real bar (Signal Bezel).
            StyledRect {
                id: pill

                required property var modelData

                readonly property bool packed: modelData.packed === true

                x: bar.vertical ? 0 : modelData.pos
                y: bar.vertical ? modelData.pos : 0
                width: bar.vertical ? bar.t : modelData.len
                height: bar.vertical ? modelData.len : bar.t
                radius: bar.style === "attached" ? 0 : 2
                color: bar.clear ? "transparent" : Signal.layer(Signal.palette.base, 1)
                border.width: bar.clear || bar.style === "attached" ? 0 : 1
                border.color: root.highlighted ? Signal.palette.ruleStrong : Signal.palette.rule

                // Components per group: packed pills lay groups end to end;
                // strips and islands align them start/center/end.
                Repeater {
                    model: pill.modelData.groups

                    Item {
                        id: grp

                        required property string modelData
                        required property int index

                        readonly property var ids: bar.hasSpec ? (bar.entries[modelData] ?? []) : []
                        readonly property real len: bar.groupLen(modelData)
                        readonly property real along: {
                            const L = bar.vertical ? pill.height : pill.width;
                            if (pill.packed) {
                                let off = 5;
                                const order = ["start", "center", "end"];
                                for (let i = 0; i < order.indexOf(modelData); i++)
                                    off += bar.groupLen(order[i]);
                                return off;
                            }
                            if (modelData === "start")
                                return 4;
                            if (modelData === "end")
                                return L - len - 4;
                            return (L - len) / 2;
                        }

                        x: bar.vertical ? 0 : along
                        y: bar.vertical ? along : 0
                        width: bar.vertical ? bar.t : len
                        height: bar.vertical ? len : bar.t

                        // Count fallback: one muted dot per component.
                        Repeater {
                            model: bar.hasSpec ? 0 : Math.min(8, bar.g[grp.modelData] ?? 0)

                            Rectangle {
                                required property int index

                                x: bar.vertical ? (bar.t - root.dot) / 2 : index * root.pitch
                                y: bar.vertical ? index * root.pitch : (bar.t - root.dot) / 2
                                width: root.dot
                                height: root.dot
                                radius: 1
                                color: bar.clear ? Signal.palette.ink : Signal.palette.inkMuted
                            }
                        }

                        // Real entries, each with its own silhouette.
                        Item {
                            id: entryRow

                            readonly property var offsets: {
                                let o = 0;
                                const out = [];
                                for (const id of grp.ids) {
                                    out.push(o);
                                    o += root.shapeOf(id).len + 4;
                                }
                                return out;
                            }

                            Repeater {
                                model: grp.ids

                                Item {
                                    id: ent

                                    required property string modelData
                                    required property int index

                                    readonly property var shape: root.shapeOf(modelData)
                                    readonly property color ink: bar.clear ? Signal.palette.ink : Signal.palette.inkMuted

                                    x: bar.vertical ? 0 : entryRow.offsets[index]
                                    y: bar.vertical ? entryRow.offsets[index] : 0
                                    width: bar.vertical ? bar.t : shape.len
                                    height: bar.vertical ? shape.len : bar.t

                                    // Mark: the one amber dot.
                                    Rectangle {
                                        visible: ent.shape.kind === "mark"
                                        anchors.centerIn: parent
                                        width: 4
                                        height: 4
                                        radius: 2
                                        color: Signal.palette.signal
                                    }
                                    // Workspace cells: small squares, the first active.
                                    Repeater {
                                        model: ent.shape.kind === "cells" ? 5 : 0

                                        Rectangle {
                                            required property int index

                                            x: bar.vertical ? (ent.width - width) / 2 : index * 4.4
                                            y: bar.vertical ? index * 4.4 : (ent.height - height) / 2
                                            width: 3
                                            height: 3
                                            color: index === 0 ? Signal.palette.ink : ent.ink
                                            opacity: index === 0 ? 1 : 0.6

                                            Rectangle {
                                                visible: parent.index === 0
                                                x: bar.vertical ? parent.width + 0.5 : 0
                                                y: bar.vertical ? 0 : parent.height + 0.5
                                                width: bar.vertical ? 1 : parent.width
                                                height: bar.vertical ? parent.height : 1
                                                color: Signal.palette.signal
                                            }
                                        }
                                    }
                                    // Clock: one solid ink block (taller than the rest).
                                    Rectangle {
                                        visible: ent.shape.kind === "clock"
                                        anchors.centerIn: parent
                                        width: bar.vertical ? 3 : ent.shape.len - 2
                                        height: bar.vertical ? ent.shape.len - 2 : 3
                                        radius: 1
                                        color: Signal.palette.ink
                                    }
                                    // Title / media: a long muted line.
                                    Rectangle {
                                        visible: ent.shape.kind === "title"
                                        anchors.centerIn: parent
                                        width: bar.vertical ? 2 : ent.shape.len - 2
                                        height: bar.vertical ? ent.shape.len - 2 : 2
                                        color: ent.ink
                                        opacity: 0.7
                                    }
                                    // Slider track with its thumb.
                                    Rectangle {
                                        visible: ent.shape.kind === "track"
                                        anchors.centerIn: parent
                                        width: bar.vertical ? 1 : ent.shape.len - 2
                                        height: bar.vertical ? ent.shape.len - 2 : 1
                                        color: ent.ink
                                        Rectangle {
                                            x: bar.vertical ? -1 : parent.width * 0.4
                                            y: bar.vertical ? parent.height * 0.4 : -1
                                            width: bar.vertical ? 3 : 2
                                            height: bar.vertical ? 2 : 3
                                            color: Signal.palette.ink
                                        }
                                    }
                                    // Resource meters: three short bars.
                                    Repeater {
                                        model: ent.shape.kind === "meters" ? 3 : 0

                                        Rectangle {
                                            required property int index

                                            x: bar.vertical ? (ent.width - width) / 2 : index * 6
                                            y: bar.vertical ? index * 6 : (ent.height - height) / 2
                                            width: bar.vertical ? 4 : 4
                                            height: bar.vertical ? 1.5 : 1.5
                                            color: ent.ink
                                        }
                                    }
                                    // App tiles.
                                    Repeater {
                                        model: ent.shape.kind === "tiles" ? 3 : 0

                                        Rectangle {
                                            required property int index

                                            x: bar.vertical ? (ent.width - width) / 2 : index * 6.5
                                            y: bar.vertical ? index * 6.5 : (ent.height - height) / 2
                                            width: Math.min(5, bar.t - 3)
                                            height: width
                                            radius: 1
                                            color: ent.ink
                                            opacity: 0.8
                                        }
                                    }
                                    // Status / tray / actions: a row of dots.
                                    Repeater {
                                        model: ent.shape.kind === "dots" ? Math.max(2, Math.round(ent.shape.len / 4)) : 0

                                        Rectangle {
                                            required property int index

                                            x: bar.vertical ? (ent.width - root.dot) / 2 : index * 4
                                            y: bar.vertical ? index * 4 : (ent.height - root.dot) / 2
                                            width: root.dot
                                            height: root.dot
                                            radius: 1.5
                                            color: ent.ink
                                        }
                                    }
                                    // Power: a single muted dot.
                                    Rectangle {
                                        visible: ent.shape.kind === "dot"
                                        anchors.centerIn: parent
                                        width: root.dot
                                        height: root.dot
                                        radius: 1.5
                                        color: ent.ink
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
