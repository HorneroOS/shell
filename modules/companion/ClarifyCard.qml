pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.modules.companion
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Pending clarification: the gateway asks a question, the user
// answers it (an explicit action on that run). Shared by the panel
// and the Workbench so both show the same pending request.
ColumnLayout {
    id: root

    required property var bridge

    readonly property string lang: root.bridge.lang

    Layout.fillWidth: true
    visible: root.bridge.pendingClarify !== null
    spacing: Appearance.spacing.small

    StyledText {
        Layout.fillWidth: true
        text: AssistantCopy.t("clarify.title", root.lang)
        font.family: Appearance.font.family.mono
        font.pointSize: Appearance.font.size.smaller
        color: Signal.palette.alert
    }

    StyledText {
        Layout.fillWidth: true
        text: root.bridge.pendingClarify ? root.bridge.pendingClarify.detail : ""
        textFormat: Text.PlainText
        font.pointSize: Appearance.font.size.small
        color: Signal.palette.ink
        wrapMode: Text.Wrap
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledInputField {
            id: clarifyInput

            Layout.fillWidth: true
            horizontalAlignment: TextInput.AlignLeft
            onEditingFinished: {
                if (text.trim() !== "" && root.bridge.pendingClarify) {
                    root.bridge.clarify(root.bridge.pendingClarify.runId, text);
                    text = "";
                }
            }
        }

        TextButton {
            text: AssistantCopy.t("clarify.send", root.lang)
            type: TextButton.Filled
            enabled: !root.bridge.decisionBusy
            onClicked: {
                if (root.bridge.pendingClarify) {
                    root.bridge.clarify(root.bridge.pendingClarify.runId, clarifyInput.text);
                    clarifyInput.text = "";
                }
            }
        }
    }
}
