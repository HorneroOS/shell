import qs.components
import qs.services
import qs.config
import QtQuick

// An adjustable level drawn as a segmented meter (Signal Bezel §6.2):
// drag or click along the meter to set it, arrow keys step it. Exposes
// the Slider role with `accessibleName` and the current value.
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
    signal moved(real value)

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
            event.accepted = true;
        } else if (event.key === down) {
            root.moved(Math.max(root.from, root.value - root.stepSize));
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

    MouseArea {
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
