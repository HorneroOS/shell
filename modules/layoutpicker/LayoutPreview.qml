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
    property bool highlighted: false

    // Normalised topology: [{edge, style, backdrop, reserve, groups}]
    readonly property var topology: {
        // QML hands var lists over as QVariantList (Array.isArray is false).
        const src = Array.from(bars ?? []);
        // Group sizes as counts: horneroctl sends numbers; raw preset groups
        // (arrays of {id, enabled}) count their enabled entries.
        const count = v => typeof v === "number" ? v : (v && v.length !== undefined ? Array.from(v).filter(e => e && e.enabled !== false && e.id !== "spacer").length : 0);
        return src.map(b => ({
                    edge: b.edge ?? "left",
                    style: b.style ?? "attached",
                    backdrop: b.backdrop ?? "solid",
                    reserve: typeof b.reserve === "boolean" ? b.reserve : (b.style === "attached" || b.style === "inset" || b.style === "dock"),
                    groups: {
                        start: count(b.groups?.start),
                        center: count(b.groups?.center),
                        end: count(b.groups?.end)
                    }
                }));
    }

    // Preview metrics (px): bar thickness, inset margin, dot size/pitch.
    readonly property real barT: 9
    readonly property real dockT: 12
    readonly property real gapM: 4
    readonly property real dot: 3
    readonly property real pitch: 6

    function barOn(edge: string): var {
        return topology.find(b => b.edge === edge) ?? null;
    }

    function stripDepth(b: var): real {
        if (!b)
            return 0;
        const t = b.style === "dock" ? dockT : barT;
        return b.style === "attached" ? t : t + gapM;
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
                color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 1)
            }
            GradientStop {
                position: 1
                color: Colours.layer(Colours.palette.m3secondaryContainer, 1)
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
                    color: Colours.layer(Colours.palette.m3surface, 2)
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outline, 0.35)

                    // Title line
                    StyledRect {
                        x: 4
                        y: 4
                        width: parent.width * 0.4
                        height: 2
                        radius: 1
                        color: Qt.alpha(Colours.palette.m3onSurfaceVariant, 0.35)
                    }
                }
            }
        }

        Repeater {
            model: root.topology

            Bar {}
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
        readonly property real t: style === "dock" ? root.dockT : root.barT
        readonly property real m: style === "attached" ? 0 : root.gapM
        readonly property var g: modelData.groups
        readonly property int total: (g.start ?? 0) + (g.center ?? 0) + (g.end ?? 0)
        readonly property real topSkip: vertical ? root.stripDepth(root.barOn("top")) : 0
        readonly property real bottomSkip: vertical ? root.stripDepth(root.barOn("bottom")) : 0
        // Main-axis length of the edge this bar lives on
        readonly property real edgeLen: vertical ? screen.height - topSkip - bottomSkip : screen.width

        function groupLen(n: int): real {
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
            const content = Math.min(L * 0.7, groupLen(total) + 10);
            if (style === "attached")
                return [{pos: 0, len: L, groups: ["start", "center", "end"]}];
            if (style === "inset")
                return [{pos: root.gapM, len: L - root.gapM * 2, groups: ["start", "center", "end"]}];
            if (style === "islands") {
                const out = [];
                if ((g.start ?? 0) > 0)
                    out.push({pos: root.gapM, len: groupLen(g.start) + 4, groups: ["start"]});
                if ((g.center ?? 0) > 0) {
                    const len = groupLen(g.center) + 4;
                    out.push({pos: (L - len) / 2, len: len, groups: ["center"]});
                }
                if ((g.end ?? 0) > 0) {
                    const len = groupLen(g.end) + 4;
                    out.push({pos: L - len - root.gapM, len: len, groups: ["end"]});
                }
                return out;
            }
            return [{pos: (L - content) / 2, len: content, groups: ["start", "center", "end"], packed: true}];
        }

        Repeater {
            model: bar.pills

            StyledRect {
                id: pill

                required property var modelData

                readonly property bool packed: modelData.packed === true

                x: bar.vertical ? 0 : modelData.pos
                y: bar.vertical ? modelData.pos : 0
                width: bar.vertical ? bar.t : modelData.len
                height: bar.vertical ? modelData.len : bar.t
                radius: bar.style === "attached" ? 0 : Appearance.rounding.full
                color: bar.clear ? "transparent" : Qt.alpha(Colours.palette.m3primary, root.highlighted ? 0.95 : 0.8)

                // Component dots per group: packed pills lay groups end to
                // end; strips/islands align them start/center/end.
                Repeater {
                    model: pill.modelData.groups

                    Item {
                        id: grp

                        required property string modelData
                        required property int index

                        readonly property int n: Math.min(8, bar.g[modelData] ?? 0)
                        readonly property real len: n * root.pitch
                        readonly property real along: {
                            const L = bar.vertical ? pill.height : pill.width;
                            if (pill.packed) {
                                let off = 5;
                                const order = ["start", "center", "end"];
                                for (let i = 0; i < order.indexOf(modelData); i++)
                                    off += bar.groupLen(Math.min(8, bar.g[order[i]] ?? 0));
                                return off;
                            }
                            if (modelData === "start")
                                return 4;
                            if (modelData === "end")
                                return L - len - 4 + root.pitch - root.dot;
                            return (L - len) / 2;
                        }

                        x: bar.vertical ? (bar.t - root.dot) / 2 : along
                        y: bar.vertical ? along : (bar.t - root.dot) / 2

                        Repeater {
                            model: grp.n

                            Rectangle {
                                required property int index

                                x: bar.vertical ? 0 : index * root.pitch
                                y: bar.vertical ? index * root.pitch : 0
                                width: root.dot
                                height: root.dot
                                radius: root.dot / 2
                                color: bar.clear ? Colours.palette.m3primary : Colours.palette.m3onPrimary
                                opacity: grp.modelData === "center" ? 1 : 0.85
                            }
                        }
                    }
                }
            }
        }
    }
}
