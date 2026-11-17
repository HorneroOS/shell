pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: root

    height: implicitHeight

    required property Session session

    spacing: Appearance.spacing.normal

    SettingsHeader {
        icon: "key"
        title: qsTr("VPN Settings")
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("General")
        description: qsTr("VPN configuration")
    }

    SectionContainer {
        ToggleRow {
            label: qsTr("VPN enabled")
            checked: Config.utilities.vpn.enabled
            toggle.onToggled: {
                Config.utilities.vpn.enabled = checked;
                Config.save();
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Providers")
        description: qsTr("Manage VPN providers")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: contentHeight

            interactive: false
            spacing: Appearance.spacing.smaller

            model: ScriptModel {
                values: Config.utilities.vpn.provider.map((provider, index) => {
                    const isObject = typeof provider === "object";
                    const name = isObject ? (provider.name || "custom") : String(provider);
                    const displayName = isObject ? (provider.displayName || name) : name;
                    const iface = isObject ? (provider.interface || "") : "";

                    return {
                        index: index,
                        name: name,
                        displayName: displayName,
                        interface: iface,
                        provider: provider,
                        isActive: index === 0
                    };
                })
            }

            delegate: Component {
                StyledRect {
                    required property var modelData
                    required property int index

                    width: ListView.view ? ListView.view.width : undefined
                    color: "transparent"
                    border.width: 1
                    border.color: Signal.palette.rule
                    radius: Appearance.rounding.small

                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Appearance.padding.normal
                        spacing: Appearance.spacing.normal

                        Glyph {
                            name: modelData.isActive ? "key" : "key-off"
                            font.pointSize: Appearance.font.size.large
                            color: modelData.isActive ? Signal.palette.signal : Signal.palette.ruleStrong
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: modelData.displayName
                                font.weight: modelData.isActive ? 500 : 400
                            }

                            StyledText {
                                text: qsTr("%1 • %2").arg(modelData.name).arg(modelData.interface || qsTr("No interface"))
                                font.pointSize: Appearance.font.size.small
                                color: Signal.palette.inkMuted
                            }
                        }

                        IconButton {
                            icon: modelData.isActive ? "arrow-down" : "arrow-up"
                            accessibleName: modelData.isActive ? qsTr("Move VPN provider down") : qsTr("Move VPN provider up")
                            visible: !modelData.isActive || Config.utilities.vpn.provider.length > 1
                            onClicked: {
                                if (modelData.isActive && index < Config.utilities.vpn.provider.length - 1) {
                                    // Move down
                                    const providers = [...Config.utilities.vpn.provider];
                                    const temp = providers[index];
                                    providers[index] = providers[index + 1];
                                    providers[index + 1] = temp;
                                    Config.utilities.vpn.provider = providers;
                                    Config.save();
                                } else if (!modelData.isActive) {
                                    // Make active (move to top)
                                    const providers = [...Config.utilities.vpn.provider];
                                    const provider = providers.splice(index, 1)[0];
                                    providers.unshift(provider);
                                    Config.utilities.vpn.provider = providers;
                                    Config.save();
                                }
                            }
                        }

                        IconButton {
                            icon: "trash"
                            accessibleName: qsTr("Remove VPN provider")
                            onClicked: {
                                const providers = [...Config.utilities.vpn.provider];
                                providers.splice(index, 1);
                                Config.utilities.vpn.provider = providers;
                                Config.save();
                            }
                        }
                    }

                    implicitHeight: 60
                }
            }
        }

        TextButton {
            Layout.fillWidth: true
            Layout.topMargin: Appearance.spacing.normal
            text: qsTr("+ Add Provider")
            inactiveColour: Signal.palette.signalWell
            inactiveOnColour: Signal.palette.onSignalWell

            onClicked: {
                addProviderDialog.open();
            }
        }
    }

    SectionHeader {
        Layout.topMargin: Appearance.spacing.large
        title: qsTr("Quick Add")
        description: qsTr("Add common VPN providers")
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.smaller

        TextButton {
            Layout.fillWidth: true
            text: qsTr("+ Add NetBird")
            inactiveColour: Signal.tPalette.raised
            inactiveOnColour: Signal.palette.ink

            onClicked: {
                const providers = [...Config.utilities.vpn.provider];
                providers.push({
                    name: "netbird",
                    displayName: "NetBird",
                    interface: "wt0"
                });
                Config.utilities.vpn.provider = providers;
                Config.save();
            }
        }

        TextButton {
            Layout.fillWidth: true
            text: qsTr("+ Add Tailscale")
            inactiveColour: Signal.tPalette.raised
            inactiveOnColour: Signal.palette.ink

            onClicked: {
                const providers = [...Config.utilities.vpn.provider];
                providers.push({
                    name: "tailscale",
                    displayName: "Tailscale",
                    interface: "tailscale0"
                });
                Config.utilities.vpn.provider = providers;
                Config.save();
            }
        }

        TextButton {
            Layout.fillWidth: true
            text: qsTr("+ Add Cloudflare WARP")
            inactiveColour: Signal.tPalette.raised
            inactiveOnColour: Signal.palette.ink

            onClicked: {
                const providers = [...Config.utilities.vpn.provider];
                providers.push({
                    name: "warp",
                    displayName: "Cloudflare WARP",
                    interface: "CloudflareWARP"
                });
                Config.utilities.vpn.provider = providers;
                Config.save();
            }
        }
    }
}
