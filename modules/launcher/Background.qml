import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes
import "../../components/placement/Fillet.js" as Fillet

// Launcher sheet (Signal Bezel §7.1): an attached `panel` surface with a
// 1 px `rule` border on its three free edges and radius `small` on the
// two corners away from the anchor edge. At the anchor edge it grows out
// of the bezel through a machined fillet (see dashboard/Background.qml):
// radius `fillet`, tangent to the junction outline `rule` px inside the
// anchor line; 0 keeps the flush square junction. The host still starts
// this path `rounding` px left of the wrapper, so the first PathMove skips
// that offset.
ShapePath {
    id: root

    required property Wrapper wrapper
    property real fillet: 0
    property real rule: 0
    readonly property real rounding: Config.border.rounding
    readonly property real r: Math.min(Appearance.rounding.small, wrapper.height / 2, wrapper.width / 2)
    readonly property bool open: wrapper.width > 0 && wrapper.height > 0
    readonly property real c: fillet > 0 ? rule : 0
    readonly property real f: Fillet.fit(fillet, wrapper.height, r, c)

    strokeWidth: open ? 1 : -1
    strokeColor: Signal.palette.rule
    fillColor: open ? Signal.surface(Signal.palette.panel, "launcher") : "transparent"

    PathMove {
        relativeX: root.rounding - root.f
        relativeY: 0
    }
    PathLine {
        relativeX: 0
        relativeY: -root.c
    }
    PathArc {
        relativeX: root.f
        relativeY: -root.f
        radiusX: root.f
        radiusY: root.f
        direction: PathArc.Counterclockwise
    }
    PathLine {
        relativeX: 0
        relativeY: -(root.wrapper.height - root.r - root.f - root.c)
    }
    PathArc {
        relativeX: root.r
        relativeY: -root.r
        radiusX: root.r
        radiusY: root.r
    }
    PathLine {
        relativeX: root.wrapper.width - root.r * 2
        relativeY: 0
    }
    PathArc {
        relativeX: root.r
        relativeY: root.r
        radiusX: root.r
        radiusY: root.r
    }
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.r - root.f - root.c
    }
    PathArc {
        relativeX: root.f
        relativeY: root.f
        radiusX: root.f
        radiusY: root.f
        direction: PathArc.Counterclockwise
    }
    PathLine {
        relativeX: 0
        relativeY: root.c
    }

    Behavior on fillColor {
        CAnim {}
    }
}
