import Quickshell
import qs.components
import qs.components.effects
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral
    // Cockpit Clear: no fill, the on-air bar and the ink numeral carry it.
    property bool clear: false

    required property ShellScreen screen

    required property int activeWsId
    required property Repeater workspaces
    required property Item mask

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
        const s = Math.abs(leading - trailing) + currentSize;
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

    clip: true
    x: vertical ? 0 : offset + mask.x
    y: vertical ? offset + mask.y : 0
    implicitWidth: vertical ? Density.inner - Appearance.padding.small * 2 : size
    implicitHeight: vertical ? size : Density.inner - Appearance.padding.small * 2
    // Signal Bezel §5: fixed rectangular cells, never pills. The active
    // cell is a raised fill with the numeral in ink — not a signal slab.
    radius: Appearance.rounding.small
    color: root.clear ? "transparent" : Signal.palette.raised

    // §5 on-air bar: 2 px signal across the full cell on the edge facing
    // the content (top edge for a bottom strip, bottom for a top rail,
    // inner edge for rails).
    Rectangle {
        width: root.vertical ? 2 : root.width
        height: root.vertical ? root.height : 2
        x: root.vertical ? (root.edge === "right" ? 0 : root.width - 2) : 0
        y: root.vertical ? 0 : (root.edge === "bottom" ? 0 : root.height - 2)
        color: root.tone.signal
    }

    Colouriser {
        source: root.mask
        sourceColor: root.tone.ink
        colorizationColor: root.tone.ink

        x: root.vertical ? 0 : -parent.offset
        y: root.vertical ? -parent.offset : 0
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight

        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
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
