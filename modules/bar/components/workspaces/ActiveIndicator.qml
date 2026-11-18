import Quickshell
import qs.components
import qs.services
import qs.config
import QtQuick

// The active workspace plate. "Needle travel" (Bars > Workspaces): on a
// switch the edge facing the target leads with `settleFast` and the far
// edge follows `trailRatio` times slower on `sweep`, so the plate
// stretches across the cells it passes and then lands as exactly one cell,
// like a tuning needle sweeping a dial. Off, at motion level `reduced`, or
// under reduced motion both edges move together (instant when durations are
// zero). The numerals it covers turn ink through PlateInk.
StyledRect {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral
    // Cockpit Clear: no fill, the signal tick and the ink numeral carry it.
    property bool clear: false
    // Special workspace open: the strip recedes, the tick dims to inkMuted.
    property bool receded: false

    required property ShellScreen screen

    // Inset of the cell inside its track (Workspaces.activeInset, px) and the
    // track's cross-axis size: the plate is exactly one cell, `inset` from
    // the track edges on the cross axis.
    property int inset: 0
    property int crossSize: Density.inner
    // The signal tick sits this far inside the plate (0 flush on Clear).
    readonly property int tickGap: clear ? 0 : 2

    required property int activeWsId
    required property Repeater workspaces
    // The strip's cell layout: the plate follows its cells.
    required property Item cells

    // Orientation of the owning bar (set by Bar.qml); defaults to the
    // primary bar for standalone use.
    property bool vertical: Config.bar.isVerticalFor(screen.name)
    // Owning bar edge; the §5 on-air bar sits on the content-facing edge.
    property string edge: Config.bar.positionFor(screen.name)

    readonly property int currentWsIdx: {
        let i = activeWsId - 1;
        while (i < 0)
            i += Config.bar.workspaces.shown;
        return i % Config.bar.workspaces.shown;
    }

    // Needle travel only where spatial motion is allowed (§11.3).
    readonly property bool needle: Config.bar.workspaces.activeTrail && Appearance.anim.spatial
    readonly property real trailRatio: Math.max(1, Math.min(2.5, Config.bar.workspaces.trailRatio))
    readonly property int leadDuration: needle ? Appearance.anim.durations.settleFast : Appearance.anim.durations.medium
    readonly property int trailDuration: needle ? Math.round(leadDuration * trailRatio) : leadDuration

    readonly property Item target: workspaces.count > 0 ? workspaces.itemAt(currentWsIdx) : null

    // Travel state: edges interpolate from where the plate was (`fromStart`,
    // `fromEnd`) to the landed cell's live geometry, so a cell that resizes
    // mid-flight (a window glyph arriving) is still tracked exactly.
    property Item landing: null
    property real fromStart: 0
    property real fromEnd: 0
    property real pStart: 1
    property real pEnd: 1
    // +1 travelling towards higher cells, -1 towards lower ones.
    property int dir: 1

    readonly property real toStart: landing ? (vertical ? landing.y : landing.x) : 0
    readonly property real toEnd: toStart + (landing?.size ?? 0)
    readonly property real startEdge: fromStart + (toStart - fromStart) * pStart
    readonly property real endEdge: fromEnd + (toEnd - fromEnd) * pEnd
    // Plate length along the bar: stretched across the passed cells while
    // travelling, exactly one cell at rest.
    readonly property real length: Math.max(0, endEdge - startEdge)
    readonly property real restLength: toEnd - toStart
    // 0 at rest, 1 once the plate is stretched by a full cell.
    readonly property real stretch: restLength > 0 ? Math.max(0, Math.min(1, (length - restLength) / restLength)) : 0

    function retarget(): void {
        if (!root.target)
            return;
        if (!root.landing || root.leadDuration <= 0) {
            travel.stop();
            root.landing = root.target;
            root.fromStart = root.toStart;
            root.fromEnd = root.toEnd;
            root.pStart = 1;
            root.pEnd = 1;
            return;
        }
        // Freeze where the plate is now, then fly to the new cell.
        const s = root.startEdge;
        const e = root.endEdge;
        travel.stop();
        root.fromStart = s;
        root.fromEnd = e;
        root.pStart = 0;
        root.pEnd = 0;
        root.landing = root.target;
        root.dir = (root.toStart + root.toEnd) >= (s + e) ? 1 : -1;
        const forward = root.dir > 0;
        // The edge facing the target leads; the far edge trails.
        startAnim.duration = forward ? root.trailDuration : root.leadDuration;
        endAnim.duration = forward ? root.leadDuration : root.trailDuration;
        // Lead on settleFast; the trail holds back on `sweep` (in-out), so
        // the plate stays stretched across the passed cells and then snaps
        // to one cell. Without the needle both edges share `standard`.
        const lead = Appearance.anim.curves.settleFast;
        const trail = Appearance.anim.curves.sweep;
        startAnim.easing.bezierCurve = !root.needle ? Appearance.anim.curves.standard : forward ? trail : lead;
        endAnim.easing.bezierCurve = !root.needle ? Appearance.anim.curves.standard : forward ? lead : trail;
        travel.start();
    }

    onTargetChanged: retarget()
    Component.onCompleted: retarget()

    x: vertical ? 0 : startEdge + cells.x
    y: vertical ? startEdge + cells.y : 0
    implicitWidth: vertical ? root.crossSize - root.inset * 2 : length
    implicitHeight: vertical ? length : root.crossSize - root.inset * 2
    // Signal Bezel §5: fixed rectangular cells, never pills. The active
    // cell is a raised fill with the numeral in ink — not a signal slab.
    radius: Appearance.rounding.small
    // Receded (special workspace open): the plain raised plate, untinted.
    color: root.clear ? "transparent" : root.receded ? Signal.palette.raised : Qt.tint(Signal.palette.raised, Qt.alpha(root.tone.signal, 0.3))

    ParallelAnimation {
        id: travel

        NumberAnimation {
            id: startAnim

            target: root
            property: "pStart"
            to: 1
            easing.type: Easing.BezierSpline
        }

        NumberAnimation {
            id: endAnim

            target: root
            property: "pEnd"
            to: 1
            easing.type: Easing.BezierSpline
        }
    }

    // Signal tick: 2 px, half a cell long (a full cell, flush, on Clear,
    // matching its underline reference), on the edge facing the content,
    // inside the plate. At rest it is centred along the bar; in flight it
    // rides the leading third of the stretched plate, like a needle.
    Rectangle {
        id: tick

        readonly property real tickLength: root.clear ? root.restLength : Math.round(root.restLength / 2)
        // Centred along the bar at rest.
        readonly property real restPos: (root.length - tickLength) / 2
        readonly property real leadPos: root.dir > 0 ? root.length * 5 / 6 - tickLength / 2 : root.length / 6 - tickLength / 2
        readonly property real pos: Math.round(Math.max(0, Math.min(root.length - tickLength, restPos + (leadPos - restPos) * root.stretch)))

        width: root.vertical ? 2 : tickLength
        height: root.vertical ? tickLength : 2
        x: root.vertical ? (root.edge === "right" ? root.tickGap : root.width - 2 - root.tickGap) : pos
        y: root.vertical ? pos : (root.edge === "bottom" ? root.tickGap : root.height - 2 - root.tickGap)
        radius: 1 // fixed: 2 px tick end rounding, not a theme corner
        color: root.receded ? root.tone.inkMuted : root.tone.signal

        Behavior on color {
            CAnim {}
        }
    }
}
