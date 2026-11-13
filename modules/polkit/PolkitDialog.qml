pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
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

    title: qsTr("Authentication required")
    color: Colours.tPalette.m3surface

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

            MaterialIcon {
                text: "lock"
                color: Colours.palette.m3primary
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Authentication required")
                font.pointSize: Appearance.font.size.large
                font.weight: 600
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
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Appearance.font.size.smaller
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: win.flow ? win.flow.supplementaryMessage : ""
            color: win.flow && win.flow.supplementaryIsError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            wrapMode: Text.Wrap
        }

        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: win.flow ? win.flow.inputPrompt : ""
            wrapMode: Text.Wrap
        }

        StyledTextField {
            id: secretField

            Layout.fillWidth: true
            Accessible.name: qsTr("Password")
            placeholderText: qsTr("Password")
            echoMode: win.flow && win.flow.responseVisible ? TextField.Normal : TextField.Password
            enabled: win.flow !== null && win.flow.isResponseRequired
            onAccepted: win.confirm()
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
