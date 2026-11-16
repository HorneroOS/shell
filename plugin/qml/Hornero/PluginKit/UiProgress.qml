import QtQuick
import QtQuick.Controls

// Signal progress: a 4 px `sunken` track with a `signal` fill. Use it for
// task progress (downloads, timers). Telemetry levels use UiSegmentMeter.
// Indeterminate progress is a static half-fill in `inkMuted` with a
// "working" description — no pulsing (RFC §2: no constant blinking).
ProgressBar {
    id: root

    property string accessibleName: ""
    // Role used for the fill: "signal" (default), "phosphor", "cue",
    // "alert".
    property string tone: "signal"

    from: 0
    to: 1
    value: 0
    indeterminate: false

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.ProgressBar

    background: Rectangle {
        implicitWidth: 160
        implicitHeight: 4
        radius: 1
        color: Theme.palette.sunken
        border.width: 1
        border.color: Theme.palette.rule
    }

    contentItem: Item {
        implicitHeight: 4

        Rectangle {
            width: root.indeterminate ? parent.width * 0.5 : root.position * parent.width
            height: parent.height
            radius: 1
            color: root.indeterminate ? Theme.palette.inkMuted : root.tone === "phosphor" ? Theme.palette.phosphor : root.tone === "cue" ? Theme.palette.cue : root.tone === "alert" ? Theme.palette.alert : Theme.palette.signal
        }
    }
}
