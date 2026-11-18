import qs.services
import qs.config
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "Fillet.js" as Fillet

// The morphing background of an anchored surface (Signal visual language
// §7.1, §7.2, §15): `panel` fill, 1 px `rule` border, radius `small`,
// one restrained shadow cast away from the anchor, and the notch — a
// 2 px `signal` line exactly as wide as the trigger on the anchor edge —
// so the surface visibly originates from its trigger even with motion
// off. Attached surfaces sit against their bar: that edge has no border
// and square corners. With a machined fillet (`fillet` > 0, attached only)
// the two junction corners flare into the bar through concave quarter
// arcs tangent to the bar's outline (`filletRule` px inside the anchor line),
// so the 1 px rule runs from the bezel through the arc into the frame.
//
// Everything is plain Rectangles plus one analytic RectangularShadow,
// and one small Shape path when a fillet is drawn: no layers, no
// offscreen passes, so animating the frame's geometry stays cheap.
Item {
    id: root

    // Anchor edge of the surface ("top" when it opens below its trigger),
    // "" for centred surfaces.
    property string edge: ""
    property bool attached: false
    // Notch extent along the anchor edge, in frame coordinates.
    property real notchStart: 0
    property real notchLength: 0
    property bool notchVisible: notchLength > 0 && edge !== ""
    // Registration tick (keyboard focus inside the surface).
    property bool focused: false
    property color fill: Signal.palette.panel
    property color rule: Signal.palette.rule
    property real radius: Appearance.rounding.small
    // 0 none, 2 panel, 4 lifted (visual language §7.2).
    property int elevation: 2

    // Machined fillet radius at the attached junction (0 = flush) and the
    // junction outline's offset from the anchor line into the surface.
    property real fillet: 0
    property real filletRule: 0

    readonly property bool horizontalEdge: edge === "top" || edge === "bottom"
    readonly property real _cut: radius + 1
    readonly property bool _filleted: attached && fillet > 0 && edge !== ""

    RectangularShadow {
        anchors.fill: parent
        visible: root.elevation > 0 && root.width > 1 && root.height > 1
        radius: root.radius
        color: Qt.alpha(Signal.palette.shadow, 0.35)
        blur: 12
        spread: 0
        // 4 px away from the anchor edge.
        offset.x: root.edge === "left" ? 4 : root.edge === "right" ? -4 : 0
        offset.y: root.edge === "top" ? 4 : root.edge === "bottom" ? -4 : (root.edge === "" ? 4 : 0)
        cached: false
    }

    // The fill and border. An attached edge is cut off by the clip: the
    // rectangle overhangs that edge by radius + 1, which hides the border
    // there and squares its corners.
    Item {
        anchors.fill: parent
        visible: !root._filleted
        clip: root.attached

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: root.attached && root.edge === "top" ? -root._cut : 0
            anchors.bottomMargin: root.attached && root.edge === "bottom" ? -root._cut : 0
            anchors.leftMargin: root.attached && root.edge === "left" ? -root._cut : 0
            anchors.rightMargin: root.attached && root.edge === "right" ? -root._cut : 0
            color: root.fill
            radius: root.radius
            border.width: 1
            border.color: root.rule
            antialiasing: true
        }
    }

    // Filleted body, drawn in anchor-edge coordinates (u along the anchor
    // edge, v away from it) and mapped onto the frame's edge. Strokes run
    // 0.5 px inside the frame, where the Rectangle above draws its border.
    Shape {
        id: filleted

        readonly property real len: root.horizontalEdge ? root.width : root.height
        readonly property real depth: root.horizontalEdge ? root.height : root.width
        readonly property real s: 0.5
        readonly property real rc: Math.max(0, Math.min(root.radius - 0.5, len / 2 - s, depth / 2 - s))
        readonly property real c: root.filletRule
        readonly property real f: Fillet.fit(root.fillet, depth, s + rc, c)

        visible: root._filleted && root.width > 1 && root.height > 1
        preferredRendererType: Shape.CurveRenderer
        transform: Matrix4x4 {
            matrix: root.edge === "bottom" ? Qt.matrix4x4(1, 0, 0, 0, 0, -1, 0, root.height, 0, 0, 1, 0, 0, 0, 0, 1)
                : root.edge === "left" ? Qt.matrix4x4(0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                : root.edge === "right" ? Qt.matrix4x4(0, -1, 0, root.width, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                : Qt.matrix4x4()
        }

        ShapePath {
            strokeWidth: 1
            strokeColor: root.rule
            fillColor: root.fill
            startX: filleted.s - filleted.f
            startY: 0

            PathLine {
                x: filleted.s - filleted.f
                y: filleted.c
            }
            PathArc {
                x: filleted.s
                y: filleted.c + filleted.f
                radiusX: filleted.f
                radiusY: filleted.f
            }
            PathLine {
                x: filleted.s
                y: filleted.depth - filleted.s - filleted.rc
            }
            PathArc {
                x: filleted.s + filleted.rc
                y: filleted.depth - filleted.s
                radiusX: filleted.rc
                radiusY: filleted.rc
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: filleted.len - filleted.s - filleted.rc
                y: filleted.depth - filleted.s
            }
            PathArc {
                x: filleted.len - filleted.s
                y: filleted.depth - filleted.s - filleted.rc
                radiusX: filleted.rc
                radiusY: filleted.rc
                direction: PathArc.Counterclockwise
            }
            PathLine {
                x: filleted.len - filleted.s
                y: filleted.c + filleted.f
            }
            PathArc {
                x: filleted.len - filleted.s + filleted.f
                y: filleted.c
                radiusX: filleted.f
                radiusY: filleted.f
            }
            PathLine {
                x: filleted.len - filleted.s + filleted.f
                y: 0
            }
        }
    }

    // Notch: continues the trigger's open-state underline into the surface.
    Rectangle {
        visible: root.notchVisible
        color: Signal.palette.signal
        x: root.horizontalEdge ? Math.max(0, Math.min(root.width, root.notchStart)) : (root.edge === "left" ? 0 : root.width - 2)
        y: root.horizontalEdge ? (root.edge === "top" ? 0 : root.height - 2) : Math.max(0, Math.min(root.height, root.notchStart))
        width: root.horizontalEdge ? Math.max(0, Math.min(root.notchLength, root.width - x)) : 2
        height: root.horizontalEdge ? 2 : Math.max(0, Math.min(root.notchLength, root.height - y))
    }

    // Registration tick: 2 x 10 px on the leading top corner while the
    // surface holds keyboard focus. Never conveyed by glow.
    Rectangle {
        visible: root.focused && root.width > 12 && root.height > 12
        color: Signal.palette.signal
        x: root.edge === "right" ? root.width - 4 - width : 4
        y: root.edge === "top" ? 4 : (root.edge === "bottom" ? 4 : 4)
        width: 2
        height: 10
    }
}
