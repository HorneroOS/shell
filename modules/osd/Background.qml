import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

// Right-attached sheet (Signal Bezel §7.1): `panel` fill, 1 px `rule`
// border on the three free edges, radius `small` on the two corners away
// from the anchor edge, no concave wings. The host starts this path
// `rounding` px above the wrapper, so the first PathMove skips it.
ShapePath {
    id: root

    required property Wrapper wrapper
    readonly property real rounding: Config.border.rounding
    readonly property real r: Math.min(Appearance.rounding.small, wrapper.width / 2, wrapper.height / 2)
    readonly property bool open: wrapper.width > 0 && wrapper.height > 0

    strokeWidth: open ? 1 : -1
    strokeColor: Signal.palette.rule
    fillColor: open ? Signal.surface(Signal.palette.panel, "osd") : "transparent"

    PathMove {
        relativeX: 0
        relativeY: root.rounding
    }
    PathLine {
        relativeX: -(root.wrapper.width - root.r)
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
        relativeX: root.wrapper.width - root.r
        relativeY: 0
    }

    Behavior on fillColor {
        CAnim {}
    }
}
