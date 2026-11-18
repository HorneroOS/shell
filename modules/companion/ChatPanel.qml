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
// over readable message bubbles. Presentation only: every action
// goes through AssistantBridge -> `horneroctl assistant ... --json`.
// Approvals/clarifications are explicit user actions, never
// auto-answered. Reduced motion disables the shimmer; themes keep
// WCAG contrast in light and dark.
Item {
    id: root

    required property var bridge

    property int dotPhase: 0

    readonly property int cardWidth: 392
    property string pendingLink: ""
    // The input holds text staged from outside the panel (IPC
    // `workbenchDraft`, a hand-off "Edit first"). Such text is sent only
    // by the Send button, which names the mode; Enter does not send it.
    property bool fromDraft: false
    property bool sendArmed: true

    Timer {
        id: sendArmTimer

        // fixed: anti-misclick delay after staged text lands (same as
        // the approval card), a safety bound, not a preference.
        interval: 700
        onTriggered: root.sendArmed = true
    }
    // The conversation yields height to a pending decision so the
    // card is always fully on screen.
    readonly property int listHeight: AssistantRun.pendingDecision ? 96 : Math.min(360, Math.max(140, Screen.height - 520))
    readonly property string lang: root.bridge.lang

    function t(key: string): string {
        return AssistantCopy.t(key, root.lang);
    }

    visible: root.bridge.chatOpen
    // Level C expands the same panel to the right; the layer surface
    // is remapped by the host when `workbenchOpen` changes.
    implicitWidth: root.cardWidth + (root.bridge.workbenchOpen ? bench.implicitWidth + Appearance.spacing.normal : 0)
    implicitHeight: card.implicitHeight

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.durations.medium
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

    function statusColor(): color {
        const st = AssistantRun.status;
        if (st === "connected")
            return Signal.palette.signal;
        if (st === "running")
            return Signal.palette.phosphor;
        return st === "unknown" ? Signal.palette.inkMuted : Signal.palette.alert;
    }

    // A hand-off from the quick ask stages text here; it is never sent
    // until the user presses Send.
    Connections {
        target: root.bridge

        function onDraftChanged(): void {
            if (root.bridge.draft === "")
                return;
            const staged = root.bridge.draft;
            root.bridge.draft = "";
            // Never replace what the user is typing, and never take the
            // keyboard for text that came from outside.
            if (input.text.trim() !== "") {
                CompanionStore.say(qsTr("Kept what you were typing; the staged text was not inserted."), 5000);
                return;
            }
            // Written into the field itself, so it is visible even while
            // the field has focus (what is shown is what Send sends).
            input.replaceText(AssistantRun.visibleText(staged));
            root.fromDraft = true;
            // Send stays disabled briefly, so a click aimed at something
            // else cannot send text that just appeared.
            root.sendArmed = false;
            sendArmTimer.restart();
            if (staged.length > AssistantRun.detailCap)
                CompanionStore.say(qsTr("The staged text was too long and was cut. Check it before sending."), 6000);
        }
    }

    function focusInput(): void {
        input.focusInput();
    }

    function sendCurrent(): void {
        if (!root.sendArmed)
            return;
        const text = input.text.trim();
        if (text === "" && root.bridge.attachments.length === 0)
            return;
        root.bridge.ask(text);
        input.replaceText("");
        root.fromDraft = false;
    }

    // Enter in the input. Staged text needs the Send button.
    function acceptInput(): void {
        if (root.fromDraft) {
            CompanionStore.say(qsTr("This text was staged for you. Check it, then press Send (%1).").arg(root.t("mode." + CompanionStore.chatMode)), 6000);
            return;
        }
        root.sendCurrent();
    }

    StyledRect {
        id: card

        width: root.cardWidth
        implicitHeight: layout.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.small
        color: Signal.palette.panel
        // Hornero 199X frame: a phosphor accent edge around the card.
        border.width: 1
        border.color: Qt.alpha(Signal.palette.phosphor, 0.55)

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            // -- Header: Javi identity + backend status ---------------
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                Image {
                    sourceSize: Qt.size(68, 68)
                    source: Companion.frameSource(CompanionStore.effectiveSkin, "idle")
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    Layout.maximumWidth: 34
                    Layout.maximumHeight: 34
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0

                    RowLayout {
                        spacing: Appearance.spacing.small

                        StyledText {
                            text: qsTr("JAVI · EL HORNERO")
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.normal
                            font.bold: true
                            color: Signal.palette.ink
                        }

                        // 199X badge: the retrofuturist marque.
                        Rectangle {
                            implicitWidth: badgeText.implicitWidth + 10
                            implicitHeight: badgeText.implicitHeight + 4
                            radius: 3
                            color: Qt.alpha(Signal.palette.phosphor, 0.18)
                            border.width: 1
                            border.color: Qt.alpha(Signal.palette.phosphor, 0.65)

                            StyledText {
                                id: badgeText

                                anchors.centerIn: parent
                                text: "199X"
                                font.family: Appearance.font.family.mono
                                font.pointSize: Appearance.font.size.smaller
                                font.bold: true
                                color: Signal.palette.phosphor
                            }
                        }
                    }

                    RowLayout {
                        spacing: Appearance.spacing.small

                        // Phosphor status light: same colour as the status text.
                        Rectangle {
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: root.statusColor()
                            opacity: root.bridge.busy && !CompanionStore.reducedMotion ? (root.dotPhase % 2 === 0 ? 1 : 0.35) : 1
                        }

                        StyledText {
                            // One honest status from the canonical state
                            // (connected / disconnected / running / blocked /
                            // awaiting approval / failed / degraded).
                            text: root.t("status." + (AssistantRun.probing && AssistantRun.status === "disconnected" ? "reconnecting" : AssistantRun.status))
                            font.family: Appearance.font.family.mono
                            font.pointSize: Appearance.font.size.smaller
                            color: root.statusColor()
                            elide: Text.ElideRight
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                IconButton {
                    icon: root.bridge.workbenchOpen ? "arrows-minimize" : "layout-sidebar-right"
                    accessibleName: root.t(root.bridge.workbenchOpen ? "workbench.collapse" : "workbench.expand")
                    type: IconButton.Text
                    checked: root.bridge.workbenchOpen
                    onClicked: root.bridge.workbenchOpen = !root.bridge.workbenchOpen
                }

                IconButton {
                    icon: "trash"
                    accessibleName: qsTr("Clear chat history")
                    type: IconButton.Text
                    onClicked: root.bridge.clearHistory()
                }

                IconButton {
                    icon: "x"
                    type: IconButton.Text
                    accessibleName: qsTr("Close chat")
                    onClicked: root.bridge.chatOpen = false
                }
            }

            // Scanline accent under the header (static; no shimmer
            // when reduced motion is on).
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 2
                color: Qt.alpha(Signal.palette.signal, CompanionStore.reducedMotion ? 0.25 : 0.45)
                radius: 1
            }

            // -- Connection banner: only when something needs attention
            RowLayout {
                Layout.fillWidth: true
                visible: AssistantRun.status === "disconnected" || AssistantRun.status === "degraded" || AssistantRun.status === "disabled" || AssistantRun.status === "degraded-isolation"
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: AssistantRun.status === "disabled" ? root.t("error.disabled") : AssistantRun.status === "degraded-isolation" ? qsTr("The gateway is not sandboxed. Approvals matter more.") : root.bridge.statusMessage
                    textFormat: Text.PlainText
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.alert
                    wrapMode: Text.Wrap
                }

                TextButton {
                    visible: AssistantRun.status === "disconnected"
                    text: root.t("action.reconnect")
                    type: TextButton.Tonal
                    onClicked: root.bridge.refreshStatus()
                }
            }

            // -- Session bar (hornero#189): named chats + model -----
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Glyph {
                    name: "messages"
                    font.pointSize: Appearance.font.size.normal
                    color: Signal.palette.inkMuted
                }

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.bridge.currentSessionTitle
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.ink
                    elide: Text.ElideRight
                }

                StyledText {
                    visible: root.bridge.currentModel !== ""
                    text: root.bridge.currentModel
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.ruleStrong
                }

                IconButton {
                    icon: "arrows-exchange"
                    accessibleName: qsTr("Switch chat session")
                    type: IconButton.Text
                    visible: root.bridge.chatSessions.length > 1
                    onClicked: root.bridge.cycleChatSession()
                }

                IconButton {
                    icon: "message-plus"
                    accessibleName: qsTr("New chat")
                    type: IconButton.Text
                    onClicked: root.bridge.newChatSession()
                }
            }

            // -- Mode bar: Ask never escalates, Agent surfaces approvals,
            // Chat has no machine authority (enforced by horneroctl). --
            RowLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.small

                Glyph {
                    name: "shield"
                    font.pointSize: Appearance.font.size.normal
                    color: Signal.palette.inkMuted
                }

                Repeater {
                    model: [
                        { id: "ask", label: qsTr("Ask") },
                        { id: "agent", label: qsTr("Agent") },
                        { id: "chat", label: qsTr("Chat") }
                    ]

                    TextButton {
                        required property var modelData

                        text: modelData.label
                        toggle: true
                        checked: CompanionStore.chatMode === modelData.id
                        type: TextButton.Tonal
                        onClicked: CompanionStore.setChatMode(modelData.id)
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: CompanionStore.chatMode === "agent" ? qsTr("Approvals ask you first") : qsTr("Approval requests are denied automatically")
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.ruleStrong
                    elide: Text.ElideRight
                }
            }

            // -- Conversation -----------------------------------------
            ListView {
                id: view

                Layout.fillWidth: true
                Layout.preferredHeight: root.listHeight
                Layout.minimumHeight: root.listHeight
                Layout.maximumHeight: root.listHeight
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

                    property bool traceOpen: false

                    width: ListView.view.width
                    implicitHeight: bubble.implicitHeight

                    StyledRect {
                        id: bubble

                        readonly property bool mine: modelData.role === "user"
                        readonly property bool system: modelData.role === "system"

                        anchors.right: bubble.mine ? parent.right : undefined
                        anchors.left: bubble.mine ? undefined : parent.left
                        width: parent.width * 0.86
                        implicitHeight: textItem.implicitHeight + (histTrace.visible ? histTrace.implicitHeight + Appearance.spacing.small : 0) + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: bubble.system ? Qt.alpha(Signal.palette.alert, 0.14) : bubble.mine ? Signal.palette.signalWell : Signal.palette.raised

                        Rectangle {
                            visible: modelData.role === "assistant"
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.margins: 6
                            width: 3
                            radius: 2
                            color: Qt.alpha(Signal.palette.phosphor, 0.8)
                        }

                        StyledText {
                            id: textItem

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Appearance.padding.large
                            text: modelData.role === "assistant" ? AssistantRun.safeMarkdown(modelData.text) : modelData.text
                            textFormat: modelData.role === "assistant" && AssistantRun.markdownOk(modelData.text) ? Text.MarkdownText : Text.PlainText
                            font.pointSize: Appearance.font.size.small
                            color: bubble.mine ? Signal.palette.onSignalWell : Signal.palette.ink
                            linkColor: bubble.mine ? Signal.palette.onSignalWell : Signal.palette.signal
                            wrapMode: Text.Wrap
                            onLinkActivated: link => {
                                // Show the real target first; opening is a
                                // second, explicit click.
                                if (AssistantRun.isSafeLink(link))
                                    root.pendingLink = link;
                            }
                        }

                        ColumnLayout {
                            id: histTrace

                            visible: !!(modelData.trace && modelData.trace !== "")
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: textItem.bottom
                            anchors.margins: Appearance.padding.large
                            spacing: Appearance.spacing.small

                            StyledText {
                                text: parent.parent.parent.traceOpen ? qsTr("HIDE ACTIVITY TRACE") : qsTr("SHOW ACTIVITY TRACE")
                                font.family: Appearance.font.family.mono
                                font.pointSize: Appearance.font.size.smaller
                                color: Signal.palette.phosphor

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: parent.parent.parent.parent.traceOpen = !parent.parent.parent.parent.traceOpen
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: parent.parent.parent.traceOpen
                                text: modelData.trace ?? ""
                                textFormat: Text.PlainText
                                font.family: Appearance.font.family.mono
                                font.pointSize: Appearance.font.size.smaller
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }

                // Streaming assistant bubble (live deltas).
                footer: ColumnLayout {
                    width: view.width
                    spacing: Appearance.spacing.normal

                    // Live activity trace (reasoning previews, tool
                    // lifecycle, commentary) as the gateway emits it.
                    StyledRect {
                        visible: root.bridge.busy && root.bridge.traceText !== ""
                        Layout.alignment: Qt.AlignLeft
                        implicitWidth: Math.min(view.width * 0.86, traceText.implicitWidth + Appearance.padding.large * 2)
                        implicitHeight: traceCol.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: Qt.alpha(Signal.palette.phosphorWell, 0.35)

                        ColumnLayout {
                            id: traceCol

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Appearance.padding.large
                            spacing: Appearance.spacing.small

                            StyledText {
                                text: qsTr("ACTIVITY TRACE · LIVE")
                                font.family: Appearance.font.family.mono
                                font.pointSize: Appearance.font.size.smaller
                                color: Signal.palette.phosphor
                            }

                            StyledText {
                                id: traceText

                                Layout.fillWidth: true
                                text: root.bridge.traceText.split("\n").slice(-8).join("\n")
                                textFormat: Text.PlainText
                                font.family: Appearance.font.family.mono
                                font.pointSize: Appearance.font.size.smaller
                                color: Signal.palette.inkMuted
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    StyledRect {
                        visible: root.bridge.busy
                        Layout.alignment: Qt.AlignLeft
                        implicitWidth: Math.min(view.width * 0.86, streamText.implicitWidth + Appearance.padding.large * 2)
                        implicitHeight: streamText.implicitHeight + Appearance.padding.normal * 2
                        radius: Appearance.rounding.small
                        color: Signal.palette.raised

                        StyledText {
                            id: streamText

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: Appearance.padding.large
                            text: root.bridge.streamText !== "" ? AssistantRun.safeMarkdown(root.bridge.streamText) : root.t("thinking") + ".".repeat(root.dotPhase)
                            textFormat: AssistantRun.markdownOk(root.bridge.streamText) ? Text.MarkdownText : Text.PlainText
                            font.pointSize: Appearance.font.size.small
                            color: Signal.palette.ink
                            linkColor: Signal.palette.signal
                            wrapMode: Text.Wrap
                        }
                    }

                    // Empty state: suggestion chips.
                    Flow {
                        visible: view.count === 0 && !root.bridge.busy
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.small

                        Repeater {
                            model: ["chip.updates", "chip.slow", "chip.themes", "chip.capabilities"].map(k => root.t(k))

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

            // -- Pending approval / clarification --------------------
            ApprovalCard {
                bridge: root.bridge
            }

            ClarifyCard {
                bridge: root.bridge
            }

            // -- Link target confirmation --------------------------------
            RowLayout {
                Layout.fillWidth: true
                visible: root.pendingLink !== ""
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: AssistantRun.visibleText(root.pendingLink)
                    textFormat: Text.PlainText
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.ink
                    wrapMode: Text.WrapAnywhere
                }

                TextButton {
                    text: qsTr("Open")
                    type: TextButton.Tonal
                    onClicked: {
                        Qt.openUrlExternally(root.pendingLink);
                        root.pendingLink = "";
                    }
                }

                TextButton {
                    text: qsTr("Cancel")
                    type: TextButton.Text
                    onClicked: root.pendingLink = ""
                }
            }

            // -- One-time notice: Agent became opt-in (N3 migration) -------
            RowLayout {
                Layout.fillWidth: true
                visible: CompanionStore.agentOptInNotice
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.t("mode.agent-opt-in")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.ink
                    wrapMode: Text.Wrap
                }

                TextButton {
                    text: root.t("handoff.dismiss")
                    type: TextButton.Text
                    onClicked: CompanionStore.dismissAgentOptInNotice()
                }
            }

            // -- Voice clip held after the 2-minute auto-stop -------------
            RowLayout {
                Layout.fillWidth: true
                visible: root.bridge.heldClip !== ""
                spacing: Appearance.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.t("mic.held")
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.ink
                    wrapMode: Text.Wrap
                }

                TextButton {
                    text: root.t("mic.attach")
                    type: TextButton.Tonal
                    onClicked: root.bridge.attachHeldClip()
                }

                TextButton {
                    text: root.t("mic.discard")
                    type: TextButton.Text
                    onClicked: root.bridge.dropHeldClip()
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
                    icon: "paperclip"
                    accessibleName: qsTr("Attach file")
                    type: IconButton.Text
                    onClicked: fileDialog.open()
                }

                IconButton {
                    icon: root.bridge.recording ? "player-stop" : "microphone"
                    accessibleName: root.bridge.recording ? qsTr("Stop recording") : qsTr("Record voice message")
                    type: IconButton.Text
                    checked: root.bridge.recording
                    onClicked: root.bridge.recording ? root.bridge.stopRecording(true, false) : root.bridge.startRecording()
                }

                StyledInputField {
                    id: input

                    Layout.fillWidth: true
                    Layout.minimumWidth: 48
                    horizontalAlignment: TextInput.AlignLeft
                    // Enter only: editingFinished also fires when focus
                    // leaves the field, which must never send anything.
                    onAccepted: root.acceptInput()
                    onTextChanged: {
                        if (text === "")
                            root.fromDraft = false;
                    }

                    Keys.onEscapePressed: root.bridge.chatOpen = false
                }

                TextButton {
                    visible: root.bridge.busy || AssistantRun.pendingDecision
                    text: root.t("action.stop")
                    type: TextButton.Tonal
                    // Not while a decision is on its way (it may already
                    // be approved); the bridge refuses it too.
                    enabled: !root.bridge.decisionBusy
                    onClicked: root.bridge.askStop()
                }

                TextButton {
                    // The mode is always on the button that sends.
                    text: qsTr("Send") + " · " + root.t("mode." + CompanionStore.chatMode)
                    type: TextButton.Filled
                    enabled: root.sendArmed && (input.text.trim() !== "" || root.bridge.attachments.length > 0)
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

                TextButton {
                    text: qsTr("Copy answer")
                    type: TextButton.Text
                    onClicked: root.bridge.copyLastAnswer()
                }

            }

            // -- Microphone status: explicit, cancellable ---------------
            RowLayout {
                Layout.fillWidth: true
                visible: root.bridge.recording
                spacing: Appearance.spacing.small

                Rectangle {
                    implicitWidth: 9
                    implicitHeight: 9
                    radius: 5
                    color: Signal.palette.alert
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.t("mic.recording") + "  " + Math.floor(root.bridge.recordSeconds / 60) + ":" + ("0" + (root.bridge.recordSeconds % 60)).slice(-2) + " / 2:00"
                    font.family: Appearance.font.family.mono
                    font.pointSize: Appearance.font.size.smaller
                    color: Signal.palette.alert
                }

                TextButton {
                    text: root.t("mic.cancel")
                    type: TextButton.Tonal
                    onClicked: root.bridge.stopRecording(false, false)
                }

                TextButton {
                    text: root.t("mic.send")
                    type: TextButton.Filled
                    onClicked: root.bridge.stopRecording(true, false)
                }
            }
        }
    }

    WorkbenchPane {
        id: bench

        visible: root.bridge.workbenchOpen
        bridge: root.bridge
        x: root.cardWidth + Appearance.spacing.normal
        height: card.implicitHeight
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
            if (!root.fromDraft && root.bridge.draft === "")
                input.forceActiveFocus();
            root.bridge.refreshStatus();
        }
    }
}
