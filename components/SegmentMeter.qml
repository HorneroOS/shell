import qs.services
import QtQuick

// Segmented meter (signal-visual-language §6.2): square segments, 2 px
// gap, off `rule`, on `ink` (horizontal) or `phosphor` (vertical VU),
// `signal` above `threshold`, `alert` only above a real `critical`
// threshold the caller supplies from its sensor. The real-data rule
// (§6.1) is the caller's: bind `value` to a native service or a declared
// provider, set `available: false` when the source is missing (all
// segments off) and always print the numeric value beside the meter —
// a meter never stands alone. No animation: numerals and segments move
// only when the sampled value does (VU ballistics live in the provider).
Item {
    id: root

    // Normalised level, 0..1. Clamped; NaN renders as unavailable.
    property real value: 0
    property int count: 10
    property bool vertical: false
    property bool available: true
    // Fraction at/above which lit segments turn `signal` (0.85 levels,
    // 0.8 of the critical value for temperatures).
    property real threshold: 0.85
    // Fraction at/above which lit segments turn `alert`; -1 disables it
    // (only set from a critical threshold the sensor actually reports).
    property real critical: -1
    property int segmentLength: 10
    property int segmentThickness: 3
    property int gap: 2
    property string accessibleName: ""
    // Cockpit Clear region tone (services/ClearInk.qml): lit segments in the
    // polarity's ink, off segments the same ink at 30 % (§12.1 step 5).
    property var tone: null

    readonly property real clamped: isNaN(root.value) ? 0 : Math.max(0, Math.min(1, root.value))
    readonly property int lit: root.available && !isNaN(root.value) ? Math.round(root.clamped * root.count) : 0
    readonly property bool toned: root.tone !== null && root.tone.active === true
    readonly property color onColor: root.toned ? root.tone.ink : root.vertical ? Signal.palette.phosphor : Signal.palette.ink

    implicitWidth: root.vertical ? root.segmentLength : root.count * root.segmentThickness + (root.count - 1) * root.gap
    implicitHeight: root.vertical ? root.count * root.segmentThickness + (root.count - 1) * root.gap : root.segmentLength

    Accessible.role: Accessible.StaticText
    Accessible.name: root.accessibleName
    Accessible.description: root.available && !isNaN(root.value) ? `${Math.round(root.clamped * 100)}%` : qsTr("unavailable")

    Repeater {
        model: root.count

        Rectangle {
            required property int index

            // Vertical meters fill from the bottom.
            readonly property int order: root.vertical ? root.count - 1 - index : index
            readonly property real fraction: (order + 1) / root.count
            readonly property bool isLit: order < root.lit

            x: root.vertical ? 0 : index * (root.segmentThickness + root.gap)
            y: root.vertical ? index * (root.segmentThickness + root.gap) : 0
            width: root.vertical ? root.segmentLength : root.segmentThickness
            height: root.vertical ? root.segmentThickness : root.segmentLength
            color: !isLit ? (root.toned ? Qt.alpha(root.tone.ink, root.tone.offAlpha) : Signal.palette.rule) : (root.critical >= 0 && fraction > root.critical) ? Signal.palette.alert : fraction > root.threshold ? Signal.palette.signal : root.onColor

            Accessible.ignored: true
        }
    }
}
