import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Shapes
import "../../components/placement/Fillet.js" as Fillet

// Utilities drawer (Signal Bezel §7.1): a bottom-right `panel` sheet with a
// 1 px `rule` border on its two free edges (left, top) and radius `small`
// on the top-left corner. The right edge sits on the screen edge and is
// not stroked; the bottom one runs on the frame's edge line. Both
// junctions grow out of the bezel through a machined fillet (see
// dashboard/Background.qml): `fillet` where the left edge meets the bottom
// frame, `filletEnd` where the top edge meets the right frame (0 while the
// sidebar shares that edge). `sidebar` stays a required property: the
// drawer still takes the sidebar's width while it is open.
ShapePath {
    id: root

    required property Wrapper wrapper
    required property var sidebar
    property real fillet: 0
    property real rule: 0
    property real filletEnd: 0
    property real ruleEnd: 0
    readonly property real r: Math.min(Appearance.rounding.small, wrapper.width / 2, wrapper.height / 2)
    readonly property bool open: wrapper.width > 0 && wrapper.height > 0
    readonly property real f: Fillet.fit(fillet, wrapper.height, r, rule)
    readonly property real cEnd: filletEnd > 0 ? ruleEnd : 0
    readonly property real fEnd: Fillet.fit(Math.min(filletEnd, wrapper.y), wrapper.width, r, cEnd)

    strokeWidth: open ? 1 : -1
    strokeColor: Signal.palette.rule
    fillColor: open ? Signal.surface(Signal.palette.panel, "utilities") : "transparent"

    // The bottom edge is drawn on the frame's own edge line (`rule` px up
    // from the screen edge), where its stroke disappears into that line, so
    // the fill closes on the sheet's real outline: a path that only covered
    // the two free edges would close with a diagonal and fill a triangle.
    PathMove {
        relativeX: 0
        relativeY: -root.rule
    }
    PathLine {
        relativeX: -(root.wrapper.width + root.f)
        relativeY: 0
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
        relativeY: -(root.wrapper.height - root.r - root.f - root.rule)
    }
    PathArc {
        relativeX: root.r
        relativeY: -root.r
        radiusX: root.r
        radiusY: root.r
    }
    PathLine {
        relativeX: root.wrapper.width - root.r - root.fEnd - root.cEnd
        relativeY: 0
    }
    PathArc {
        relativeX: root.fEnd
        relativeY: -root.fEnd
        radiusX: root.fEnd
        radiusY: root.fEnd
        direction: PathArc.Counterclockwise
    }
    PathLine {
        relativeX: root.cEnd
        relativeY: 0
    }

    Behavior on fillColor {
        CAnim {}
    }
}
