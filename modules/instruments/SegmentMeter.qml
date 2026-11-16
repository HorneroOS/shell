pragma ComponentBehavior: Bound

import qs.services
import QtQuick

// Discrete VU-style meter (Signal Bezel §6.2). `value` is 0..1; NaN (or
// `available: false`) renders every segment off — never invented data.
// Off `rule`; on `onColor` (default `ink`); above `threshold` `signal`;
// above `critical` (only when a real critical level exists) `alert`.
Item {
    id: root

    property real value: 0
    property bool available: true
    property int count: 24
    property bool vertical: false
    property real segmentWidth: 3
    property real segmentLength: 12
    property real gap: 2
    property real threshold: 0.85
    property real critical: 2
    property color onColor: Signal.palette.ink
    property color offColor: Signal.palette.rule
    property real peak: -1

    readonly property bool live: available && !isNaN(value)
    readonly property int lit: live ? Math.round(Math.max(0, Math.min(1, value)) * count) : 0

    implicitWidth: vertical ? segmentLength : count * segmentWidth + (count - 1) * gap
    implicitHeight: vertical ? count * segmentWidth + (count - 1) * gap : segmentLength

    Accessible.role: Accessible.ProgressBar
    Accessible.name: ""

    Repeater {
        model: root.count

        Rectangle {
            required property int index

            readonly property real level: (index + 1) / root.count
            readonly property bool on: index < root.lit
            readonly property bool isPeak: root.live && root.peak >= 0 && index === Math.max(0, Math.round(root.peak * root.count) - 1)

            x: root.vertical ? 0 : index * (root.segmentWidth + root.gap)
            y: root.vertical ? root.height - (index + 1) * root.segmentWidth - index * root.gap : 0
            width: root.vertical ? root.segmentLength : root.segmentWidth
            height: root.vertical ? root.segmentWidth : root.segmentLength
            color: !on && !isPeak ? root.offColor : level > root.critical ? Signal.palette.alert : level > root.threshold ? Signal.palette.signal : root.onColor
        }
    }
}
