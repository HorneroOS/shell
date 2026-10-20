pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Companion chat panel: the native Hermes conversation surface.
// Presentation only — every action goes through AssistantBridge,
// which talks exclusively to `horneroctl assistant ... --json`.
// The bird's state (thinking/acting/warning/success/error) is
// owned by CompanionStore; this panel mirrors the conversation,
// an animated thinking indicator while a run is busy, the pending
// approval with explicit Approve/Deny buttons (never auto-
// answered), and an input row. History is in-memory in the
// bridge; Hermes owns real sessions.
Item {
    id: root

    required property var bridge

    property int dotPhase: 0

    visible: root.bridge.chatOpen
    implicitWidth: 330
    implicitHeight: card.implicitHeight

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
        running: root.bridge.busy
        repeat: true
        onTriggered: root.dotPhase = (root.dotPhase + 1) % 4
    }

    StyledRect {
        id: card

        width: root.implicitWidth
        implicitHeight: layout.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.large
        color: Colours.palette.m3surfaceContainer

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    text: qsTr("Hornero Companion")
                    font.pointSize: Appearance.font.size.normal
                    font.bold: true
                    color: Colours.palette.m3onSurface
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    visible: root.bridge.busy
                    text: qsTr("thinking") + ".".repeat(root.dotPhase)
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3primary
                }
            }

            Repeater {
                model: root.bridge.history

                delegate: StyledText {
                    required property var modelData

                    Layout.fillWidth: true
                    text: (modelData.role === "user" ? qsTr("You: ") : qsTr("Hornero: ")) + modelData.text
                    font.pointSize: Appearance.font.size.small
                    color: modelData.role === "user" ? Colours.palette.m3primary : Colours.palette.m3onSurface
                    wrapMode: Text.Wrap
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.bridge.history.length === 0 && !root.bridge.busy
                text: qsTr("Ask me anything — I read the system through horneroctl and always ask before changing anything.")
                font.pointSize: Appearance.font.size.small
                color: Colours.palette.m3onSurfaceVariant
                wrapMode: Text.Wrap
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.bridge.pendingApproval !== null
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: root.bridge.pendingApproval ? root.bridge.pendingApproval.detail : ""
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3error
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

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                StyledInputField {
                    id: input

                    Layout.fillWidth: true
                    horizontalAlignment: TextInput.AlignLeft
                    onEditingFinished: {
                        if (text.trim() !== "") {
                            root.bridge.ask(text);
                            text = "";
                        }
                    }
                }

                TextButton {
                    text: qsTr("Send")
                    type: TextButton.Filled
                    enabled: input.text.trim() !== ""
                    onClicked: {
                        root.bridge.ask(input.text);
                        input.text = "";
                    }
                }

                TextButton {
                    visible: root.bridge.busy
                    text: qsTr("Stop")
                    type: TextButton.Tonal
                    onClicked: root.bridge.askStop()
                }
            }
        }
    }
}
