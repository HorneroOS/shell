pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.containers
import qs.services
import qs.config
import qs.utils
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

DeviceDetails {
    id: root

    required property Session session
    readonly property var vpnProvider: root.session.vpn.active
    readonly property bool providerEnabled: {
        if (!vpnProvider || vpnProvider.index === undefined)
            return false;
        const provider = Config.utilities.vpn.provider[vpnProvider.index];
        return provider && typeof provider === "object" && provider.enabled === true;
    }

    device: vpnProvider

    headerComponent: Component {
        ConnectionHeader {
            icon: "key"
            title: root.vpnProvider?.displayName ?? qsTr("Unknown")
        }
    }

    sections: [
        Component {
            ColumnLayout {
                spacing: Appearance.spacing.normal

                SectionHeader {
                    title: qsTr("Connection status")
                    description: qsTr("VPN connection settings")
                }

                SectionContainer {
                    ToggleRow {
                        label: qsTr("Enable this provider")
                        checked: root.providerEnabled
                        toggle.onToggled: {
                            if (!root.vpnProvider)
                                return;
                            const providers = [];
                            const index = root.vpnProvider.index;

                            // Copy providers and update enabled state
                            for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                                const p = Config.utilities.vpn.provider[i];
                                if (typeof p === "object") {
                                    const newProvider = {
                                        name: p.name,
                                        displayName: p.displayName,
                                        interface: p.interface
                                    };

                                    if (checked) {
                                        // Enable this one, disable others
                                        newProvider.enabled = (i === index);
                                    } else {
                                        // Just disable this one
                                        newProvider.enabled = (i === index) ? false : (p.enabled !== false);
                                    }

                                    providers.push(newProvider);
                                } else {
                                    providers.push(p);
                                }
                            }

                            Config.utilities.vpn.provider = providers;
                            Config.save();
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: Appearance.spacing.normal
                        spacing: Appearance.spacing.normal

                        TextButton {
                            Layout.fillWidth: true
                            Layout.minimumHeight: Appearance.font.size.normal + Appearance.padding.normal * 2
                            visible: root.providerEnabled
                            enabled: !VPN.connecting
                            inactiveColour: Signal.palette.signalWell
                            inactiveOnColour: Signal.palette.onSignalWell
                            text: VPN.connected ? qsTr("Disconnect") : qsTr("Connect")

                            onClicked: {
                                VPN.toggle();
                            }
                        }

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("Edit Provider")
                            inactiveColour: Signal.palette.cueWell
                            inactiveOnColour: Signal.palette.onCueWell

                            onClicked: {
                                editVpnDialog.editIndex = root.vpnProvider.index;
                                editVpnDialog.providerName = root.vpnProvider.name;
                                editVpnDialog.displayName = root.vpnProvider.displayName;
                                editVpnDialog.interfaceName = root.vpnProvider.interface;
                                editVpnDialog.open();
                            }
                        }

                        TextButton {
                            Layout.fillWidth: true
                            text: qsTr("Delete Provider")
                            inactiveColour: Signal.palette.alertWell
                            inactiveOnColour: Signal.palette.onAlertWell

                            onClicked: {
                                const providers = [];
                                for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                                    if (i !== root.vpnProvider.index) {
                                        providers.push(Config.utilities.vpn.provider[i]);
                                    }
                                }
                                Config.utilities.vpn.provider = providers;
                                Config.save();
                                root.session.vpn.active = null;
                            }
                        }
                    }
                }
            }
        },
        Component {
            ColumnLayout {
                spacing: Appearance.spacing.normal

                SectionHeader {
                    title: qsTr("Provider details")
                    description: qsTr("VPN provider information")
                }

                SectionContainer {
                    contentSpacing: Appearance.spacing.small / 2

                    PropertyRow {
                        label: qsTr("Provider")
                        value: root.vpnProvider?.name ?? qsTr("Unknown")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("Display name")
                        value: root.vpnProvider?.displayName ?? qsTr("Unknown")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("Interface")
                        value: root.vpnProvider?.interface || qsTr("N/A")
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("Status")
                        value: {
                            if (!root.providerEnabled)
                                return qsTr("Disabled");
                            if (VPN.connecting)
                                return qsTr("Connecting...");
                            if (VPN.connected)
                                return qsTr("Connected");
                            return qsTr("Enabled (Not connected)");
                        }
                    }

                    PropertyRow {
                        showTopMargin: true
                        label: qsTr("Enabled")
                        value: root.providerEnabled ? qsTr("Yes") : qsTr("No")
                    }
                }
            }
        }
    ]

    // Edit VPN Dialog
    Popup {
        id: editVpnDialog

        property int editIndex: -1
        property string providerName: ""
        property string displayName: ""
        property string interfaceName: ""

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(400, parent.width - Appearance.padding.large * 2)
        padding: Appearance.padding.large * 1.5

        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        opacity: 0
        scale: 0.7

        enter: Transition {
            Anim {
                property: "opacity"
                from: 0
                to: 1
                duration: Appearance.anim.durations.settleFast
                easing.bezierCurve: Appearance.anim.curves.settleFast
            }
            Anim {
                property: "scale"
                from: 0.7
                to: 1
                duration: Appearance.anim.durations.settleFast
                easing.bezierCurve: Appearance.anim.curves.settleFast
            }
        }

        exit: Transition {
            Anim {
                property: "opacity"
                from: 1
                to: 0
                duration: Appearance.anim.durations.settleFast
                easing.bezierCurve: Appearance.anim.curves.settleFast
            }
            Anim {
                property: "scale"
                from: 1
                to: 0.7
                duration: Appearance.anim.durations.settleFast
                easing.bezierCurve: Appearance.anim.curves.settleFast
            }
        }

        function closeWithAnimation(): void {
            close();
        }

        Overlay.modal: Rectangle {
            color: Qt.rgba(0, 0, 0, 0.4 * editVpnDialog.opacity)
        }

        background: StyledRect {
            color: Signal.palette.raised
            radius: Appearance.rounding.small

            Elevation {
                anchors.fill: parent
                radius: parent.radius
                level: 3
                z: -1
            }
        }

        contentItem: ColumnLayout {
            spacing: Appearance.spacing.normal

            StyledText {
                text: qsTr("Edit VPN Provider")
                font.pointSize: Appearance.font.size.large
                font.weight: 500
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.smaller / 2

                StyledText {
                    text: qsTr("Display Name")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    color: displayNameField.activeFocus ? Signal.layer(Signal.palette.panel, 3) : Signal.layer(Signal.palette.panel, 2)
                    radius: Appearance.rounding.small
                    border.width: 1
                    border.color: displayNameField.activeFocus ? Signal.palette.signal : Qt.alpha(Signal.palette.ruleStrong, 0.3)

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on border.color {
                        CAnim {}
                    }

                    StyledTextField {
                        id: displayNameField
                        anchors.centerIn: parent
                        width: parent.width - Appearance.padding.normal
                        horizontalAlignment: TextInput.AlignLeft
                        text: editVpnDialog.displayName
                        onTextChanged: editVpnDialog.displayName = text
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Appearance.spacing.smaller / 2

                StyledText {
                    text: qsTr("Interface (e.g., wg0, torguard)")
                    font.pointSize: Appearance.font.size.small
                    color: Signal.palette.inkMuted
                }

                StyledRect {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    color: interfaceNameField.activeFocus ? Signal.layer(Signal.palette.panel, 3) : Signal.layer(Signal.palette.panel, 2)
                    radius: Appearance.rounding.small
                    border.width: 1
                    border.color: interfaceNameField.activeFocus ? Signal.palette.signal : Qt.alpha(Signal.palette.ruleStrong, 0.3)

                    Behavior on color {
                        CAnim {}
                    }
                    Behavior on border.color {
                        CAnim {}
                    }

                    StyledTextField {
                        id: interfaceNameField
                        anchors.centerIn: parent
                        width: parent.width - Appearance.padding.normal
                        horizontalAlignment: TextInput.AlignLeft
                        text: editVpnDialog.interfaceName
                        onTextChanged: editVpnDialog.interfaceName = text
                    }
                }
            }

            RowLayout {
                Layout.topMargin: Appearance.spacing.normal
                Layout.fillWidth: true
                spacing: Appearance.spacing.normal

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("Cancel")
                    inactiveColour: Signal.tPalette.raised
                    inactiveOnColour: Signal.palette.ink
                    onClicked: editVpnDialog.closeWithAnimation()
                }

                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("Save")
                    enabled: editVpnDialog.interfaceName.length > 0
                    inactiveColour: Signal.palette.signalWell
                    inactiveOnColour: Signal.palette.onSignalWell

                    onClicked: {
                        const providers = [];
                        const oldProvider = Config.utilities.vpn.provider[editVpnDialog.editIndex];
                        const wasEnabled = typeof oldProvider === "object" ? (oldProvider.enabled !== false) : true;

                        for (let i = 0; i < Config.utilities.vpn.provider.length; i++) {
                            if (i === editVpnDialog.editIndex) {
                                providers.push({
                                    name: editVpnDialog.providerName,
                                    displayName: editVpnDialog.displayName || editVpnDialog.interfaceName,
                                    interface: editVpnDialog.interfaceName,
                                    enabled: wasEnabled
                                });
                            } else {
                                providers.push(Config.utilities.vpn.provider[i]);
                            }
                        }

                        Config.utilities.vpn.provider = providers;
                        Config.save();
                        editVpnDialog.closeWithAnimation();
                    }
                }
            }
        }
    }
}
