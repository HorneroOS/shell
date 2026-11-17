import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

// Utilities drawer (Signal Bezel §7.1): a bottom-right `panel` sheet with a
// 1 px `rule` border on its two free edges (left, top) and radius `small`
// on the top-left corner. The bottom and right edges sit on the screen
// edge and are not stroked. No concave wings. `sidebar` stays a required
// property: the drawer still takes the sidebar's width while it is open.
ShapePath {
    id: root

    required property Wrapper wrapper
    required property var sidebar
    readonly property real r: Math.min(Appearance.rounding.small, wrapper.width / 2, wrapper.height / 2)
    readonly property bool open: wrapper.width > 0 && wrapper.height > 0

    strokeWidth: open ? 1 : -1
    strokeColor: Signal.palette.rule
    fillColor: open ? Signal.surface(Signal.palette.panel, "utilities") : "transparent"

    PathMove {
        relativeX: -root.wrapper.width
        relativeY: 0
    }
    PathLine {
        relativeX: 0
        relativeY: -(root.wrapper.height - root.r)
    }
    PathArc {
        relativeX: root.r
        relativeY: -root.r
        radiusX: root.r
        radiusY: root.r
    }
    PathLine {
        relativeX: root.wrapper.width - root.r
        relativeY: 0
    }

    Behavior on fillColor {
        CAnim {}
    }
}
