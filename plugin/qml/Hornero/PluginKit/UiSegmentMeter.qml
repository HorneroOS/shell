import QtQuick

// Segmented meter (visual language §6.2): discrete VU-style segments,
// square corners, 2 px gap.
//
//   UiSegmentMeter { value: System.cpuPerc; count: 24 }
//
// Off segments are `rule`; on segments `ink` (or `phosphor` with
// `vu: true`, the hardware VU convention for vertical level meters);
// segments above `threshold` are `signal`; `alert` is used only above a
// real `critical` value reported by the source (leave it at -1 when the
// sensor reports none). `available: false` turns every segment off — a
// meter never shows an invented level. `peak` draws a peak-hold marker.
// Pair every meter with its numeric value (UiMeterRow does both).
Item {
    id: root

    property real value: 0
    property bool available: true
    property int count: 8
    property string orientation: "horizontal"
    property real threshold: 0.85
    property real critical: -1
    property bool vu: false
    // Peak-hold level (0–1); negative hides the marker.
    property real peak: -1
    // Segment thickness and length: 3 × 10 in bars, 3 × 12 in panels.
    property int segmentThickness: 3
    property int segmentLength: 12
    property int gap: 2
    property string accessibleName: ""

    readonly property bool vertical: root.orientation === "vertical"
    readonly property real _clamped: Math.max(0, Math.min(1, root.value))
    readonly property int lit: root.available && isFinite(root.value) ? Math.round(root._clamped * root.count) : 0
    readonly property int peakIndex: root.available && root.peak >= 0 ? Math.max(0, Math.min(root.count - 1, Math.round(root.peak * root.count) - 1)) : -1

    implicitWidth: root.vertical ? root.segmentLength : root.count * (root.segmentThickness + root.gap) - root.gap
    implicitHeight: root.vertical ? root.count * (root.segmentThickness + root.gap) - root.gap : root.segmentLength

    Accessible.role: Accessible.ProgressBar
    Accessible.name: root.accessibleName.length > 0 ? root.accessibleName : root.available ? `${Math.round(root._clamped * 100)} %` : "unavailable"

    Repeater {
        model: root.count

        delegate: Rectangle {
            required property int index

            readonly property real level: (index + 1) / root.count
            readonly property bool on: index < root.lit || index === root.peakIndex

            x: root.vertical ? 0 : index * (root.segmentThickness + root.gap)
            y: root.vertical ? root.height - (index + 1) * (root.segmentThickness + root.gap) + root.gap : 0
            width: root.vertical ? root.width : root.segmentThickness
            height: root.vertical ? root.segmentThickness : root.height
            color: !on ? Theme.palette.rule : root.critical >= 0 && level > root.critical ? Theme.palette.alert : level > root.threshold ? Theme.palette.signal : root.vu ? Theme.palette.phosphor : Theme.palette.ink
        }
    }
}
