import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

// Launcher sheet (Signal Bezel §7.1): an attached `panel` surface with a
// 1 px `rule` border on its three free edges and radius `small` on the
// two corners away from the anchor edge. No concave "wings": the host
// still starts this path `rounding` px left of the wrapper, so the first
// PathMove skips that offset.
ShapePath {
    id: root

    required property Wrapper wrapper
    readonly property real rounding: Config.border.rounding
    readonly property real r: Math.min(Appearance.rounding.small, wrapper.height / 2, wrapper.width / 2)
    readonly property bool open: wrapper.width > 0 && wrapper.height > 0

    strokeWidth: open ? 1 : -1
    strokeColor: Signal.palette.rule
    fillColor: open ? Signal.surface(Signal.palette.panel, "launcher") : "transparent"

    PathMove {
        relativeX: root.rounding
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
        relativeY: root.wrapper.height - root.r
    }

    Behavior on fillColor {
        CAnim {}
    }
}
