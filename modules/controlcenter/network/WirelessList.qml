pragma ComponentBehavior: Bound

import ".."
import "../components"
import "."
import qs.components
import qs.components.controls
import qs.components.containers
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell
import QtQuick
import QtQuick.Layouts

DeviceList {
    id: root

    required property Session session

    title: qsTr("Networks (%1)").arg(Nmcli.networks.length)
    description: qsTr("All available WiFi networks")
    activeItem: session.network.active

    titleSuffix: Component {
        StyledText {
            visible: Nmcli.scanning
            text: qsTr("Scanning...")
            color: Signal.palette.signal
            font.pointSize: Appearance.font.size.small
        }
    }

    model: ScriptModel {
        values: [...Nmcli.networks].sort((a, b) => {
            if (a.active !== b.active)
                return b.active - a.active;
            return b.strength - a.strength;
        })
    }

    headerComponent: Component {
        RowLayout {
            spacing: Appearance.spacing.smaller

            StyledText {
                text: qsTr("Settings")
                font.pointSize: Appearance.font.size.large
                font.weight: 500
            }

            Item {
                Layout.fillWidth: true
            }

            ToggleButton {
                toggled: Nmcli.wifiEnabled
                icon: "wifi"
                accent: "phosphor"
                iconSize: Appearance.font.size.normal
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.smaller

                onClicked: {
                    Nmcli.toggleWifi(null);
                }
            }

            ToggleButton {
                toggled: Nmcli.scanning
                icon: "wifi"
                accent: "cue"
                iconSize: Appearance.font.size.normal
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.smaller

                onClicked: {
                    Nmcli.rescanWifi();
                }
            }

            ToggleButton {
                toggled: !root.session.network.active
                icon: "settings"
                accent: "signal"
                iconSize: Appearance.font.size.normal
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.smaller

                onClicked: {
                    if (root.session.network.active)
                        root.session.network.active = null;
                    else {
                        root.session.network.active = root.view.model.get(0)?.modelData ?? null;
                    }
                }
            }
        }
    }

    delegate: Component {
        StyledRect {
            required property var modelData

            width: ListView.view ? ListView.view.width : undefined

            color: Qt.alpha(Signal.tPalette.panel, root.activeItem === modelData ? Signal.tPalette.panel.a : 0)
            radius: Appearance.rounding.small

            Accessible.role: Accessible.Button
            Accessible.name: (modelData.ssid || qsTr("Unknown")) + (modelData.active ? qsTr(", connected") : "")

            Interactive {
                function onClicked(): void {
                    root.session.network.active = modelData;
                    if (modelData && modelData.ssid) {
                        root.checkSavedProfileForNetwork(modelData.ssid);
                    }
                }
            }

            RowLayout {
                id: rowLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Appearance.padding.normal

                spacing: Appearance.spacing.normal

                StyledRect {
                    implicitWidth: implicitHeight
                    implicitHeight: icon.implicitHeight + Appearance.padding.normal * 2

                    radius: Appearance.rounding.small
                    color: modelData.active ? Signal.palette.signalWell : Signal.tPalette.raised

                    Glyph {
                        id: icon

                        anchors.centerIn: parent
                        name: Icons.getNetworkIcon(modelData.strength, modelData.isSecure)
                        font.pointSize: Appearance.font.size.large
                        color: modelData.active ? Signal.palette.onSignalWell : Signal.palette.ink
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        maximumLineCount: 1

                        text: modelData.ssid || qsTr("Unknown")
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.smaller

                        StyledText {
                            Layout.fillWidth: true
                            text: {
                                if (modelData.active)
                                    return qsTr("Connected");
                                if (modelData.isSecure && modelData.security && modelData.security.length > 0) {
                                    return modelData.security;
                                }
                                if (modelData.isSecure)
                                    return qsTr("Secured");
                                return qsTr("Open");
                            }
                            color: modelData.active ? Signal.palette.signal : Signal.palette.ruleStrong
                            font.pointSize: Appearance.font.size.small
                            font.weight: modelData.active ? 500 : 400
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledRect {
                    implicitWidth: implicitHeight
                    implicitHeight: connectIcon.implicitHeight + Appearance.padding.smaller * 2

                    radius: Appearance.rounding.small
                    color: Qt.alpha(Signal.palette.signalWell, modelData.active ? 1 : 0)

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.active ? qsTr("Disconnect") : qsTr("Connect")

                    Interactive {
                        function onClicked(): void {
                            if (modelData.active) {
                                Nmcli.disconnectFromNetwork();
                            } else {
                                NetworkConnection.handleConnect(modelData, root.session, null);
                            }
                        }
                    }

                    Glyph {
                        id: connectIcon

                        anchors.centerIn: parent
                        name: modelData.active ? "link-off" : "link"
                        color: modelData.active ? Signal.palette.onSignalWell : Signal.palette.ink
                    }
                }
            }

            implicitHeight: rowLayout.implicitHeight + Appearance.padding.normal * 2
        }
    }

    onItemSelected: function (item) {
        session.network.active = item;
        if (item && item.ssid) {
            checkSavedProfileForNetwork(item.ssid);
        }
    }

    function checkSavedProfileForNetwork(ssid: string): void {
        if (ssid && ssid.length > 0) {
            Nmcli.loadSavedConnections(() => {});
        }
    }
}
