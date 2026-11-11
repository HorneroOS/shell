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

                StyledText {
                    text: qsTr("Javi · el Hornero")
                    font.pointSize: Appearance.font.size.large
                    font.weight: 500
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Javi, el Hornero: your sidekick. Idles, greets, shows tips — and, with Hermes enabled, chats, reads the system and always asks before changing anything.")
                    font.pointSize: Appearance.font.size.small
                    color: Colours.palette.m3outline
                    wrapMode: Text.Wrap
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: generalCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: generalCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("General")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

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


                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: assistantCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: assistantCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Assistant (Hermes)")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: assistantStatus.text
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Optional and local: Hermes runs as your user on loopback, Javi talks to it only through horneroctl, and nothing changes the system without your approval. Keys never enter this panel.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
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
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: hermesCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: hermesCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Hermes agent")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Live state from horneroctl. Model, provider, API keys and token usage are managed in the Hermes dashboard — keys never enter this panel.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
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
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: assistantLog.text !== ""
                            text: assistantLog.text
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.smaller
                            color: Colours.palette.m3outline
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
                                    onClicked: modelInput.text = modelData
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            StyledInputField {
                                id: modelInput

                                Layout.fillWidth: true
                            }

                            TextButton {
                                text: qsTr("Apply model")
                                type: TextButton.Tonal
                                onClicked: {
                                    const id = modelInput.text.trim();
                                    if (id !== "" && !id.includes(" "))
                                        assistantCtl.run(["horneroctl", "assistant", "model", "set", id, "--yes", "--json"]);
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Applies to new chats (same as hermes model); running chats keep their model.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
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

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: policyCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: policyCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Permissions & security")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Enforced by horneroctl, outside the agent. Deny always wins; screenshots, clipboard and shell stay off or approval-gated unless a preset allows them. The agent cannot edit its own policy.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: assistantPolicy.text
                            font.pointSize: Appearance.font.size.small
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

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: promptCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: promptCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Personality & system prompt")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("This is Javi's full user-configurable system prompt (Hermes SOUL.md). Saving snapshots the previous version for rollback. Behaviour only: it can never widen permissions or the sandbox.")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
                            wrapMode: Text.Wrap
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 140
                            radius: Appearance.rounding.small
                            color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 1)

                            TextEdit {
                                id: promptEditor

                                anchors.fill: parent
                                anchors.margins: Appearance.padding.small
                                color: Colours.palette.m3onSurface
                                font.family: Appearance.font.family.mono
                                font.pointSize: Appearance.font.size.small
                                wrapMode: TextEdit.Wrap
                                selectByMouse: true
                                text: assistantPrompt.text
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Appearance.spacing.small

                            TextButton {
                                text: qsTr("Save prompt")
                                type: TextButton.Filled
                                onClicked: assistantPrompt.save(promptEditor.text)
                            }

                            TextButton {
                                text: qsTr("Reload")
                                type: TextButton.Tonal
                                onClicked: assistantPrompt.refresh()
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: assistantPromptHistory.text
                                font.pointSize: Appearance.font.size.small
                                color: Colours.palette.m3outline
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: charCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: charCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Character")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

                        StyledText {
                            text: qsTr("Skin")
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
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
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
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
                            font.pointSize: Appearance.font.size.small
                            color: Colours.palette.m3outline
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

                StyledRect {
                    Layout.fillWidth: true
                    radius: Appearance.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 1)
                    implicitHeight: actionCol.implicitHeight + Appearance.padding.large * 2

                    ColumnLayout {
                        id: actionCol

                        anchors.fill: parent
                        anchors.margins: Appearance.padding.large
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("Actions")
                            font.pointSize: Appearance.font.size.normal
                            font.weight: 500
                        }

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

        function save(text): void {
            assistantPromptSaveProc.command = ["horneroctl", "assistant", "prompt", "set-text", text.toString(), "--yes", "--json"];
            assistantPromptSaveProc.running = true;
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

    Process {
        id: assistantPromptSaveProc

        onExited: (exitCode, exitStatus) => assistantPrompt.refresh()
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
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurfaceVariant
        }

        StyledText {
            Layout.fillWidth: true
            text: value
            font.pointSize: Appearance.font.size.small
            color: Colours.palette.m3onSurface
            wrapMode: Text.Wrap
        }
    }

    QtObject {
        id: assistantCtl

        function run(cmd): void {
            assistantCtlProc.command = cmd;
            assistantCtlProc.running = true;
        }
    }

    Process {
        id: assistantCtlProc

        onExited: (exitCode, exitStatus) => {
            assistantStatus.refresh();
            assistantPolicy.refresh();
            assistantProfile.refresh();
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
