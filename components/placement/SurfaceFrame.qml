import qs.services
import qs.config
import QtQuick
import QtQuick.Effects

// The morphing background of an anchored surface (Signal visual language
// §7.1, §7.2, §15): `panel` fill, 1 px `rule` border, radius `small`,
// one restrained shadow cast away from the anchor, and the notch — a
// 2 px `signal` line exactly as wide as the trigger on the anchor edge —
// so the surface visibly originates from its trigger even with motion
// off. Attached surfaces sit flush against their bar: that edge has no
// border and square corners.
//
// Everything is plain Rectangles plus one analytic RectangularShadow:
// no layers, no offscreen passes, so animating the frame's geometry
// costs a few vertices per frame.
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

    readonly property bool horizontalEdge: edge === "top" || edge === "bottom"
    readonly property real _cut: radius + 1

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
