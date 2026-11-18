import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes
import "../../components/placement/Fillet.js" as Fillet

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

    // Machined fillet at the top junction with the right frame (see
    // dashboard/Background.qml), only where there is frame above the sheet
    // to grow out of (below a notification stack). The bottom junction is
    // the utilities drawer or the frame's own bottom corner: no fillet.
    property real fillet: 0
    property real rule: 0
    readonly property real c: fillet > 0 ? rule : 0
    readonly property real f: Fillet.fit(Math.min(fillet, panels.notifications.height), wrapper.width, r, c)

    // Signal Bezel §7.1: a right-attached `panel` sheet with a 1 px `rule`
    // border on its three free edges and radius `small` on the two corners
    // away from the anchor edge. The `*RoundingX`
    // properties above stay because the notification host still derives its
    // own geometry from them; they no longer shape this sheet.
    strokeWidth: open ? 1 : -1
    strokeColor: Signal.palette.rule
    fillColor: open ? Signal.surface(Signal.palette.panel, "sidebar") : "transparent"

    PathMove {
        relativeX: 0
        relativeY: -root.f
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
        relativeX: root.wrapper.width - root.r
        relativeY: 0
    }

    Behavior on fillColor {
        CAnim {}
    }
}
