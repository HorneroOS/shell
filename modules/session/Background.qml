import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes
import "../../components/placement/Fillet.js" as Fillet

// Right-attached sheet (Signal Bezel §7.1): `panel` fill, 1 px `rule`
// border on the three free edges, radius `small` on the two corners away
// from the anchor edge. Where it meets the frame or the bar it grows out
// of the bezel through a machined fillet (see dashboard/Background.qml):
// radius `fillet`, tangent to the junction outline `rule` px inside the
// anchor line; 0 keeps the flush square junction. The host starts this
// path `rounding` px above the wrapper, so the first PathMove skips it.
ShapePath {
    id: root

    required property Wrapper wrapper
    property real fillet: 0
    property real rule: 0
    readonly property real rounding: Config.border.rounding
    readonly property real r: Math.min(Appearance.rounding.small, wrapper.width / 2, wrapper.height / 2)
    readonly property bool open: wrapper.width > 0 && wrapper.height > 0
    readonly property real c: fillet > 0 ? rule : 0
    readonly property real f: Fillet.fit(fillet, wrapper.width, r, c)

    strokeWidth: open ? 1 : -1
    strokeColor: Signal.palette.rule
    fillColor: open ? Signal.surface(Signal.palette.panel, "session") : "transparent"

    PathMove {
        relativeX: 0
        relativeY: root.rounding - root.f
    }
    PathLine {
        relativeX: -root.c
        relativeY: 0
    }
    PathArc {
        relativeX: -root.f
        relativeY: root.f
        radiusX: root.f
        radiusY: root.f
    }
    PathLine {
        relativeX: -(root.wrapper.width - root.r - root.f - root.c)
        relativeY: 0
    }
    PathArc {
        relativeX: -root.r
        relativeY: root.r
        radiusX: root.r
        radiusY: root.r
        direction: PathArc.Counterclockwise
    }
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.r * 2
    }
    PathArc {
        relativeX: root.r
        relativeY: root.r
        radiusX: root.r
        radiusY: root.r
        direction: PathArc.Counterclockwise
    }
    PathLine {
        relativeX: root.wrapper.width - root.r - root.f - root.c
        relativeY: 0
    }
    PathArc {
        relativeX: root.f
        relativeY: root.f
        radiusX: root.f
        radiusY: root.f
    }
    PathLine {
        relativeX: root.c
        relativeY: 0
    }

    Behavior on fillColor {
        CAnim {}
    }
}
