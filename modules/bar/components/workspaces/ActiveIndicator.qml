import Quickshell
import qs.components
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral
    // Cockpit Clear: no fill, the signal tick and the ink numeral carry it.
    property bool clear: false

    required property ShellScreen screen

    // Inset of the cell inside its track (Workspaces.activeInset, px) and the
    // track's cross-axis size: the plate is exactly one cell, `inset` from
    // the track edges on the cross axis.
    property int inset: 0
    property int crossSize: Density.inner
    // The signal tick sits this far inside the plate (0 flush on Clear).
    readonly property int tickGap: clear ? 0 : 2
    readonly property int tickInset: clear ? 0 : Math.max(3, Math.round(Density.textPx / 3))

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

    property real leading: workspaces.count > 0 ? (vertical ? workspaces.itemAt(currentWsIdx)?.y : workspaces.itemAt(currentWsIdx)?.x) ?? 0 : 0
    property real trailing: workspaces.count > 0 ? (vertical ? workspaces.itemAt(currentWsIdx)?.y : workspaces.itemAt(currentWsIdx)?.x) ?? 0 : 0
    property real currentSize: workspaces.count > 0 ? workspaces.itemAt(currentWsIdx)?.size ?? 0 : 0
    property real offset: Math.min(leading, trailing)
    property real size: {
        const s = Math.max(0, Math.abs(leading - trailing) + currentSize);
        if (Config.bar.workspaces.activeTrail && lastWs > currentWsIdx) {
            const ws = workspaces.itemAt(lastWs);
            const wsEnd = vertical ? (ws ? ws.y + ws.size : 0) : (ws ? ws.x + ws.size : 0);
            return ws ? Math.min(wsEnd - offset, s) : 0;
        }
        return s;
    }

    property int cWs
    property int lastWs

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }

    x: vertical ? 0 : offset + cells.x
    y: vertical ? offset + cells.y : 0
    implicitWidth: vertical ? root.crossSize - root.inset * 2 : size
    implicitHeight: vertical ? size : root.crossSize - root.inset * 2
    // Signal Bezel §5: fixed rectangular cells, never pills. The active
    // cell is a raised fill with the numeral in ink — not a signal slab.
    radius: Appearance.rounding.small
    color: root.clear ? "transparent" : Qt.tint(Signal.palette.raised, Qt.alpha(root.tone.ink, 0.1))

    // Signal tick: 2 px across the cell on the edge facing the content (top
    // edge for a bottom strip, bottom for a top rail, inner edge for rails),
    // inset inside the plate; flush and full width on Cockpit Clear.
    Rectangle {
        width: root.vertical ? 2 : Math.max(0, root.width - root.tickInset * 2)
        height: root.vertical ? Math.max(0, root.height - root.tickInset * 2) : 2
        x: root.vertical ? (root.edge === "right" ? root.tickGap : root.width - 2 - root.tickGap) : root.tickInset
        y: root.vertical ? root.tickInset : (root.edge === "bottom" ? root.tickGap : root.height - 2 - root.tickGap)
        color: root.tone.signal
    }

    Behavior on leading {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on trailing {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {
            duration: Appearance.anim.durations.medium * 2
        }
    }

    Behavior on currentSize {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on offset {
        enabled: !Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on size {
        enabled: !Config.bar.workspaces.activeTrail

        EAnim {}
    }

    component EAnim: Anim {
        easing.bezierCurve: Appearance.anim.curves.standard
    }
}
