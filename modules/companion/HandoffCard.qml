pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.modules.companion
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// What a quick (Level A) question ran into, handed to the Workbench by
// Javi Radio or the launcher's `>ai` row when the user pressed "Open the
// Workbench" (AssistantRun.handoffRecord). The quick run was read-only
// (`--mode ask`): horneroctl denied its approval or the quick ask stopped
// it, and horneroctl refuses to approve a non-agent run, so this card
// has NO Allow button. It shows the exact (redacted, hidden characters
// made visible) request as plain text and offers the only honest ways
// forward: re-run the question as a new Agent run (its approvals then
// arrive on the normal ApprovalCard, bound to the exact request), edit
// it first, or dismiss.
Rectangle {
    id: root

    required property var bridge

    readonly property var rec: AssistantRun.handoffRecord
    readonly property string lang: root.bridge.lang

    // Same anti-misclick delay as the approval card: a click aimed at
    // something else cannot land on a card that just appeared.
    property bool armed: false
    onRecChanged: {
        root.armed = false;
        if (root.rec)
            armTimer.restart();
    }

    Timer {
        id: armTimer

        interval: 700
        onTriggered: root.armed = true
    }

    function t(key: string): string {
        return AssistantCopy.t(key, root.lang);
    }

    visible: root.rec !== null
    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + Appearance.padding.normal * 2
    radius: Appearance.rounding.small
    color: Qt.alpha(Signal.palette.cue, 0.08)
    border.width: 1
    border.color: Qt.alpha(Signal.palette.cue, 0.6)

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: root.t("handoff.title").toUpperCase()
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.smaller
                font.bold: true
                color: Signal.palette.cue
                elide: Text.ElideRight
            }

            StyledText {
                text: root.rec ? root.t("handoff.from." + root.rec.source) : ""
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.inkMuted
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.t("handoff.question")
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        StyledText {
            Layout.fillWidth: true
            text: root.rec ? root.rec.question : ""
            textFormat: Text.PlainText
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.ink
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.rec !== null && root.rec.detail !== ""
            text: root.rec ? root.t("handoff.kind." + root.rec.kind) : ""
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.alert
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.rec !== null && root.rec.detail !== ""
            text: root.rec ? root.rec.detail : ""
            textFormat: Text.PlainText
            font.family: Appearance.font.family.mono
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.ink
            wrapMode: Text.WrapAnywhere
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.rec !== null && (root.rec.truncated || root.rec.flagged)
            text: root.rec ? [root.rec.truncated ? root.t("handoff.truncated") : "", root.rec.flagged ? root.t("handoff.flagged") : ""].filter(s => s !== "").join(" ") : ""
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.alert
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            text: root.t("handoff.nothing-ran") + " " + root.t("handoff.how")
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
            wrapMode: Text.Wrap
        }

        Flow {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            TextButton {
                text: root.t("handoff.run-agent")
                type: TextButton.Tonal
                enabled: root.armed && !root.bridge.busy && !AssistantRun.pendingDecision
                onClicked: root.bridge.continueHandoff()
            }

            TextButton {
                text: root.t("handoff.edit")
                type: TextButton.Tonal
                enabled: root.armed
                onClicked: root.bridge.editHandoff()
            }

            TextButton {
                text: root.t("handoff.dismiss")
                type: TextButton.Tonal
                onClicked: AssistantRun.reset()
            }
        }
    }
}
