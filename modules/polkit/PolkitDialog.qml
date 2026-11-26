pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Authentication dialog for the native polkit agent (shell#352).
// Fail-closed: every dismissal path (Cancel, Escape, window close)
// funnels through cancelRequest(). The secret is submitted only from
// confirm(), is never logged or persisted, and the field is cleared
// on submit, completion, failure and cancellation.
FloatingWindow {
    id: win

    required property PolkitAgent agent

    // AuthFlow is non-creatable in the qmltypes; hold it untyped.
    readonly property var flow: win.agent.flow
    property bool _closing: false
    property string _requesterLabel: ""
    property string _requesterDetail: ""
    property bool _requesterIsAgent: false
    property string _requesterAgentName: ""

    title: qsTr("Authentication required")
    color: Signal.tPalette.base

    implicitWidth: 480
    implicitHeight: 360
    minimumSize.width: 420
    minimumSize.height: 320

    visible: win.agent.isRegistered && win.flow !== null && !win.flow.isCompleted && !win._closing

    function clearSecret(): void {
        secretField.text = "";
    }

    function confirm(): void {
        if (win.flow === null || !win.flow.isResponseRequired)
            return;
        win.flow.submit(secretField.text);
        win.clearSecret();
    }

    function cancelRequest(): void {
        win.clearSecret();
        if (win.flow !== null && !win.flow.isCompleted) {
            win._closing = true;
            win.flow.cancelAuthenticationRequest();
        }
    }

    onFlowChanged: {
        win._closing = false;
        win.clearSecret();
        win._requesterLabel = "";
        win._requesterDetail = "";
        win._requesterIsAgent = false;
        win._requesterAgentName = "";
        if (win.flow !== null) {
            requesterProc.command = [
                "python3",
                Qt.resolvedUrl("../../scripts/polkit_requester.py").toString().replace(/^file:\/\//, ""),
                "--action-id",
                win.flow.actionId || "",
                "--message",
                win.flow.message || ""
            ];
            requesterProc.running = true;
        }
    }

    // FloatingWindow has no closing signal: a hide that is not driven
    // by completion is a user close and must cancel (fail closed).
    onVisibleChanged: {
        if (visible) {
            secretField.forceActiveFocus();
        } else {
            win.clearSecret();
            if (win.flow !== null && !win.flow.isCompleted && !win._closing)
                win.cancelRequest();
        }
    }

    Connections {
        target: win.flow

        function onIsCompletedChanged(): void {
            if (win.flow.isCompleted)
                win.clearSecret();
        }

        function onAuthenticationSucceeded(): void {
            win.clearSecret();
        }

        function onAuthenticationFailed(): void {
            win.clearSecret();
        }

        function onAuthenticationRequestCancelled(): void {
            win.clearSecret();
        }
    }

    Process {
        id: requesterProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text.trim());
                    win._requesterLabel = parsed.label || "";
                    win._requesterDetail = parsed.detail || "";
                    win._requesterIsAgent = Boolean(parsed.is_agent);
                    win._requesterAgentName = parsed.agent_name || "";
                } catch (e) {
                    win._requesterLabel = "";
                    win._requesterDetail = "";
                    win._requesterIsAgent = false;
                    win._requesterAgentName = "";
                }
            }
        }
    }

    Shortcut {
        sequences: ["Escape"]
        context: Qt.WindowShortcut
        onActivated: win.cancelRequest()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Glyph {
                name: "lock"
                color: Signal.palette.signal
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Eyebrow {
                    Layout.fillWidth: true
                    label: qsTr("Administrator")
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Authentication required")
                    font.pointSize: Appearance.font.size.large
                    font.weight: Appearance.font.weight.strong
                    Accessible.role: Accessible.Heading
                }
            }
        }

        Well {
            Layout.fillWidth: true
            visible: win._requesterLabel !== ""
            implicitHeight: requesterCol.implicitHeight + Appearance.padding.small * 2
            outline: win._requesterIsAgent ? Signal.palette.alert : Signal.palette.rule

            ColumnLayout {
                id: requesterCol

                anchors.fill: parent
                anchors.margins: Appearance.padding.small
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Appearance.spacing.small

                    StyledText {
                        Layout.fillWidth: true
                        text: win._requesterLabel
                        font.weight: Appearance.font.weight.strong
                        color: win._requesterIsAgent ? Signal.palette.alert : Signal.palette.ink
                        wrapMode: Text.Wrap
                    }

                    StyledText {
                        visible: win._requesterIsAgent
                        text: qsTr("AI AGENT")
                        font.pointSize: Appearance.font.size.smaller
                        font.weight: Appearance.font.weight.strong
                        color: Signal.palette.alert
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: win._requesterDetail !== ""
                    text: win._requesterDetail
                    color: Signal.palette.inkMuted
                    font.pointSize: Appearance.font.size.smaller
                    wrapMode: Text.Wrap
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: win.flow ? win.flow.message : ""
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            text: win.flow ? win.flow.actionId : ""
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.smaller
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: win.flow ? win.flow.supplementaryMessage : ""
            color: win.flow && win.flow.supplementaryIsError ? Signal.palette.alert : Signal.palette.inkMuted
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: win.flow ? win.flow.inputPrompt : ""
            wrapMode: Text.Wrap
        }

        Well {
            Layout.fillWidth: true
            implicitHeight: secretField.implicitHeight + Appearance.padding.small * 2
            outline: secretField.activeFocus ? Signal.palette.focus : Signal.palette.rule

        StyledTextField {
            id: secretField

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal
            Accessible.name: qsTr("Password")
            placeholderText: qsTr("Password")
            echoMode: win.flow && win.flow.responseVisible ? TextField.Normal : TextField.Password
            enabled: win.flow !== null && win.flow.isResponseRequired
            onAccepted: win.confirm()
        }
        }

        Item {
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Item {
                Layout.fillWidth: true
            }

            TextButton {
                type: TextButton.Text
                text: qsTr("Cancel")
                onClicked: win.cancelRequest()
            }

            TextButton {
                text: qsTr("Authenticate")
                disabled: win.flow === null || !win.flow.isResponseRequired
                onClicked: win.confirm()
            }
        }
    }
}
