pragma ComponentBehavior: Bound

import ".."
import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Passkey confirmation / PIN entry for the Bluetooth pairing agent.
//
// This dialog never confirms on its own: it only shows what the external
// hornero-bt-agent (org.bluez.Agent1) forwarded through BluetoothState and
// returns the user's explicit choice via confirmPairing() /
// submitPairingPin() / rejectPairing(). Closing, Escape, or rejecting all
// mean Reject to BlueZ; there is no auto-accept path and no timeout in the
// shell that would confirm after a delay (BlueZ/agent owns the 60s timeout
// and calls cancelPairingRequest()).
Item {
    id: root

    required property Session session

    visible: session.bt.showPairingDialog
    enabled: visible
    focus: enabled

    Keys.onEscapePressed: session.bt.rejectPairing()

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)

        MouseArea {
            Accessible.name: qsTr("Reject pairing")
            anchors.fill: parent
            // Clicking outside is a rejection, never a dismissal that
            // leaves BlueZ waiting on a hidden dialog.
            onClicked: root.session.bt.rejectPairing()
        }
    }

    StyledRect {
        id: dialog

        anchors.centerIn: parent
        implicitWidth: 400
        implicitHeight: content.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.normal
        color: Colours.tPalette.m3surface

        ColumnLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "bluetooth"
                font.pointSize: Appearance.font.size.extraLarge * 2
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.session.bt.pairingKind === "confirmation" ? qsTr("Confirm passkey") : qsTr("Enter pairing code")
                font.pointSize: Appearance.font.size.large
                font.weight: 500
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: root.session.bt.pairingDeviceAddress ? qsTr("Device: %1 (%2)").arg(root.session.bt.pairingDeviceName).arg(root.session.bt.pairingDeviceAddress) : qsTr("Device: %1").arg(root.session.bt.pairingDeviceName)
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.small
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: root.session.bt.pairingKind === "confirmation"
                text: root.session.bt.pairingPasskey
                font.pointSize: Appearance.font.size.extraLarge
                font.family: Appearance.font.family.mono
                font.weight: 600
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: root.session.bt.pairingKind === "confirmation"
                text: qsTr("Only confirm if this code matches the code shown on the other device.")
                color: Colours.palette.m3outline
                font.pointSize: Appearance.font.size.small
            }

            StyledTextField {
                id: pinField

                Layout.fillWidth: true
                visible: root.session.bt.pairingKind !== "confirmation"
                placeholderText: root.session.bt.pairingKind === "passkey" ? qsTr("6-digit passkey") : qsTr("PIN code")
                inputMethodHints: Qt.ImhDigitsOnly
                echoMode: TextInput.Normal

                onAccepted: {
                    if (text.length > 0)
                        root.session.bt.submitPairingPin(text);
                }

                Connections {
                    target: root.session.bt

                    function onShowPairingDialogChanged(): void {
                        pinField.text = "";
                        if (root.session.bt.showPairingDialog && root.session.bt.pairingKind !== "confirmation")
                            pinField.forceActiveFocus();
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Appearance.spacing.normal
                spacing: Appearance.spacing.normal

                TextButton {
                    Layout.fillWidth: true
                    inactiveColour: Colours.palette.m3secondaryContainer
                    inactiveOnColour: Colours.palette.m3onSecondaryContainer
                    text: qsTr("Reject")

                    onClicked: root.session.bt.rejectPairing()
                }

                TextButton {
                    Layout.fillWidth: true
                    inactiveColour: Colours.palette.m3primary
                    inactiveOnColour: Colours.palette.m3onPrimary
                    text: root.session.bt.pairingKind === "confirmation" ? qsTr("Confirm") : qsTr("Pair")
                    enabled: root.session.bt.pairingKind === "confirmation" || pinField.text.length > 0

                    onClicked: {
                        if (root.session.bt.pairingKind === "confirmation")
                            root.session.bt.confirmPairing();
                        else if (pinField.text.length > 0)
                            root.session.bt.submitPairingPin(pinField.text);
                    }
                }
            }
        }
    }
}
