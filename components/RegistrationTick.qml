import qs.services
import qs.config
import QtQuick

// Registration tick (RFC 0001 §2): a 2 × 10 px `signal` tick on the
// leading top corner of the focused/active surface, instead of a glow.
// Place as a direct child of the surface; it anchors itself.
Rectangle {
    id: root

    property bool active: true
    // Leading corner: "left" (default, LTR) or "right".
    property string corner: Qt.application.layoutDirection === Qt.RightToLeft ? "right" : "left"

    anchors.top: parent.top
    anchors.left: root.corner === "left" ? parent.left : undefined
    anchors.right: root.corner === "right" ? parent.right : undefined
    width: 2
    height: 10
    color: Signal.palette.signal
    opacity: root.active ? 1 : 0
    visible: opacity > 0

    Accessible.ignored: true

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.durations.fade
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }
}
