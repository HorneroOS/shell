import QtQuick

// Signal readout (visual language §6.3): an eyebrow label over a large
// tabular number with its unit, inside a `sunken` readout well.
//
//   UiMetric { label: "CPU"; value: "34"; unit: "%" }
//
// `available: false` (or an empty value) renders an em dash in
// `inkMuted`: a readout never shows an invented number. Set `tone` to a
// role name ("signal", "alert") when the value crosses a real threshold.
// `well: false` drops the well for dense rows.
Rectangle {
    id: root

    property string label: ""
    property string value: ""
    property string unit: ""
    property bool available: true
    property string tone: ""
    property bool well: true
    property string size: "readout" // "readout" | "display" | "value"

    readonly property bool _shown: root.available && root.value.length > 0

    implicitWidth: Math.max(labelText.implicitWidth, valueRow.implicitWidth) + (root.well ? Theme.padding.larger * 2 : 0)
    implicitHeight: labelText.implicitHeight + Theme.spacing.small + valueRow.implicitHeight + (root.well ? Theme.padding.normal * 2 : 0)
    radius: Theme.rounding.small
    color: root.well ? Theme.palette.sunken : "transparent"
    border.width: root.well ? 1 : 0
    border.color: Theme.palette.rule

    Accessible.role: Accessible.StaticText
    Accessible.name: root._shown ? `${root.label} ${root.value} ${root.unit}` : `${root.label} unavailable`

    UiText {
        id: labelText

        x: root.well ? Theme.padding.larger : 0
        y: root.well ? Theme.padding.normal : 0
        // Inside a tile narrower than its label ("TOTAL TOKENS" in a
        // three-column row) the label elides instead of running out of it.
        width: root.width > 0 ? Math.min(implicitWidth, Math.max(0, root.width - (root.well ? Theme.padding.larger * 2 : 0))) : implicitWidth
        role: "eyebrow"
        text: root.label
        elide: Text.ElideRight
    }

    Row {
        id: valueRow

        x: labelText.x
        anchors.top: labelText.bottom
        anchors.topMargin: Theme.spacing.small
        spacing: Theme.spacing.small

        UiText {
            role: root.size
            text: root._shown ? root.value : "—"
            color: !root._shown ? Theme.palette.inkMuted : root.tone === "alert" ? Theme.palette.alert : root.tone === "signal" ? Theme.palette.signal : root.tone === "phosphor" ? Theme.palette.phosphor : root.tone === "cue" ? Theme.palette.cue : Theme.palette.ink
        }

        UiText {
            visible: root._shown && root.unit.length > 0
            anchors.baseline: parent.children[0].baseline
            role: "value"
            color: Theme.palette.inkMuted
            text: root.unit
        }
    }
}
