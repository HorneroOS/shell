import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes

ShapePath {
    id: root

    required property Wrapper wrapper
    required property var panels

    readonly property real rounding: Config.border.rounding

    readonly property real notifsWidthDiff: panels.notifications.width - wrapper.width
    readonly property real notifsRoundingX: panels.notifications.height > 0 && notifsWidthDiff < rounding * 2 ? notifsWidthDiff / 2 : rounding

    readonly property real utilsWidthDiff: panels.utilities.width - wrapper.width
    readonly property real utilsRoundingX: utilsWidthDiff < rounding * 2 ? utilsWidthDiff / 2 : rounding

    readonly property real r: Math.min(Appearance.rounding.small, wrapper.width / 2, wrapper.height / 2)
    readonly property bool open: wrapper.width > 0 && wrapper.height > 0

    // Signal Bezel §7.1: a right-attached `panel` sheet with a 1 px `rule`
    // border on its three free edges and radius `small` on the two corners
    // away from the anchor edge — no concave wings. The `*RoundingX`
    // properties above stay because the notification host still derives its
    // own geometry from them; they no longer shape this sheet.
    strokeWidth: open ? 1 : -1
    strokeColor: Signal.palette.rule
    fillColor: open ? Signal.surface(Signal.palette.panel, "sidebar") : "transparent"

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
