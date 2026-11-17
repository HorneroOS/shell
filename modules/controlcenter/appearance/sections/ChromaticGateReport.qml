pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Contrast gate report of the candidate: each measured pair with its
// ratio against the minimum for the resolved level. Failing rows (the
// engine never ships any) are shown, never hidden.
ColumnLayout {
    id: root

    // {level, passed, rows: [{label, ratio, min, pass}]}
    property var gates: null
    property var adjustments: []

    property bool showAll: false

    spacing: Appearance.spacing.small / 2
    Accessible.role: Accessible.List
    Accessible.name: qsTr("Contrast report")

    StyledText {
        text: root.gates ? (root.gates.passed ? qsTr("All %1 checks pass at the %2 level.").arg(root.gates.rows.length).arg(root.gates.level) : qsTr("Some checks fail at the %1 level.").arg(root.gates.level)) : qsTr("No candidate yet.")
        font.pointSize: Appearance.font.size.small
        color: root.gates && !root.gates.passed ? Signal.palette.alert : Signal.palette.inkMuted
    }

    TextButton {
        visible: !!root.gates && root.gates.passed && root.gates.rows.length > 0
        text: root.showAll ? qsTr("Hide measurements") : qsTr("Show measurements")
        type: TextButton.Text
        onClicked: root.showAll = !root.showAll
    }

    Flow {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small
        visible: root.showAll || (!!root.gates && !root.gates.passed)

        Repeater {
            model: root.gates ? root.gates.rows : []

            StyledRect {
                id: chip

                required property var modelData

                implicitWidth: chipLabel.implicitWidth + Appearance.padding.normal * 2
                implicitHeight: chipLabel.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.small
                color: modelData.pass ? Signal.palette.phosphorWell : Signal.palette.alertWell
                Accessible.role: Accessible.StaticText
                Accessible.name: qsTr("%1: %2 to 1, needs %3: %4").arg(modelData.label).arg(modelData.ratio.toFixed(1)).arg(modelData.min.toFixed(1)).arg(modelData.pass ? qsTr("pass") : qsTr("fail"))

                StyledText {
                    id: chipLabel

                    anchors.centerIn: parent
                    mono: true
                    text: `${chip.modelData.pass ? "✓" : "✗"} ${chip.modelData.label} ${chip.modelData.ratio.toFixed(1)}`
                    font.pointSize: Appearance.font.size.smaller
                    color: chip.modelData.pass ? Signal.palette.onPhosphorWell : Signal.palette.onAlertWell
                }
            }
        }
    }

    StyledText {
        visible: root.adjustments.length > 0
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: qsTr("Adjusted to pass: %1").arg(root.adjustments.map(a => `${a.role} (${a.reason})`).join(", "))
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.inkMuted
    }
}
