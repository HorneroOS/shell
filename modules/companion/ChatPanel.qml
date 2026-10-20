pragma ComponentBehavior: Bound

import qs.components
import qs.modules.companion
import Quickshell.Io
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import Quickshell

// Javi's chat panel (shell#234, #239, #240, #241): the native Hermes
// conversation surface, styled as Hornero 199X retrofuturism —
// phosphor status light, mono micro-labels, a subtle scanline header —
// over readable Material bubbles. Presentation only: every action
// goes through AssistantBridge -> `horneroctl assistant ... --json`.
// Approvals/clarifications are explicit user actions, never
// auto-answered. Reduced motion disables the shimmer; themes keep
// WCAG contrast in light and dark.
Item {
    id: root

    required property var bridge

    property int dotPhase: 0

    visible: root.bridge.chatOpen
    implicitWidth: 392
    implicitHeight: 560

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.durations.normal
            easing.type: Easing.OutCubic
        }
    }
    opacity: root.bridge.chatOpen ? 1 : 0
    scale: root.bridge.chatOpen ? 1 : 0.96

    Timer {
        interval: 400
        running: root.bridge.busy && !CompanionStore.reducedMotion
        repeat: true
        onTriggered: root.dotPhase = (root.dotPhase + 1) % 4
    }

    function sendCurrent(): void {
        const text = input.text.trim();
        if (text === "" && root.bridge.attachments.length === 0)
            return;
        root.bridge.ask(text);
        input.text = "";
    }

    StyledRect {
        id: card

        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Colours.palette.m3surfaceContainer

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            // -- Header: Javi identity + backend status ---------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                Image {
                    source: `${Quickshell.shellDir}/assets/companion/frames/default-idle.png`
                    width: 34
                    height: 34
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                }

                ColumnLayout {
                    spacing: 0

                    StyledText {
                        text: qsTr("Javi · el Hornero")
                        font.pointSize: Appearance.font.size.normal
                        font.bold: true
                        color: Colours.palette.m3onSurface
                    }

                    StyledText {
                        text: root.bridge.busy ? qsTr("pensando") + ".".repeat(root.dotPhase) : (root.bridge.gatewayReachable ? qsTr("Hermes conectado · loopback") : qsTr("Hermes no disponible"))
                        font.family: Appearance.font.family.mono
                        font.pointSize: Appearance.font.size.smaller
                        color: root.bridge.gatewayReachable ? Colours.palette.m3primary : Colours.palette.m3error
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                // Phosphor status light (retro 199X accent).
                Rectangle {
                    implicitWidth: 9
                    implicitHeight: 9
                    radius: 5
                    color: root.bridge.busy ? Colours.palette.m3tertiary : root.bridge.gatewayReachable ? Colours.palette.m3primary : Colours.palette.m3error
                    opacity: root.bridge.busy && !CompanionStore.reducedMotion ? (root.dotPhase % 2 === 0 ? 1 : 0.35) : 1
                }

                IconButton {
                    icon: "delete_sweep"
                    type: IconButton.Text
                    label.text: qsTr("Clear chat")
                    onClicked: root.bridge.clearHistory()
                }

                IconButton {
                    icon: "close"
                    type: IconButton.Text
                    label.text: qsTr("Close chat")
                    onClicked: root.bridge.chatOpen = false
                }
            }

            // Scanline accent under the header (static; no shimmer
            // when reduced motion is on).
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 2
                color: Qt.alpha(Colours.palette.m3primary, CompanionStore.reducedMotion ? 0.25 : 0.45)
                radius: 1
            }

            // -- Conversation -----------------------------------------
            ListView {
                id: view

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Appearance.spacing.normal
                model: root.bridge.history
                cacheBuffer: 400

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: view
                }

                onCountChanged: view.positionViewAtEnd()
                onContentHeightChanged: {
                    if (view.atYEnd)
                        view.positionViewAtEnd();
                }

                delegate: Item {
                    required property var modelData

                    width: ListView.view.width
                    implicitHeight: bubble.implicitHeight

                    StyledRect {
                        id: bubble

                        readonly property bool mine: modelData.role === "user"
                        readonly property bool system: modelData.role === "system"

                        anchors.right: bubble.mine ? parent.right : undefined
                        anchors.left: bubble.mine ? undefined : parent.left
                        width: Math.min(parent.width * 0.86, textItem.implicitWidth + Appearance.padding.large * 2)
                        implicitHeight: textItem.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.normal
                        color: bubble.system ? Qt.alpha(Colours.palette.m3error, 0.14) : bubble.mine ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh

                        StyledText {
                            id: textItem

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Appearance.padding.large
                            text: modelData.text
                            textFormat: modelData.role === "assistant" ? Text.MarkdownText : Text.PlainText
                            font.pointSize: Appearance.font.size.small
                            color: bubble.mine ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                            wrapMode: Text.Wrap
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }
                    }
                }

                // Streaming assistant bubble (live deltas).
                footer: ColumnLayout {
                    width: view.width
                    spacing: Appearance.spacing.normal

                    StyledRect {
                        visible: root.bridge.busy
                        Layout.alignment: Qt.AlignLeft
                        implicitWidth: Math.min(view.width * 0.86, streamText.implicitWidth + Appearance.padding.large * 2)
                        implicitHeight: streamText.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.normal
                        color: Colours.palette.m3surfaceContainerHigh

                        StyledText {
                            id: streamText

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Appearance.padding.large
                            text: root.bridge.streamText !== "" ? root.bridge.streamText : qsTr("Javi está pensando") + ".".repeat(root.dotPhase)
                            textFormat: Text.MarkdownText
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3onSurface
                            wrapMode: Text.Wrap
                        }
                    }

                    // Empty state: suggestion chips.
                    Flow {
                        visible: view.count === 0 && !root.bridge.busy
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        Repeater {
                            model: [qsTr("¿Qué updates hay pendientes?"), qsTr("¿Por qué está lenta la máquina?"), qsTr("Mostrame los themes GTK"), qsTr("¿Qué podés hacer?")]

                            delegate: TextButton {
                                required property var modelData

                                text: modelData
                                type: TextButton.Tonal
                                onClicked: root.bridge.ask(modelData)
                            }
                        }
                    }
                }
            }

            // -- Pending approval card ---------------------------------
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.bridge.pendingApproval !== null
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Javi necesita tu OK:")
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.smaller
                    color: Colours.palette.m3error
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.bridge.pendingApproval ? root.bridge.pendingApproval.detail : ""
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurface
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    spacing: Appearance.spacing.small

                    TextButton {
                        text: qsTr("Approve")
                        type: TextButton.Filled
                        onClicked: root.bridge.approve(root.bridge.pendingApproval.runId, "approve")
                    }

                    TextButton {
                        text: qsTr("Deny")
                        type: TextButton.Tonal
                        onClicked: root.bridge.approve(root.bridge.pendingApproval.runId, "deny")
                    }
                }
            }

            // -- Pending clarification card ----------------------------
            ColumnLayout {
                Layout.fillWidth: true
                visible: root.bridge.pendingClarify !== null
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.bridge.pendingClarify ? root.bridge.pendingClarify.detail : ""
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3onSurface
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    StyledInputField {
                        id: clarifyInput

                        Layout.fillWidth: true
                        horizontalAlignment: TextInput.AlignLeft
                        placeholderText: qsTr("Tu respuesta…")
                        onEditingFinished: {
                            if (text.trim() !== "" && root.bridge.pendingClarify) {
                                root.bridge.clarify(root.bridge.pendingClarify.runId, text);
                                text = "";
                            }
                        }
                    }

                    TextButton {
                        text: qsTr("Answer")
                        type: TextButton.Filled
                        onClicked: {
                            if (root.bridge.pendingClarify) {
                                root.bridge.clarify(root.bridge.pendingClarify.runId, clarifyInput.text);
                                clarifyInput.text = "";
                            }
                        }
                    }
                }
            }

            // -- Attachment chips ---------------------------------------
            Flow {
                visible: root.bridge.attachments.length > 0
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Repeater {
                    model: root.bridge.attachments

                    delegate: TextButton {
                        required property var modelData

                        text: "📎 " + modelData.toString().split("/").pop() + "  ✕"
                        type: TextButton.Tonal
                        onClicked: root.bridge.removeAttachment(modelData)
                    }
                }
            }

            // -- Input row ----------------------------------------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                IconButton {
                    icon: "attach_file"
                    type: IconButton.Text
                    label.text: qsTr("Attach file")
                    onClicked: fileDialog.open()
                }

                IconButton {
                    icon: root.bridge.recording ? "stop_circle" : "mic"
                    type: IconButton.Text
                    checked: root.bridge.recording
                    label.text: root.bridge.recording ? qsTr("Stop and send voice note") : qsTr("Record voice note")
                    onClicked: root.bridge.recording ? root.bridge.stopRecording(true) : root.bridge.startRecording()
                }

                StyledInputField {
                    id: input

                    Layout.fillWidth: true
                    horizontalAlignment: TextInput.AlignLeft
                    placeholderText: qsTr("Preguntale a Javi…")
                    onEditingFinished: root.sendCurrent()

                    Keys.onEscapePressed: root.bridge.chatOpen = false
                }

                TextButton {
                    visible: root.bridge.busy
                    text: qsTr("Stop")
                    type: TextButton.Tonal
                    onClicked: root.bridge.askStop()
                }

                TextButton {
                    text: qsTr("Send")
                    type: TextButton.Filled
                    enabled: input.text.trim() !== "" || root.bridge.attachments.length > 0
                    onClicked: root.sendCurrent()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.bridge.lastPrompt !== "" && !root.bridge.busy
                spacing: Appearance.spacing.small

                TextButton {
                    text: qsTr("↻ Retry last")
                    type: TextButton.Text
                    onClicked: root.bridge.retryLast()
                }

                StyledText {
                    visible: root.bridge.recording
                    text: qsTr("● Grabando… tocá el mic para enviar")
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.smaller
                    color: Colours.palette.m3error
                }
            }
        }
    }

    // File picker: kdialog is the Hornero-standard picker backend on
    // this stack; absence degrades to an honest bubble message.
    Process {
        id: fileDialogProc

        property bool used: false

        stdout: SplitParser {
            onRead: data => {
                const path = data.trim().split("\n").pop();
                if (path !== "" && !fileDialogProc.used) {
                    fileDialogProc.used = true;
                    root.bridge.addAttachment(path);
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !fileDialogProc.used)
                CompanionStore.say("No file picker available (kdialog missing).", 5000);
        }
    }

    QtObject {
        id: fileDialog

        function open(): void {
            fileDialogProc.used = false;
            fileDialogProc.command = ["kdialog", "--getopenfilename", Quickshell.env("HOME"), "Images and text (*.png *.jpg *.jpeg *.webp *.gif *.wav *.mp3 *.ogg *.txt *.md *.log *.json *.yaml *.yml *.v *.py *.js *.sh)"];
            fileDialogProc.running = true;
        }
    }

    onVisibleChanged: {
        if (visible) {
            input.forceActiveFocus();
            root.bridge.refreshStatus();
        }
    }
}
