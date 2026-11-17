pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// What this system can do, in two plain lines: the current experience
// mode and layout, and how many of the optional checks (low-latency
// audio, compositor tuning) are ready. Read from the live Experience
// service; a check that cannot be confirmed yet counts as pending, never
// as ready. Details live in Settings, nothing here offers to switch modes.
StyledRect {
    id: root

    readonly property int checksReady: (Experience.studioAudioAvailable ? 1 : 0) + (Experience.hyprlandTuningAvailable ? 1 : 0)
    readonly property int checksTotal: 2
    readonly property string summary: root.checksReady === root.checksTotal ? qsTr("All %1 checks ready").arg(root.checksTotal) : qsTr("%1 of %2 checks ready").arg(root.checksReady).arg(root.checksTotal)

    Layout.fillWidth: true
    implicitHeight: lines.implicitHeight + Appearance.padding.normal * 2

    radius: Appearance.rounding.small
    color: "transparent"
    border.width: 1
    border.color: Signal.palette.rule

    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("Mode %1, %2").arg(Experience.label).arg(root.summary)

    ColumnLayout {
        id: lines

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Appearance.padding.normal
        anchors.rightMargin: Appearance.padding.normal
        spacing: Appearance.spacing.smaller

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Mode %1 · Cockpit layout").arg(Experience.label)
            mono: true
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            text: root.summary
            mono: true
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.smaller
            elide: Text.ElideRight
        }
    }
}
