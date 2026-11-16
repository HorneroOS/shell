import QtQuick

// One labelled telemetry row: eyebrow label, segmented meter filling the
// middle, tabular value on the right (visual language §6.2: a meter
// never stands alone).
//
//   UiMeterRow { label: "GPU"; value: System.gpuPerc; valueText: "22 %"
//                available: System.gpuAvailable }
Item {
    id: root

    property string label: ""
    property real value: 0
    property string valueText: ""
    property bool available: true
    property int count: 24
    property real threshold: 0.85
    property real critical: -1
    property int labelWidth: 40
    property int valueWidth: 64

    implicitWidth: root.labelWidth + root.count * 5 - 2 + root.valueWidth + Theme.spacing.normal * 2
    implicitHeight: Math.max(meter.implicitHeight, valueLabel.implicitHeight)

    Accessible.role: Accessible.StaticText
    Accessible.name: `${root.label}: ${root.available ? root.valueText : "unavailable"}`

    UiText {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelWidth
        role: "eyebrow"
        text: root.label
        elide: Text.ElideRight
    }

    UiSegmentMeter {
        id: meter

        x: root.labelWidth + Theme.spacing.normal
        anchors.verticalCenter: parent.verticalCenter
        // Whole segments that fit the row's middle.
        count: root.width <= 0 ? root.count : Math.max(4, Math.floor((root.width - root.labelWidth - root.valueWidth - Theme.spacing.normal * 2 + gap) / (segmentThickness + gap)))
        value: root.value
        available: root.available
        threshold: root.threshold
        critical: root.critical
        segmentLength: 10
    }

    UiText {
        id: valueLabel

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.valueWidth
        horizontalAlignment: Text.AlignRight
        role: "value"
        color: root.available ? Theme.palette.ink : Theme.palette.inkMuted
        text: root.available && root.valueText.length > 0 ? root.valueText : "—"
    }
}
