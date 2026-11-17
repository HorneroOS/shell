import qs.services
import qs.config
import QtQuick
import QtQuick.Effects

// On-air bar (RFC 0001 §2, signal-visual-language §5): the active state
// of a strip item — a 2 px `signal` bar on the edge facing the content.
// `edge` names that edge of the parent. `glow` is honoured only where
// amendment 2 allows it (Experience.glow: Signal mode, dark theme, no
// high contrast, motion on) and is a static ≤ 4 px, ≤ 40 % halo.
Rectangle {
    id: root

    property string edge: "bottom"
    property bool active: true
    property bool glow: false
    property int thickness: 2
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property bool glowWanted: root.glow && Experience.glow && !Appearance.anim.reduced && root.visible
    // Shell-wide glow budget (visual language §9).
    property bool _granted: false
    readonly property bool glowAllowed: root.glowWanted && root._granted
    onGlowWantedChanged: root._syncGlow()
    Component.onCompleted: root._syncGlow()
    Component.onDestruction: Experience.releaseGlow(root)

    function _syncGlow(): void {
        if (root.glowWanted)
            root._granted = Experience.acquireGlow(root, 0);
        else {
            Experience.releaseGlow(root);
            root._granted = false;
        }
    }

    anchors.top: root.edge === "bottom" ? undefined : parent.top
    anchors.bottom: root.edge === "top" ? undefined : parent.bottom
    anchors.left: root.edge === "right" ? undefined : parent.left
    anchors.right: root.edge === "left" ? undefined : parent.right
    width: root.horizontal ? undefined : root.thickness
    height: root.horizontal ? root.thickness : undefined
    color: Signal.palette.signal
    opacity: root.active ? 1 : 0
    visible: opacity > 0

    Accessible.ignored: true

    layer.enabled: root.glowAllowed
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.alpha(Signal.palette.glow, Math.min(1, 0.4 * Signal.glowIntensity))
        shadowBlur: 0.25
        shadowHorizontalOffset: 0
        shadowVerticalOffset: 0
        autoPaddingEnabled: true
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.durations.fade
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }
}
