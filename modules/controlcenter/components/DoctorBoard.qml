pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Edition doctor board: the verbatim result of `horneroctl <edition> doctor`
// as a channel list. Each row says OK or FAIL in words and a glyph (never
// colour alone) and keeps the CLI's detail line. When horneroctl cannot
// answer, the board says "Unavailable" and why — it never shows a pass.
ColumnLayout {
    id: root

    property string edition: ""
    property var checks: []
    property bool loading: false
    // Non-empty when horneroctl is missing or answered with garbage.
    property string error: ""
    property string summary: ""
    readonly property int passCount: root.checks.filter(c => c.ok).length
    readonly property bool unavailable: !root.loading && (root.error.length > 0 || root.checks.length === 0)

    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        Eyebrow {
            Layout.fillWidth: true
            label: qsTr("%1 doctor").arg(root.edition)
        }

        StyledText {
            mono: true
            text: root.loading ? qsTr("Checking") : root.unavailable ? qsTr("Unavailable") : qsTr("%1 of %2 pass").arg(root.passCount).arg(root.checks.length)
            color: root.unavailable ? Signal.palette.inkMuted : root.passCount === root.checks.length ? Signal.palette.phosphor : Signal.palette.alert
            font.pointSize: Appearance.font.size.small
            Accessible.name: text
        }
    }

    SegmentMeter {
        Layout.fillWidth: true
        visible: !root.unavailable && !root.loading
        count: Math.max(1, Math.min(root.checks.length, 24))
        value: root.checks.length > 0 ? root.passCount / root.checks.length : 0
        threshold: 1.1
        available: !root.unavailable
        accessibleName: qsTr("Passing checks")
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.unavailable || root.loading
        text: root.loading ? qsTr("Running checks…") : root.error.length > 0 ? root.error : qsTr("No checks reported.")
        wrapMode: Text.WordWrap
        color: Signal.palette.inkMuted
        font.pointSize: Appearance.font.size.small
    }

    Repeater {
        model: root.checks

        delegate: ColumnLayout {
            id: row

            required property var modelData
            required property int index

            Layout.fillWidth: true
            spacing: 0

            Hairline {
                Layout.fillWidth: true
                visible: row.index > 0
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.padding.small
                Layout.bottomMargin: Appearance.padding.small
                spacing: Appearance.spacing.normal

                Glyph {
                    Layout.alignment: Qt.AlignTop
                    name: row.modelData.ok ? "circle-check" : "alert-triangle"
                    color: row.modelData.ok ? Signal.palette.phosphor : Signal.palette.alert
                    font.pointSize: Appearance.font.size.normal
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            mono: true
                            text: row.modelData.name
                            font.pointSize: Appearance.font.size.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            mono: true
                            text: row.modelData.ok ? qsTr("OK") : qsTr("FAIL")
                            color: row.modelData.ok ? Signal.palette.phosphor : Signal.palette.alert
                            font.pointSize: Appearance.font.size.small
                            font.weight: Font.DemiBold
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: row.modelData.detail.length > 0
                        text: row.modelData.detail
                        wrapMode: Text.WordWrap
                        color: Signal.palette.inkMuted
                        font.pointSize: Appearance.font.size.small
                    }
                }

                Accessible.role: Accessible.StaticText
                Accessible.name: `${row.modelData.name}: ${row.modelData.ok ? qsTr("OK") : qsTr("FAIL")}. ${row.modelData.detail}`
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.summary.length > 0 && !root.unavailable
        text: root.summary
        color: Signal.palette.inkMuted
        font.pointSize: Appearance.font.size.small
        wrapMode: Text.WordWrap
    }
}
