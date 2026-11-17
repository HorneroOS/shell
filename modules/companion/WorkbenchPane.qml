pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.modules.companion
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Level C of Javi's Workbench: the conversation panel expanded with
// the run's activity timeline, pending approvals, artifacts, history
// and model/mode controls. It is a VIEW over the same engine as the
// panel (AssistantRun for run state, AssistantBridge for actions);
// it owns no run state of its own, so the two can never disagree.
//
// Only what the backend really provides is shown: timeline entries
// are the gateway's reported activity, artifacts are files the user
// attached (the backend has no artifact listing), history is the
// shell-side conversation cache plus the horneroctl session registry.
Rectangle {
    id: root

    required property var bridge

    readonly property string lang: root.bridge.lang
    property string tab: "activity"
    property string stagedModel: ""

    implicitWidth: 372
    implicitHeight: 560
    radius: Appearance.rounding.small
    color: Signal.palette.panel
    border.width: 1
    border.color: Qt.alpha(Signal.palette.phosphor, 0.55)

    // A pending approval always surfaces: the Approvals tab opens
    // itself so a decision is never hidden behind another tab.
    Connections {
        target: AssistantRun

        function onPendingDecisionChanged(): void {
            if (AssistantRun.pendingDecision)
                root.tab = "approvals";
        }
    }

    function t(key: string): string {
        return AssistantCopy.t(key, root.lang);
    }

    function statusColor(): color {
        const s = AssistantRun.status;
        if (s === "connected")
            return Signal.palette.signal;
        if (s === "running")
            return Signal.palette.phosphor;
        return s === "unknown" ? Signal.palette.inkMuted : Signal.palette.alert;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        // -- Status strip: one honest line -------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Rectangle {
                implicitWidth: 9
                implicitHeight: 9
                radius: 5
                color: root.statusColor()
            }

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: root.t("status." + (AssistantRun.probing && AssistantRun.status === "disconnected" ? "reconnecting" : AssistantRun.status))
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.smaller
                font.bold: true
                color: Signal.palette.ink
                elide: Text.ElideRight
            }

            StyledText {
                text: root.t("phase." + AssistantRun.phase)
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.inkMuted
            }
        }

        // -- Model + mode (real, explicit) -----------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: (root.bridge.currentModel !== "" ? root.bridge.currentModel : "—") + (root.bridge.currentProvider !== "" ? "  ·  " + root.bridge.currentProvider : "")
                textFormat: Text.PlainText
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.ink
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small
                visible: root.bridge.modelChoices.length > 1

                Repeater {
                    model: root.bridge.modelChoices

                    delegate: TextButton {
                        required property string modelData

                        text: modelData
                        type: TextButton.Tonal
                        toggle: true
                        checked: root.stagedModel === modelData
                        onClicked: root.stagedModel = modelData
                    }
                }
            }

            RowLayout {
                visible: root.stagedModel !== "" && root.stagedModel !== root.bridge.currentModel
                spacing: Appearance.spacing.small

                TextButton {
                    text: qsTr("Apply %1 to new sessions").arg(root.stagedModel)
                    type: TextButton.Filled
                    onClicked: {
                        root.bridge.applyModel(root.stagedModel);
                        root.stagedModel = "";
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Repeater {
                    model: ["ask", "agent", "chat"]

                    delegate: TextButton {
                        required property string modelData

                        text: root.t("mode." + modelData)
                        toggle: true
                        checked: CompanionStore.chatMode === modelData
                        type: TextButton.Tonal
                        enabled: !AssistantRun.active && !AssistantRun.pendingDecision
                        onClicked: CompanionStore.setChatMode(modelData)
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.t("mode." + CompanionStore.chatMode + ".hint")
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.inkMuted
                wrapMode: Text.Wrap
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Qt.alpha(Signal.palette.signal, 0.35)
        }

        // -- Tabs ------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Repeater {
                model: ["activity", "approvals", "artifacts", "history"]

                delegate: TextButton {
                    required property string modelData

                    text: root.t("tab." + modelData) + (modelData === "approvals" && AssistantRun.pendingDecision ? " ●" : "")
                    toggle: true
                    checked: root.tab === modelData
                    type: TextButton.Tonal
                    onClicked: root.tab = modelData
                }
            }
        }

        // -- Activity timeline -------------------------------------------
        ColumnLayout {
            visible: root.tab === "activity"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.small

            ListView {
                id: timelineView

                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: AssistantRun.timeline
                onCountChanged: positionViewAtEnd()

                StyledScrollBar.vertical: StyledScrollBar {}

                delegate: RowLayout {
                    id: entry

                    required property var modelData

                    width: timelineView.width - 8
                    spacing: Appearance.spacing.small

                    StyledText {
                        Layout.preferredWidth: 14
                        Layout.alignment: Qt.AlignTop
                        text: entry.modelData.kind === "tool" ? (entry.modelData.status === "ok" ? "✓" : entry.modelData.status === "failed" ? "✗" : entry.modelData.status === "running" ? "▸" : "?") : entry.modelData.kind === "approval" || entry.modelData.kind === "clarify" ? "▲" : "·"
                        font.family: Appearance.font.family.mono
                        font.pointSize: Appearance.font.size.smaller
                        color: entry.modelData.status === "failed" ? Signal.palette.alert : entry.modelData.status === "running" ? Signal.palette.phosphor : Signal.palette.inkMuted
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: entry.modelData.kind === "tool" ? entry.modelData.name + (entry.modelData.preview ? "  " + entry.modelData.preview : "") + (entry.modelData.status === "unknown" ? "  (" + qsTr("outcome unknown") + ")" : "") : entry.modelData.text
                        textFormat: Text.PlainText
                        font.family: Appearance.font.family.mono
                        font.pointSize: Appearance.font.size.smaller
                        color: entry.modelData.kind === "thinking" ? Signal.palette.inkMuted : Signal.palette.ink
                        wrapMode: Text.WrapAnywhere
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: timelineView.count === 0
                    text: root.t("timeline.empty")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.t("timeline.note")
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.inkMuted
                wrapMode: Text.Wrap
            }
        }

        // -- Approvals ---------------------------------------------------
        Flickable {
            visible: root.tab === "approvals"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentHeight: approvalsCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: approvalsCol

                width: parent.width
                spacing: Appearance.spacing.normal

                ApprovalCard {
                    bridge: root.bridge
                }

                StyledText {
                    visible: !AssistantRun.pendingDecision
                    text: root.t("approvals.none")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                }

                StyledText {
                    visible: root.bridge.decisions.length > 0
                    text: root.t("approvals.decided").toUpperCase()
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                }

                Repeater {
                    model: root.bridge.decisions.slice().reverse()

                    delegate: StyledText {
                        required property var modelData

                        Layout.fillWidth: true
                        text: (modelData.denied ? "✗ " + root.t("approvals.denied") : "✓ " + root.t("approvals.allowed")) + "  " + modelData.detail
                        textFormat: Text.PlainText
                        font.family: Appearance.font.family.mono
                        font.pointSize: Appearance.font.size.smaller
                        color: Signal.palette.ink
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }

        // -- Artifacts ---------------------------------------------------
        ColumnLayout {
            visible: root.tab === "artifacts"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.small

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.bridge.sentArtifacts

                delegate: StyledText {
                    required property var modelData

                    width: ListView.view.width
                    text: "📎 " + modelData.path.split("/").pop()
                    textFormat: Text.PlainText
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.ink
                    elide: Text.ElideMiddle
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: root.bridge.sentArtifacts.length === 0
                    text: root.t("artifacts.empty")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.t("artifacts.note")
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.inkMuted
                wrapMode: Text.Wrap
            }

            TextButton {
                visible: AssistantRun.gateway.workspace !== ""
                text: qsTr("Open workspace folder")
                type: TextButton.Tonal
                onClicked: Quickshell.execDetached(["horneroctl", "assistant", "workspace", "reveal"])
            }
        }

        // -- History -----------------------------------------------------
        ColumnLayout {
            visible: root.tab === "history"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Appearance.spacing.small

            StyledText {
                text: root.t("history.sessions").toUpperCase()
                font.family: Appearance.font.family.mono
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.inkMuted
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: root.bridge.chatSessions

                delegate: TextButton {
                    required property var modelData

                    width: ListView.view.width
                    text: modelData.title
                    toggle: true
                    checked: modelData.id === root.bridge.currentSession
                    type: TextButton.Tonal
                    enabled: !AssistantRun.active
                    onClicked: root.bridge.useChatSession(modelData.id)
                }
            }

            RowLayout {
                spacing: Appearance.spacing.small

                TextButton {
                    text: root.t("history.new")
                    type: TextButton.Tonal
                    enabled: !AssistantRun.active
                    onClicked: root.bridge.newChatSession()
                }

                TextButton {
                    text: root.t("action.clear")
                    type: TextButton.Tonal
                    onClicked: root.bridge.clearHistory()
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Kept on this device: last %1 messages. Hermes owns the real sessions.").arg(root.bridge.historyCap)
                font.pointSize: Appearance.font.size.smaller
                color: Signal.palette.inkMuted
                wrapMode: Text.Wrap
            }
        }
    }
}
