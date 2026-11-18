import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes
import "../../components/placement/Fillet.js" as Fillet

// Dashboard sheet (Signal Bezel §7.1): a top-attached `panel` surface with
// a 1 px `rule` border on its three free edges and radius `small` on the
// two lower corners. Where it meets the bar or the frame it grows out of
// the bezel through a machined fillet: a concave quarter arc of radius
// `fillet` (border.fillet; 0 = the flush square junction) tangent to the
// junction's outline, `rule` px from the anchor line into the sheet, so the
// frame's edge line runs through the arc without a step. The host still
// starts this path `rounding` px left of the wrapper, so the first PathMove
// skips that offset. Nothing is painted while the panel is closed.
ShapePath {
    id: root

    required property Wrapper wrapper
    // Set by modules/drawers/Backgrounds.qml (0 where nothing is attached).
    property real fillet: 0
    property real rule: 0
    readonly property real rounding: Config.border.rounding
    readonly property real r: Math.min(Appearance.rounding.small, wrapper.height / 2, wrapper.width / 2)
    readonly property bool open: wrapper.width > 0 && wrapper.height > 0
    readonly property real c: fillet > 0 ? rule : 0
    // The fillet never eats the side: it grows with the sheet as it opens.
    readonly property real f: Fillet.fit(fillet, wrapper.height, r, c)

    strokeWidth: open ? 1 : -1
    strokeColor: Signal.palette.rule
    fillColor: open ? Signal.surface(Signal.palette.panel, "dashboard") : "transparent"

    PathMove {
        relativeX: root.rounding - root.f
        relativeY: 0
    }
    PathLine {
        relativeX: 0
        relativeY: root.c
    }
    PathArc {
        relativeX: root.f
        relativeY: root.f
        radiusX: root.f
        radiusY: root.f
    }
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.r - root.f - root.c
    }
    PathArc {
        relativeX: root.r
        relativeY: root.r
        radiusX: root.r
        radiusY: root.r
        direction: PathArc.Counterclockwise
    }
    PathLine {
        relativeX: root.wrapper.width - root.r * 2
        relativeY: 0
    }
    PathArc {
        relativeX: root.r
        relativeY: -root.r
        radiusX: root.r
        radiusY: root.r
        direction: PathArc.Counterclockwise
    }
    PathLine {
        relativeX: 0
        relativeY: -(root.wrapper.height - root.r - root.f - root.c)
    }
    PathArc {
        relativeX: root.f
        relativeY: -root.f
        radiusX: root.f
        radiusY: root.f
    }
    PathLine {
        relativeX: 0
        relativeY: -root.c
    }

    Behavior on fillColor {
        CAnim {}
    }
}
