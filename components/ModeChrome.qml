import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Effects

// Experience-mode chrome (RFC 0001 §5a, signal-visual-language §13): what
// makes Focus, Everyday, Signal, Gaming and Studio read as different
// places at a glance, beyond the small mode chip. Drop it as a child of a
// bar slab, above the slab's own background and below its content:
//
// - wash: a faint wash of the mode accent over the slab;
// - edge: a 1 px hairline (or a 2 px glowing line) on the edge facing the
//   content, in the mode accent;
// - scanlines: the Signal-mode scope texture on the slab.
//
// Everything follows Experience.chrome* and is user-tunable per mode
// (Control Center > Experience). It never takes input and is hidden from
// assistive tech.
Item {
    id: root

    // Edge of the parent the line sits on ("top" | "bottom" | "left" | "right").
    property string edge: "bottom"
    property real radius: 0

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property string accentRole: Experience.chromeAccent
    readonly property color accent: root.accentRole === "none" ? "transparent" : Signal.palette[root.accentRole]
    readonly property bool lineGlow: Experience.chromeEdge === "glow" && !Appearance.anim.reduced && root.visible
    // Shell-wide glow budget (visual language §9).
    property bool _granted: false
    readonly property bool lineGlowing: root.lineGlow && root._granted

    onLineGlowChanged: root._syncGlow()
    Component.onCompleted: root._syncGlow()
    Component.onDestruction: Experience.releaseGlow(root)

    function _syncGlow(): void {
        if (root.lineGlow)
            root._granted = Experience.acquireGlow(root, 0);
        else {
            Experience.releaseGlow(root);
            root._granted = false;
        }
    }

    anchors.fill: parent
    enabled: false
    visible: Experience.chromeActive
    Accessible.ignored: true

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.accent
        opacity: Experience.chromeWash
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.durations.fade
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Math.round(root.radius / 3)
        clip: true
        visible: Experience.scanlines

        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl(`${Quickshell.shellDir}/assets/atmosphere/scanlines.png`)
            fillMode: Image.Tile
            smooth: false
            opacity: Experience.scanlineOpacity
            asynchronous: true
        }
    }

    Rectangle {
        id: line

        readonly property int weight: Experience.chromeEdge === "glow" ? 2 : 1

        anchors.top: root.edge === "bottom" ? undefined : parent.top
        anchors.bottom: root.edge === "top" ? undefined : parent.bottom
        anchors.left: root.edge === "right" ? undefined : parent.left
        anchors.right: root.edge === "left" ? undefined : parent.right
        // Stops short of rounded corners so the line never pokes out of a
        // pill.
        anchors.leftMargin: root.horizontal ? Math.round(root.radius * 0.6) : 0
        anchors.rightMargin: root.horizontal ? Math.round(root.radius * 0.6) : 0
        anchors.topMargin: root.horizontal ? 0 : Math.round(root.radius * 0.6)
        anchors.bottomMargin: root.horizontal ? 0 : Math.round(root.radius * 0.6)
        width: root.horizontal ? undefined : weight
        height: root.horizontal ? weight : undefined
        color: root.accent
        opacity: Experience.chromeEdge === "off" ? 0 : 1
        visible: opacity > 0

        layer.enabled: root.lineGlowing
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
                easing.type: Easing.OutCubic
            }
        }
    }
}
