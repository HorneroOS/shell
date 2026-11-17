pragma ComponentBehavior: Bound

import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Shapes

// One surface's share of the atmosphere (visual language section 17):
// a warm lamp wash from one corner, a soft inner highlight along the top
// edge and a gentle vignette (film grain and scanlines live in
// AtmosphereTexture, which goes UNDER the content). Drop this one as
// the LAST child of a surface: it fills its parent and lies over the
// content as a very light veil (every alpha is at most a few percent, so
// text contrast is unchanged in practice). It never takes input and is
// hidden from assistive tech. Do not give it a negative z: that paints it
// behind its parent's own fill.
//
// All strengths come from Atmosphere.levels (user knobs, hard-capped).
// The lamp asks the shared glow budget for a lease and is simply left out
// when the budget is spent; the other parts are not glows.
Item {
    id: root

    // Corner the lamp shines from: topLeft | topRight | bottomLeft |
    // bottomRight | top | bottom. Lamp reach is a fraction of the longer side.
    property string lampOrigin: "topRight"
    property real lampReach: 0.85
    property bool lamp: true
    property bool innerLight: true
    property bool vignette: true
    // Corner radius of the surface, so the highlight stays inside it.
    property real cornerRadius: 0

    readonly property bool shown: Atmosphere.active && width > 0 && height > 0
    readonly property var lv: Atmosphere.levels
    readonly property bool lampWanted: root.shown && root.lamp && root.lv.lamp > 0
    property bool _granted: false
    readonly property bool lampOn: root.lampWanted && root._granted

    onLampWantedChanged: root._syncLamp()
    Component.onCompleted: root._syncLamp()
    Component.onDestruction: Experience.releaseGlow(root)

    function _syncLamp(): void {
        if (root.lampWanted)
            root._granted = Experience.acquireGlow(root, 1);
        else {
            Experience.releaseGlow(root);
            root._granted = false;
        }
    }

    readonly property real _cx: origin.includes("Left") ? 0 : origin.includes("Right") ? width : width / 2
    readonly property real _cy: origin.startsWith("top") ? 0 : origin.startsWith("bottom") ? height : height / 2
    readonly property string origin: root.lampOrigin

    anchors.fill: parent
    enabled: false
    clip: true
    visible: root.shown
    opacity: root.shown ? 1 : 0
    Accessible.ignored: true

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.durations.fade
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.anim.curves.standard
        }
    }

    // Lamp wash.
    Shape {
        anchors.fill: parent
        visible: root.lampOn
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root._cx
                centerY: root._cy
                focalX: centerX
                focalY: centerY
                centerRadius: Math.max(root.width, root.height) * root.lampReach
                GradientStop {
                    position: 0
                    color: Qt.alpha(Atmosphere.lamp, root.lv.lamp)
                }
                GradientStop {
                    position: 0.55
                    color: Qt.alpha(Atmosphere.lamp, root.lv.lamp * 0.35)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Atmosphere.lamp, 0)
                }
            }
            PathRectangle {
                x: 0
                y: 0
                width: root.width
                height: root.height
            }
        }
    }

    // Vignette: transparent in the middle, a touch of shadow at the edges.
    Shape {
        anchors.fill: parent
        visible: root.vignette && root.lv.vignette > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillGradient: RadialGradient {
                centerX: root.width / 2
                centerY: root.height / 2
                focalX: centerX
                focalY: centerY
                centerRadius: Math.hypot(root.width, root.height) / 2
                GradientStop {
                    position: 0
                    color: Qt.alpha(Signal.palette.shadow, 0)
                }
                GradientStop {
                    position: 0.62
                    color: Qt.alpha(Signal.palette.shadow, 0)
                }
                GradientStop {
                    position: 1
                    color: Qt.alpha(Signal.palette.shadow, root.lv.vignette)
                }
            }
            PathRectangle {
                x: 0
                y: 0
                width: root.width
                height: root.height
            }
        }
    }

    // Soft inner highlight: a faint wash under the top edge and a 1 px
    // warm line that fades out toward both ends.
    Rectangle {
        visible: root.innerLight && root.lv.innerLight > 0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.min(28, root.height / 3)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.alpha(Atmosphere.highlight, root.lv.innerLight * 0.6)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Atmosphere.highlight, 0)
            }
        }
    }

    Rectangle {
        visible: root.innerLight && root.lv.innerLight > 0
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.cornerRadius
        anchors.rightMargin: root.cornerRadius
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.alpha(Atmosphere.highlight, 0)
            }
            GradientStop {
                position: 0.5
                color: Qt.alpha(Atmosphere.highlight, root.lv.innerLight * 1.6)
            }
            GradientStop {
                position: 1
                color: Qt.alpha(Atmosphere.highlight, 0)
            }
        }
    }
}
