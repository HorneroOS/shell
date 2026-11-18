pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.modules.companion
import qs.config
import qs.services
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Control Center › Companion: enable, character, size, idle-to-sleep,
// tips, edge, bubble theme, and position reset. Binds straight onto
// CompanionStore (persisted via PersistentProperties, no save step).
Item {
    id: root

    required property Session session

    anchors.fill: parent

    ClippingRectangle {
        id: clipRect

        anchors.fill: parent
        anchors.margins: Appearance.padding.normal
        anchors.leftMargin: 0
        anchors.rightMargin: Appearance.padding.normal
        color: "transparent"

        StyledFlickable {
            id: flick

            anchors.fill: parent
            anchors.margins: Appearance.padding.large + Appearance.padding.normal
            anchors.leftMargin: Appearance.padding.large
            anchors.rightMargin: Appearance.padding.large
            flickableDirection: Flickable.VerticalFlick
            contentHeight: content.implicitHeight

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: flick
            }

            ColumnLayout {
                id: content

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Appearance.spacing.normal

                PaneHeader {
                    paneId: "companion"
                    title: qsTr("Javi · the Hornero")
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Javi, el Hornero: your sidekick. Idles, greets, shows tips — and, with Hermes enabled, chats, reads the system and always asks before changing anything.")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.inkMuted
                    wrapMode: Text.Wrap
                }

                ChannelPanel {
                    title: qsTr("General")

                    ColumnLayout {
                        id: generalCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        SwitchRow {
                            label: qsTr("Enabled")
                            checked: CompanionStore.enabled
                            onToggled: checked => CompanionStore.enabled = checked
                        }

                        SwitchRow {
                            label: qsTr("Show tips on click")
                            checked: CompanionStore.tipsEnabled
                            onToggled: checked => CompanionStore.tipsEnabled = checked
                        }

                        SwitchRow {
                            label: qsTr("Reduced motion")
                            checked: CompanionStore.reducedMotion
                            onToggled: checked => CompanionStore.reducedMotion = checked
                        }

                        SwitchRow {
                            label: qsTr("Idle animations")
                            checked: CompanionStore.idleAnimEnabled
                            onToggled: checked => CompanionStore.idleAnimEnabled = checked
                        }

                        StyledText {
                            text: qsTr("Activity")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small
                            enabled: CompanionStore.idleAnimEnabled

                            Repeater {
                                model: ["calm", "normal", "lively"]

                                TextButton {
                                    required property int index
                                    required property string modelData

                                    text: modelData === "calm" ? qsTr("Calm") : modelData === "lively" ? qsTr("Lively") : qsTr("Normal")
                                    toggle: true
                                    checked: CompanionStore.activityLevel === modelData
                                    type: TextButton.Tonal
                                    onClicked: CompanionStore.activityLevel = modelData
                                }
                            }
                        }

                        SwitchRow {
                            label: qsTr("Let Javi wander")
                            checked: CompanionStore.wanderEnabled
                            onToggled: checked => CompanionStore.wanderEnabled = checked
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Occasionally flies to another corner. Off: stays where you put it.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        SwitchRow {
                            label: qsTr("Nest building")
                            checked: CompanionStore.nestEnabled
                            onToggled: checked => CompanionStore.nestEnabled = checked
                        }

                        SwitchRow {
                            label: qsTr("Sleep at nest")
                            enabled: CompanionStore.nestEnabled
                            checked: CompanionStore.sleepAtNest
                            onToggled: checked => CompanionStore.sleepAtNest = checked
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledText {
                                Layout.fillWidth: true
                                text: qsTr("Nest stage: %1 / 4").arg(CompanionStore.nestStage)
                                font.pointSize: Appearance.font.size.smaller
                                color: Signal.palette.inkMuted
                            }

                            TextButton {
                                text: qsTr("Reset nest")
                                type: TextButton.Tonal
                                enabled: CompanionStore.nestEnabled && CompanionStore.nestStage > 0
                                onClicked: CompanionStore.resetNest()
                            }
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Size")
                            value: CompanionStore.sizeScale
                            from: 0.5
                            to: 2.0
                            stepSize: 0.05
                            suffix: "×"
                            decimals: 2
                            onValueModified: newValue => CompanionStore.sizeScale = newValue
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Sleep after idle")
                            value: CompanionStore.sleepMinutes
                            from: 0
                            to: 30
                            stepSize: 1
                            suffix: "min"
                            validator: IntValidator {
                                bottom: 0
                                top: 30
                            }
                            formatValueFunction: val => val === 0 ? qsTr("never") : `${Math.round(val)} min`
                            parseValueFunction: text => parseInt(text)
                            onValueModified: newValue => CompanionStore.sleepMinutes = Math.round(newValue)
                        }
                    }
                }


                ChannelPanel {
                    title: qsTr("Reactions")

                    ColumnLayout {
                        id: reactionsCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Javi reacts only to things that really happened: a notification, a battery warning, a mode switch, or a finished build or download reported by an extension. Never on a timer.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        SwitchRow {
                            label: qsTr("React to events")
                            checked: CompanionStore.reactionSettings.enabled
                            onToggled: checked => CompanionStore.patchReactions("enabled", checked)
                        }

                        SwitchRow {
                            label: qsTr("Speech bubbles with reactions")
                            enabled: CompanionStore.reactionSettings.enabled
                            checked: CompanionStore.reactionSettings.bubbles
                            onToggled: checked => CompanionStore.patchReactions("bubbles", checked)
                        }

                        StyledText {
                            text: qsTr("Per event")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                        }

                        Repeater {
                            model: CompanionReactions.catalog

                            SwitchRow {
                                required property var modelData

                                Layout.fillWidth: true
                                enabled: CompanionStore.reactionSettings.enabled
                                label: modelData.external ? qsTr("%1 (from extensions)").arg(CompanionReactions.label(modelData.id)) : CompanionReactions.label(modelData.id)
                                checked: CompanionStore.reactionSettings.kindsOff.indexOf(modelData.id) < 0
                                onToggled: checked => CompanionStore.setKindEnabled(modelData.id, checked)
                            }
                        }

                        StyledText {
                            text: qsTr("Per Experience mode")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Full: every enabled event. Quiet: only important events, animation only. Silent: no reactions.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        Repeater {
                            model: CompanionReactions.modeIds

                            RowLayout {
                                id: modeRow

                                required property string modelData

                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                StyledText {
                                    Layout.preferredWidth: 90
                                    text: modeRow.modelData === "focus" ? qsTr("Focus") : modeRow.modelData === "signal" ? qsTr("Signal") : modeRow.modelData === "gaming" ? qsTr("Gaming") : modeRow.modelData === "studio" ? qsTr("Studio") : qsTr("Everyday")
                                }

                                Repeater {
                                    model: CompanionReactions.levels

                                    TextButton {
                                        required property string modelData

                                        text: modelData === "quiet" ? qsTr("Quiet") : modelData === "silent" ? qsTr("Silent") : qsTr("Full")
                                        toggle: true
                                        checked: CompanionStore.reactionSettings.modeBehaviour[modeRow.modelData] === modelData
                                        type: TextButton.Tonal
                                        onClicked: CompanionStore.setModeBehaviour(modeRow.modelData, modelData)
                                    }
                                }
                            }
                        }

                        StyledText {
                            visible: sourcesRepeater.count > 0
                            text: qsTr("Extensions and tools that asked Javi to react")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                        }

                        Repeater {
                            id: sourcesRepeater

                            model: {
                                const all = CompanionReactions.seenSources.concat(CompanionStore.reactionSettings.mutedSources);
                                return all.filter((v, i) => all.indexOf(v) === i);
                            }

                            SwitchRow {
                                required property string modelData

                                Layout.fillWidth: true
                                label: qsTr("Allow %1").arg(modelData)
                                checked: CompanionStore.reactionSettings.mutedSources.indexOf(modelData) < 0
                                onToggled: checked => {
                                    const muted = CompanionStore.reactionSettings.mutedSources.filter(v => v !== modelData);
                                    if (!checked)
                                        muted.push(modelData);
                                    CompanionStore.patchReactions("mutedSources", muted);
                                }
                            }
                        }

                        SwitchRow {
                            label: qsTr("Quiet hours")
                            checked: CompanionStore.reactionSettings.quietHours.enabled
                            onToggled: checked => CompanionStore.setQuietHours("enabled", checked)
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            enabled: CompanionStore.reactionSettings.quietHours.enabled
                            label: qsTr("Quiet from")
                            value: parseInt(CompanionStore.reactionSettings.quietHours.start)
                            from: 0
                            to: 23
                            stepSize: 1
                            suffix: ":00"
                            decimals: 0
                            onValueModified: newValue => CompanionStore.setQuietHours("start", Math.round(newValue) + ":00")
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            enabled: CompanionStore.reactionSettings.quietHours.enabled
                            label: qsTr("Quiet until")
                            value: parseInt(CompanionStore.reactionSettings.quietHours.end)
                            from: 0
                            to: 23
                            stepSize: 1
                            suffix: ":00"
                            decimals: 0
                            onValueModified: newValue => CompanionStore.setQuietHours("end", Math.round(newValue) + ":00")
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("During quiet hours Javi only reacts to important events, without a speech bubble.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Preview a reaction")
                                type: TextButton.Tonal
                                onClicked: CompanionStore.playReaction("celebrate", qsTr("Like this."), 4000, 3)
                            }

                            TextButton {
                                text: qsTr("Reset reactions")
                                type: TextButton.Tonal
                                onClicked: CompanionStore.resetReactions()
                            }
                        }
                    }
                }

                ChannelPanel {
                    title: qsTr("Look per Experience mode")

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Each mode can show or hide Javi, scale him relative to the size above, and use its own character. Gaming mode always hides him.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        Repeater {
                            model: CompanionReactions.modeIds

                            ColumnLayout {
                                id: lookRow

                                required property string modelData
                                readonly property var look: CompanionStore.modeLookSettings[lookRow.modelData]
                                readonly property string modeName: lookRow.modelData === "focus" ? qsTr("Focus") : lookRow.modelData === "signal" ? qsTr("Signal") : lookRow.modelData === "gaming" ? qsTr("Gaming") : lookRow.modelData === "studio" ? qsTr("Studio") : qsTr("Everyday")

                                Layout.fillWidth: true
                                spacing: Appearance.spacing.small

                                SwitchRow {
                                    label: qsTr("Show Javi in %1 mode").arg(lookRow.modeName)
                                    checked: lookRow.look.visible
                                    onToggled: checked => CompanionStore.setModeLook(lookRow.modelData, "visible", checked)
                                }

                                SliderInput {
                                    Layout.fillWidth: true

                                    enabled: lookRow.look.visible
                                    label: qsTr("%1 size").arg(lookRow.modeName)
                                    value: lookRow.look.size
                                    from: 0.5
                                    to: 2.0
                                    stepSize: 0.05
                                    suffix: "×"
                                    decimals: 2
                                    onValueModified: newValue => CompanionStore.setModeLook(lookRow.modelData, "size", newValue)
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    spacing: Appearance.spacing.small
                                    enabled: lookRow.look.visible

                                    TextButton {
                                        text: qsTr("Main character")
                                        toggle: true
                                        checked: lookRow.look.skin === ""
                                        type: TextButton.Tonal
                                        onClicked: CompanionStore.setModeLook(lookRow.modelData, "skin", "")
                                    }

                                    Repeater {
                                        model: Companion.knownSkins

                                        TextButton {
                                            required property string modelData

                                            text: modelData
                                            toggle: true
                                            checked: lookRow.look.skin === modelData
                                            type: TextButton.Tonal
                                            onClicked: CompanionStore.setModeLook(lookRow.modelData, "skin", modelData)
                                        }
                                    }
                                }
                            }
                        }

                        TextButton {
                            text: qsTr("Reset mode looks")
                            type: TextButton.Tonal
                            onClicked: CompanionStore.resetModeLook()
                        }
                    }
                }

                ChannelPanel {
                    title: qsTr("Assistant (Hermes)")

                    ColumnLayout {
                        id: assistantCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: assistantStatus.text
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Optional and local: Hermes runs as your user on loopback, Javi talks to it only through horneroctl, and nothing changes the system without your approval. Keys never enter this panel.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        RowLayout {
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Enable assistant")
                                type: TextButton.Filled
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "enable", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Disable")
                                type: TextButton.Tonal
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "disable", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Refresh status")
                                type: TextButton.Tonal
                                onClicked: assistantStatus.refresh()
                            }
                        }

                        SwitchRow {
                            label: qsTr("Stream answers live")
                            checked: CompanionStore.chatStreaming
                            onToggled: checked => CompanionStore.chatStreaming = checked
                        }

                        SliderInput {
                            Layout.fillWidth: true

                            label: qsTr("Chat history kept")
                            value: CompanionStore.chatHistoryLimit
                            from: 0
                            to: 200
                            stepSize: 10
                            suffix: qsTr("msgs")
                            validator: IntValidator {
                                bottom: 0
                                top: 200
                            }
                            formatValueFunction: val => val === 0 ? qsTr("off") : `${Math.round(val)}`
                            parseValueFunction: text => parseInt(text)
                            onValueModified: newValue => CompanionStore.chatHistoryLimit = Math.round(newValue)
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: CompanionStore.chatHistoryLimit === 0 ? qsTr("History is off: conversations are not saved on this device.") : qsTr("Kept on this device only (last %1 messages). Hermes owns the real sessions; clear them from the chat panel at any time.").arg(CompanionStore.chatHistoryLimit)
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            text: qsTr("Default mode").toUpperCase()
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                        }

                        RowLayout {
                            spacing: Appearance.spacing.small

                            Repeater {
                                model: ["ask", "agent", "chat"]

                                delegate: TextButton {
                                    required property string modelData

                                    text: AssistantCopy.t("mode." + modelData, AssistantCopy.lang(Language.uiLocale))
                                    toggle: true
                                    checked: CompanionStore.chatMode === modelData
                                    type: TextButton.Tonal
                                    onClicked: CompanionStore.setChatMode(modelData)
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: AssistantCopy.t("mode." + CompanionStore.chatMode + ".hint", AssistantCopy.lang(Language.uiLocale))
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            text: qsTr("Workbench").toUpperCase()
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Quick questions (Javi Radio, the launcher) are read-only and never act. When one needs approval, it hands you over to the Workbench, where you decide on each request. The shell writes no keybinding; bind the Workbench yourself if you want a key.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "qs ipc call companion workbench"
                            textFormat: Text.PlainText
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.ink
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Privacy: the microphone opens only when you press it and stops after 2 minutes; nothing is copied, captured or sent to a provider unless you attach it or approve a specific action.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }
                    }
                }

                ChannelPanel {
                    title: qsTr("Hermes agent")

                    ColumnLayout {
                        id: hermesCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Live state from horneroctl. Model, provider, API keys and token usage are managed in the Hermes dashboard — keys never enter this panel.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        DetailRow {
                            label: qsTr("Endpoint")
                            value: assistantStatus.data.endpoint || "—"
                        }

                        DetailRow {
                            label: qsTr("Gateway")
                            value: assistantStatus.data.gateway || "—"
                        }

                        DetailRow {
                            label: qsTr("Protocol")
                            value: assistantStatus.data.protocol || "—"
                        }

                        DetailRow {
                            label: qsTr("Isolation")
                            value: assistantStatus.data.isolation === "bubblewrap" ? qsTr("Sandboxed (bubblewrap)") : qsTr("systemd only — not sandboxed")
                        }

                        DetailRow {
                            label: qsTr("Workspace")
                            value: assistantStatus.data.workspace || "—"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Reveal workspace")
                                type: TextButton.Tonal
                                onClicked: Quickshell.execDetached(["xdg-open", assistantStatus.data.workspace || ""])
                            }

                            TextButton {
                                text: qsTr("Recent activity")
                                type: TextButton.Tonal
                                onClicked: assistantLog.refresh()
                            }
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small
                            visible: assistantWorkspaces.ids.length > 1

                            Repeater {
                                model: assistantWorkspaces.ids

                                TextButton {
                                    required property int index
                                    required property string modelData

                                    text: modelData
                                    toggle: true
                                    checked: assistantWorkspaces.active === modelData
                                    type: TextButton.Tonal
                                    onClicked: assistantCtl.run(["horneroctl", "assistant", "workspace", "use", modelData, "--yes", "--json"])
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledInputField {
                                id: workspaceNameInput

                                Layout.fillWidth: true
                            }

                            TextButton {
                                text: qsTr("Create workspace")
                                type: TextButton.Tonal
                                onClicked: {
                                    const name = workspaceNameInput.text.trim();
                                    if (name !== "") {
                                        assistantCtl.run(["horneroctl", "assistant", "workspace", "create", name, "--yes", "--json"]);
                                        workspaceNameInput.text = "";
                                    }
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Switching workspace rebinds the gateway on its next start; chats keep the workspace they were created in.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: assistantLog.text !== ""
                            text: assistantLog.text
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        DetailRow {
                            label: qsTr("Model")
                            value: hermesModel.text
                        }

                        DetailRow {
                            label: qsTr("Configured model")
                            value: assistantModelConfig.text
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small
                            visible: hermesModel.models.length > 0

                            Repeater {
                                model: hermesModel.models

                                TextButton {
                                    required property int index
                                    required property string modelData

                                    text: modelData
                                    toggle: true
                                    checked: modelInput.text.trim() === modelData
                                    type: TextButton.Tonal
                                    onClicked: {
                                        modelInput.text = modelData;
                                        root.applyModel(modelData);
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledInputField {
                                id: modelInput

                                Layout.fillWidth: true
                                // Enter or leaving the field applies; there is no Apply button.
                                onEditingFinished: root.applyModel(modelInput.text)
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Applies to new chats as soon as you pick a model or press Enter (same as hermes model); running chats keep their model.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        DetailRow {
                            label: qsTr("Chat sessions")
                            value: hermesSessions.text
                        }

                        DetailRow {
                            label: qsTr("Tokens in")
                            value: hermesUsage.data.inputTokens || "—"
                        }

                        DetailRow {
                            label: qsTr("Tokens out")
                            value: hermesUsage.data.outputTokens || "—"
                        }

                        DetailRow {
                            label: qsTr("API calls")
                            value: hermesUsage.data.apiCalls || "—"
                        }

                        DetailRow {
                            label: qsTr("Usage sessions")
                            value: hermesUsage.data.sessions || "—"
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Start gateway")
                                type: TextButton.Filled
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "gateway", "start", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Stop gateway")
                                type: TextButton.Tonal
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "gateway", "stop", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Open Hermes dashboard")
                                type: TextButton.Tonal
                                onClicked: {
                                    Quickshell.execDetached(["hermes", "dashboard", "--no-open"]);
                                    dashboardTimer.restart();
                                }
                            }
                        }

                        Timer {
                            id: dashboardTimer

                            interval: 1800
                            repeat: false
                            onTriggered: Quickshell.execDetached(["app2unit", "-O", "--", "http://127.0.0.1:9119"])
                        }
                    }
                }

                ChannelPanel {
                    title: qsTr("Permissions & security")

                    ColumnLayout {
                        id: policyCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Enforced by horneroctl, outside the agent. Deny always wins; screenshots, clipboard and shell stay off or approval-gated unless a preset allows them. The agent cannot edit its own policy.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: assistantPolicy.text
                            font.pointSize: Appearance.font.size.smaller
                            wrapMode: Text.Wrap
                        }

                        DetailRow {
                            label: qsTr("Secure profile")
                            value: assistantProfile.text
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Read only")
                                type: TextButton.Tonal
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "policy", "preset", "read-only", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Workspace agent")
                                type: TextButton.Tonal
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "policy", "preset", "workspace-agent", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Desktop assistant")
                                type: TextButton.Tonal
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "policy", "preset", "desktop-assistant", "--yes", "--json"])
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Revoke all agent actions")
                                type: TextButton.Filled
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "policy", "revoke-all", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Fix secure profile")
                                type: TextButton.Tonal
                                onClicked: assistantCtl.run(["horneroctl", "assistant", "profile", "fix", "--yes", "--json"])
                            }

                            TextButton {
                                text: qsTr("Refresh")
                                type: TextButton.Tonal
                                onClicked: {
                                    assistantPolicy.refresh();
                                    assistantProfile.refresh();
                                }
                            }
                        }
                    }
                }

                ChannelPanel {
                    title: qsTr("Personality & system prompt")

                    ColumnLayout {
                        id: promptCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("This is Javi's full user-configurable system prompt (Hermes SOUL.md). Saving snapshots the previous version for rollback. Behaviour only: it can never widen permissions or the sandbox.")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                            wrapMode: Text.Wrap
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 140
                            radius: Appearance.rounding.small
                            color: Signal.palette.sunken
                            border.width: 1
                            border.color: Signal.palette.rule

                            TextEdit {
                                id: promptEditor

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.small
                                color: Signal.palette.ink
                                font.family: Appearance.font.family.mono
                                font.pointSize: Appearance.font.size.smaller
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                text: assistantPrompt.text
                                // Saved when the editor loses focus (no Save button); Undo restores the old text.
                                // Saved shortly after the editor loses focus. Pressing Reload
                                // (which also takes focus) cancels that save: Reload means
                                // "throw my edits away", not "save them first".
                                onActiveFocusChanged: {
                                    if (!activeFocus)
                                        promptSave.restart();
                                    else
                                        promptSave.stop();
                                }

                                Timer {
                                    id: promptSave

                                    interval: 400
                                    onTriggered: root.applyPrompt(promptEditor.text)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Reload")
                                type: TextButton.Tonal
                                onClicked: {
                                    promptSave.stop();
                                    promptEditor.text = Qt.binding(() => assistantPrompt.text);
                                    assistantPrompt.refresh();
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: assistantPromptHistory.text
                                font.pointSize: Appearance.font.size.smaller
                                color: Signal.palette.inkMuted
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                ChannelPanel {
                    title: qsTr("Character")

                    ColumnLayout {
                        id: charCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Skin")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            Repeater {
                                model: Companion.knownSkins

                                TextButton {
                                    required property int index
                                    required property string modelData

                                    text: modelData
                                    toggle: true
                                    checked: CompanionStore.skin === modelData
                                    type: TextButton.Tonal
                                    onClicked: CompanionStore.setSkin(modelData)
                                }
                            }
                        }

                        StyledText {
                            text: qsTr("Summon edge")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Left")
                                toggle: true
                                checked: CompanionStore.edge === "left"
                                type: TextButton.Tonal
                                Layout.fillWidth: true
                                onClicked: CompanionStore.edge = "left"
                            }
                            TextButton {
                                text: qsTr("Right")
                                toggle: true
                                checked: CompanionStore.edge === "right"
                                type: TextButton.Tonal
                                Layout.fillWidth: true
                                onClicked: CompanionStore.edge = "right"
                            }
                        }

                        StyledText {
                            text: qsTr("Speech bubble theme")
                            font.pointSize: Appearance.font.size.smaller
                            color: Signal.palette.inkMuted
                        }

                        Flow {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            Repeater {
                                model: ["auto", "dark", "light", "pampa"]

                                TextButton {
                                    required property int index
                                    required property string modelData

                                    text: modelData
                                    toggle: true
                                    checked: CompanionStore.bubbleTheme === modelData
                                    type: TextButton.Tonal
                                    onClicked: CompanionStore.bubbleTheme = modelData
                                }
                            }
                        }
                    }
                }

                HabitatSection {}

                VoiceSection {}

                RadioSection {}

                ChannelPanel {
                    title: qsTr("Actions")

                    ColumnLayout {
                        id: actionCol

                        Layout.fillWidth: true
                        Layout.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: CompanionStore.state === "hidden" ? qsTr("Summon") : qsTr("Peek out")
                                type: TextButton.Filled
                                Layout.fillWidth: true
                                onClicked: CompanionStore.summon()
                            }
                            TextButton {
                                text: qsTr("Reset position")
                                type: TextButton.Tonal
                                Layout.fillWidth: true
                                onClicked: CompanionStore.resetPosition()
                            }
                        }
                    }
                }
            }
        }
    }

    QtObject {
        id: assistantStatus

        property string text: qsTr("Checking assistant status…")
        property var data: ({})

        function refresh(): void {
            assistantStatusProc.out = "";
            assistantStatusProc.command = ["horneroctl", "assistant", "status", "--json"];
            assistantStatusProc.running = true;
            hermesModel.refresh();
            assistantWorkspaces.refresh();
            hermesSessions.refresh();
            hermesUsage.refresh();
        }
    }

    Process {
        id: assistantStatusProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                assistantStatusProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(assistantStatusProc.out.trim());
                assistantStatus.text = payload.message ? payload.message.toString() : qsTr("Unknown status");
                assistantStatus.data = payload.data ?? {};
            } catch (e) {
                assistantStatus.text = qsTr("horneroctl assistant unavailable on this system.");
                assistantStatus.data = {};
            }
        }
    }

    QtObject {
        id: assistantPolicy

        property string text: qsTr("Checking policy…")

        function refresh(): void {
            assistantPolicyProc.out = "";
            assistantPolicyProc.command = ["horneroctl", "assistant", "policy", "--json"];
            assistantPolicyProc.running = true;
        }
    }

    Process {
        id: assistantPolicyProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                assistantPolicyProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(assistantPolicyProc.out.trim());
                assistantPolicy.text = payload.message ? payload.message.toString() : "";
            } catch (e) {
                assistantPolicy.text = qsTr("Policy unavailable (horneroctl too old?).");
            }
        }
    }

    QtObject {
        id: assistantProfile

        property string text: "—"

        function refresh(): void {
            assistantProfileProc.out = "";
            assistantProfileProc.command = ["horneroctl", "assistant", "profile", "--json"];
            assistantProfileProc.running = true;
        }
    }

    Process {
        id: assistantProfileProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                assistantProfileProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(assistantProfileProc.out.trim());
                assistantProfile.text = payload.data && payload.data.profileOk === "true" ? qsTr("OK") : qsTr("Drift — fix recommended");
            } catch (e) {
                assistantProfile.text = "—";
            }
        }
    }

    QtObject {
        id: assistantLog

        property string text: ""

        function refresh(): void {
            assistantLogProc.out = "";
            assistantLogProc.command = ["horneroctl", "assistant", "log", "--json"];
            assistantLogProc.running = true;
        }
    }

    Process {
        id: assistantLogProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                assistantLogProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(assistantLogProc.out.trim());
                assistantLog.text = payload.message ? payload.message.toString() : "";
            } catch (e) {
                assistantLog.text = "";
            }
        }
    }

    QtObject {
        id: assistantPrompt

        property string text: ""

        function refresh(): void {
            assistantPromptProc.out = "";
            assistantPromptProc.command = ["horneroctl", "assistant", "prompt", "--json"];
            assistantPromptProc.running = true;
            assistantPromptHistory.refresh();
        }
    }

    Process {
        id: assistantPromptProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                assistantPromptProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(assistantPromptProc.out.trim());
                assistantPrompt.text = payload.message ? payload.message.toString() : "";
            } catch (e) {
                assistantPrompt.text = "";
            }
        }
    }

    QtObject {
        id: assistantPromptHistory

        property string text: ""

        function refresh(): void {
            assistantPromptHistoryProc.out = "";
            assistantPromptHistoryProc.command = ["horneroctl", "assistant", "prompt", "history", "--json"];
            assistantPromptHistoryProc.running = true;
        }
    }

    Process {
        id: assistantPromptHistoryProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                assistantPromptHistoryProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(assistantPromptHistoryProc.out.trim());
                const count = payload.data && payload.data.count ? payload.data.count.toString() : "0";
                assistantPromptHistory.text = count === "0" ? qsTr("No saved versions yet") : qsTr("%1 saved version(s) for rollback").arg(count);
            } catch (e) {
                assistantPromptHistory.text = "";
            }
        }
    }

    QtObject {
        id: assistantModelConfig

        property string text: "—"

        function refresh(): void {
            assistantModelConfigProc.out = "";
            assistantModelConfigProc.command = ["horneroctl", "assistant", "model", "show", "--json"];
            assistantModelConfigProc.running = true;
        }
    }

    Process {
        id: assistantModelConfigProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                assistantModelConfigProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(assistantModelConfigProc.out.trim());
                assistantModelConfig.text = payload.data && payload.data.model ? payload.data.model.toString() : "—";
            } catch (e) {
                assistantModelConfig.text = "—";
            }
            assistantModelConfigProc.out = "";
        }
    }

    QtObject {
        id: hermesModel

        property string text: "—"
        property var models: []

        function refresh(): void {
            hermesModelProc.out = "";
            hermesModelProc.command = ["horneroctl", "assistant", "model", "list", "--json"];
            hermesModelProc.running = true;
        }
    }

    Process {
        id: hermesModelProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                hermesModelProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(hermesModelProc.out.trim());
                hermesModel.text = payload.ok ? ((payload.data ?? {}).models ?? "—").toString() : "—";
                hermesModel.models = payload.ok ? hermesModel.text.split(/[,\n]/).map(s => s.trim()).filter(s => s !== "" && s !== "—") : [];
            } catch (e) {
                hermesModel.text = "—";
                hermesModel.models = [];
            }
        }
    }

    QtObject {
        id: assistantWorkspaces

        property var ids: []
        property string active: ""

        function refresh(): void {
            assistantWorkspacesProc.out = "";
            assistantWorkspacesProc.command = ["horneroctl", "assistant", "workspace", "list", "--json"];
            assistantWorkspacesProc.running = true;
        }
    }

    Process {
        id: assistantWorkspacesProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                assistantWorkspacesProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(assistantWorkspacesProc.out.trim());
                const data = payload.data ?? {};
                assistantWorkspaces.ids = payload.ok && data.ids ? data.ids.toString().split(",").filter(s => s !== "") : [];
                assistantWorkspaces.active = payload.ok && data.active ? data.active.toString() : "";
            } catch (e) {
                assistantWorkspaces.ids = [];
                assistantWorkspaces.active = "";
            }
            assistantWorkspacesProc.out = "";
        }
    }

    QtObject {
        id: hermesSessions

        property string text: "—"

        function refresh(): void {
            hermesSessionsProc.out = "";
            hermesSessionsProc.command = ["horneroctl", "assistant", "sessions", "list", "--json"];
            hermesSessionsProc.running = true;
        }
    }

    Process {
        id: hermesSessionsProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                hermesSessionsProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(hermesSessionsProc.out.trim());
                hermesSessions.text = payload.ok ? ((payload.data ?? {}).count ?? "—").toString() : "—";
            } catch (e) {
                hermesSessions.text = "—";
            }
        }
    }

    QtObject {
        id: hermesUsage

        property var data: ({})

        function refresh(): void {
            hermesUsageProc.out = "";
            hermesUsageProc.command = ["horneroctl", "assistant", "usage", "--json"];
            hermesUsageProc.running = true;
        }
    }

    Process {
        id: hermesUsageProc

        property string out: ""

        stdout: SplitParser {
            onRead: data => {
                hermesUsageProc.out += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            try {
                const payload = JSON.parse(hermesUsageProc.out.trim());
                hermesUsage.data = payload.ok ? (payload.data ?? {}) : {};
            } catch (e) {
                hermesUsage.data = {};
            }
        }
    }

    // Label/value row for live Hermes state.
    component DetailRow: RowLayout {
        required property string label
        required property string value

        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            Layout.preferredWidth: 130
            text: label
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.inkMuted
        }

        StyledText {
            Layout.fillWidth: true
            text: value
            font.pointSize: Appearance.font.size.smaller
            color: Signal.palette.ink
            wrapMode: Text.Wrap
        }
    }

    // One assistant command at a time; a newer one issued meanwhile replaces
    // an older queued one (newest wins). `undo` is {key, title, detail,
    // restore: argv} and is offered after a successful run.
    QtObject {
        id: assistantCtl

        property var current: null
        property var queued: null

        function run(cmd, undo): void {
            const job = {
                "cmd": cmd,
                "undo": undo ?? null
            };
            if (assistantCtlProc.running) {
                assistantCtl.queued = job;
                return;
            }
            assistantCtl.current = job;
            assistantCtlProc.command = cmd;
            assistantCtlProc.running = true;
        }
    }

    function applyModel(raw: string): void {
        const id = raw.trim();
        const prev = assistantModelConfig.text;
        if (id === "" || id.includes(" ") || id === prev)
            return;
        assistantCtl.run(["horneroctl", "assistant", "model", "set", id, "--yes", "--json"], prev !== "" && prev !== "—" ? {
            "key": "assistant-model",
            "title": qsTr("Assistant model %1").arg(id),
            "detail": qsTr("Undo returns to %1 for new chats.").arg(prev),
            "restore": ["horneroctl", "assistant", "model", "set", prev, "--yes", "--json"]
        } : null);
    }

    function applyPrompt(text: string): void {
        const prev = assistantPrompt.text;
        if (text === prev)
            return;
        assistantCtl.run(["horneroctl", "assistant", "prompt", "set-text", text, "--yes", "--json"], {
            "key": "assistant-prompt",
            "title": qsTr("Assistant prompt saved"),
            "detail": qsTr("Undo restores the previous text."),
            "restore": ["horneroctl", "assistant", "prompt", "set-text", prev, "--yes", "--json"]
        });
    }

    Process {
        id: assistantCtlProc

        stderr: StdioCollector {
            id: assistantCtlErr
        }
        onExited: (exitCode, exitStatus) => {
            const job = assistantCtl.current;
            assistantCtl.current = null;
            if (job && job.undo) {
                const u = job.undo;
                if (exitCode === 0)
                    Undo.offerCommand(u.key, u.title, u.restore, u.detail);
                else
                    Undo.report(u.key, qsTr("%1 was not applied").arg(u.title), assistantCtlErr.text.trim().split("\n").slice(-1)[0] || qsTr("horneroctl refused the change."));
            }
            assistantStatus.refresh();
            assistantPolicy.refresh();
            assistantProfile.refresh();
            assistantModelConfig.refresh();
            assistantPrompt.refresh();
            const next = assistantCtl.queued;
            assistantCtl.queued = null;
            if (next)
                assistantCtl.run(next.cmd, next.undo);
        }
    }

    Connections {
        target: Undo

        function onCommandFinished(key: string, ok: bool): void {
            if (key === "assistant-model")
                assistantModelConfig.refresh();
            else if (key === "assistant-prompt")
                assistantPrompt.refresh();
        }
    }

    Component.onCompleted: {
        assistantStatus.refresh();
        assistantPolicy.refresh();
        assistantProfile.refresh();
        assistantPrompt.refresh();
        assistantModelConfig.refresh();
    }
}
