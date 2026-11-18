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

    // The answer goes to the question shown here, never to one that
    // replaced it (the bridge compares the text).
    function send(): void {
        const pend = root.bridge.pendingClarify;
        if (!pend || clarifyInput.text.trim() === "")
            return;
        root.bridge.clarify(pend.runId, clarifyInput.text, root.answeringDetail !== "" ? root.answeringDetail : root.shownDetail);
        clarifyInput.text = "";
        root.answeringDetail = "";
    }

    readonly property string shownDetail: root.bridge.pendingClarify ? root.bridge.pendingClarify.detail : ""
    // The question on screen when the user started typing the answer.
    property string answeringDetail: ""
    onShownDetailChanged: {
        // A different question: drop the half-typed answer to the old one.
        clarifyInput.text = "";
        root.answeringDetail = "";
    }

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
            // Enter only: an answer is never sent because focus left the
            // field (editingFinished fires on blur too).
            onAccepted: root.send()
            onTextEdited: {
                if (root.answeringDetail === "")
                    root.answeringDetail = root.shownDetail;
            }
        }

        TextButton {
            text: AssistantCopy.t("clarify.send", root.lang)
            type: TextButton.Filled
            enabled: !root.bridge.decisionBusy
            onClicked: root.send()
        }
    }
}
