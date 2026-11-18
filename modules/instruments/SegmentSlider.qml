import qs.components
import qs.components.motion
import qs.services
import qs.config
import QtQuick

// An adjustable level drawn as a segmented meter (Signal Bezel §6.2):
// drag or click along the meter to set it, arrow keys step it. Exposes
// the Slider role with `accessibleName` and the current value.
//
// The handle is a small cap riding the fill edge. At rest it shows a
// Hornero Glyph (`glyph`, a grip by default). While the slider is pressed,
// scrolled (`nudge()`) or stepped, the cap becomes the value: `valueText`
// in Plex Mono on `signal`, because amber marks a live interaction. It
// swaps with a quick cross-fade (instant with motion off) and returns to
// the glyph `appearance.sliders.readoutHold` ms after the last change.
// `appearance.sliders.readout` turns the readout off. The cap is
// decorative: the owner's separate value label and the Slider role's
// value stay the accessible readout.
FocusScope {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real stepSize: 0.05
    property bool vertical: true
    property int count: 24
    property real segmentLength: 12
    property real threshold: 1
    property string accessibleName: ""
    readonly property real fraction: to > from ? (value - from) / (to - from) : 0
    // Rest glyph on the handle and the text it shows while adjusting.
    property string glyph: vertical ? "grip-horizontal" : "grip-vertical"
    property string valueText: Math.round(value * 100)
    // Also read out changes that come from elsewhere (keys, a wheel on the
    // owner): the OSD sets this; a seek bar that moves on its own does not.
    property bool readoutOnChange: false
    readonly property bool reading: Config.appearance.sliders.readout && (pointer.pressed || readoutTimer.running)
    signal moved(real value)

    // Show the value on the handle for a moment (a scroll on the owner).
    function nudge(): void {
        readoutTimer.restart();
    }

    onValueChanged: {
        if (root.readoutOnChange && root._settled)
            root.nudge();
    }
    property bool _settled: false
    Component.onCompleted: _settled = true

    implicitWidth: meter.implicitWidth
    implicitHeight: meter.implicitHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.Slider
    Accessible.name: root.accessibleName
    Accessible.description: `${Math.round(root.value * 100)} %`
    Accessible.focusable: true

    function setFromPos(px: real, py: real): void {
        const f = root.vertical ? 1 - py / height : px / width;
        const v = root.from + Math.max(0, Math.min(1, f)) * (root.to - root.from);
        root.moved(Math.round(v / root.stepSize) * root.stepSize);
    }

    Keys.onPressed: event => {
        const up = root.vertical ? Qt.Key_Up : Qt.Key_Right;
        const down = root.vertical ? Qt.Key_Down : Qt.Key_Left;
        if (event.key === up) {
            root.moved(Math.min(root.to, root.value + root.stepSize));
            root.nudge();
            event.accepted = true;
        } else if (event.key === down) {
            root.moved(Math.max(root.from, root.value - root.stepSize));
            root.nudge();
            event.accepted = true;
        }
    }

    SegmentMeter {
        id: meter

        anchors.fill: parent
        vertical: root.vertical
        count: root.count
        segmentLength: root.segmentLength
        value: root.fraction
        threshold: root.threshold
    }

    Rectangle {
        visible: root.activeFocus
        anchors.fill: parent
        anchors.margins: -4
        radius: Appearance.rounding.small + 2
        color: "transparent"
        border.width: 2
        border.color: Signal.palette.focus
    }

    Timer {
        id: readoutTimer

        interval: Math.max(100, Config.appearance.sliders.readoutHold)
    }

    // Handle cap on the fill edge, centred across the meter (it may
    // overhang it) and kept inside it along the travel axis.
    Rectangle {
        id: cap

        readonly property real restSize: 18
        readonly property real thin: 16
        readonly property real along: root.vertical ? root.height : root.width
        readonly property real capAlong: root.vertical ? height : width
        // Same mapping as the pointer (setFromPos): the full travel length.
        readonly property real f: Math.max(0, Math.min(1, root.fraction))
        readonly property real edge: root.vertical ? (1 - f) * along : f * along
        readonly property real pos: Math.max(0, Math.min(along - capAlong, edge - capAlong / 2))

        Accessible.ignored: true
        visible: root.enabled && along > capAlong
        width: root.reading ? Math.max(restSize, readout.implicitWidth + 8) : restSize
        height: thin
        x: root.vertical ? (root.width - width) / 2 : pos
        y: root.vertical ? pos : (root.height - height) / 2
        radius: Appearance.rounding.small
        color: root.reading ? Signal.palette.signal : Signal.layer(Signal.palette.panel, 2)
        border.width: 1
        border.color: root.reading ? Signal.palette.signal : Signal.palette.ruleStrong

        Behavior on width {
            enabled: Choreography.animated

            NumberAnimation {
                duration: Choreography.quick
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Choreography.curves.standard
            }
        }

        Behavior on color {
            enabled: Choreography.animated

            ColorAnimation {
                duration: Choreography.fade
            }
        }

        Glyph {
            anchors.centerIn: parent
            name: root.glyph
            color: Signal.palette.inkMuted
            size: Math.max(7, Appearance.font.size.small - 2)
            opacity: root.reading ? 0 : 1

            Behavior on opacity {
                enabled: Choreography.animated

                NumberAnimation {
                    duration: Choreography.fade
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Choreography.curves.standard
                }
            }
        }

        StyledText {
            id: readout

            anchors.centerIn: parent
            mono: true
            text: root.valueText
            color: Signal.palette.onSignal
            font.pointSize: Math.max(7, Appearance.font.size.small - 1)
            font.weight: Font.Medium
            opacity: root.reading ? 1 : 0

            Behavior on opacity {
                enabled: Choreography.animated

                NumberAnimation {
                    duration: Choreography.fade
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Choreography.curves.standard
                }
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        anchors.margins: -4
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: event => root.setFromPos(event.x - 4, event.y - 4)
        onPositionChanged: event => {
            if (pressed)
                root.setFromPos(event.x - 4, event.y - 4);
        }
    }
}
