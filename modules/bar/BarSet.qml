pragma ComponentBehavior: Bound

import qs.config
import "popouts" as BarPopouts
import Quickshell
import QtQuick

// The screen's bars (Config.bar.barsFor): at most one per edge, all inside
// the one input-owning drawers window. Exposes the aggregate the drawers
// modules consume (per-edge margins and reservations, hit testing, popout
// and wheel dispatch) so they stay agnostic of how many bars exist.
Item {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    required property bool disabled
    required property bool frameVisible

    readonly property var specs: Config.bar.barsFor(screen.name)
    readonly property int frameInset: frameVisible ? Config.border.thickness : 0
    property bool isHovered

    readonly property list<Item> bars: {
        const out = [];
        for (let i = 0; i < repeater.count; i++) {
            const b = repeater.itemAt(i);
            if (b)
                out.push(b);
        }
        return out;
    }
    readonly property Item primary: bars.length > 0 ? bars[0] : null

    // Legacy single-bar view (primary bar) for consumers that need one edge.
    readonly property string position: primary?.position ?? "left"
    readonly property bool vertical: primary?.vertical ?? true
    readonly property bool floating: primary?.floating ?? false
    readonly property int thickness: primary?.thickness ?? 0
    readonly property int currentThickness: primary?.currentThickness ?? 0
    readonly property bool shouldBeVisible: bars.some(b => b.shouldBeVisible)
    readonly property Item visualItem: primary?.visualItem ?? null
    readonly property real visualX: primary?.visualX ?? 0
    readonly property real visualY: primary?.visualY ?? 0
    readonly property real visualWidth: primary?.visualWidth ?? 0
    readonly property real visualHeight: primary?.visualHeight ?? 0

    // Panels avoid every visible bar; reservations add up per edge.
    readonly property int marginLeft: bars.reduce((m, b) => Math.max(m, b.marginLeft), frameInset)
    readonly property int marginRight: bars.reduce((m, b) => Math.max(m, b.marginRight), frameInset)
    readonly property int marginTop: bars.reduce((m, b) => Math.max(m, b.marginTop), frameInset)
    readonly property int marginBottom: bars.reduce((m, b) => Math.max(m, b.marginBottom), frameInset)
    readonly property int reservedLeft: bars.reduce((m, b) => Math.max(m, b.reservedLeft), frameInset)
    readonly property int reservedRight: bars.reduce((m, b) => Math.max(m, b.reservedRight), frameInset)
    readonly property int reservedTop: bars.reduce((m, b) => Math.max(m, b.reservedTop), frameInset)
    readonly property int reservedBottom: bars.reduce((m, b) => Math.max(m, b.reservedBottom), frameInset)

    // Every visible island of every bar, in window coordinates.
    readonly property var visualRects: bars.reduce((acc, b) => acc.concat(b.visualRects), [])

    function barOn(edge: string): Item {
        return bars.find(b => b.position === edge) ?? null;
    }

    function floatingOn(edge: string): bool {
        return barOn(edge)?.floating ?? false;
    }

    function barAt(x: real, y: real): Item {
        return bars.find(b => b.containsVisualPoint(x, y)) ?? null;
    }

    function containsVisualPoint(x: real, y: real): bool {
        return barAt(x, y) !== null;
    }

    function closeTray(): void {
        for (const b of bars)
            b.closeTray();
    }

    function checkPopout(x: real, y: real): void {
        const b = barAt(x, y);
        if (b)
            b.checkPopoutAt(x, y);
        else
            popouts.hasCurrent = false;
    }

    function handleWheel(x: real, y: real, angleDelta: point): void {
        barAt(x, y)?.handleWheelAt(x, y, angleDelta);
    }

    Repeater {
        id: repeater

        model: root.specs

        BarWrapper {
            id: bar

            required property var modelData

            spec: modelData
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts
            disabled: root.disabled
            frameVisible: root.frameVisible
            isHovered: root.isHovered

            // parent is null while delegates are destroyed on model reset.
            anchors.left: (!bar.vertical || bar.position === "left") ? parent?.left : undefined
            anchors.right: (!bar.vertical || bar.position === "right") ? parent?.right : undefined
            anchors.top: (bar.vertical || bar.position === "top") ? parent?.top : undefined
            anchors.bottom: (bar.vertical || bar.position === "bottom") ? parent?.bottom : undefined
            // Horizontal bars own the full width; vertical bars sit between them.
            anchors.topMargin: bar.vertical ? (root.barOn("top")?.currentThickness ?? 0) : 0
            anchors.bottomMargin: bar.vertical ? (root.barOn("bottom")?.currentThickness ?? 0) : 0
        }
    }
}
