pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

DeviceList {
    id: root

    required property Session session

    title: qsTr("Devices (%1)").arg(Nmcli.ethernetDevices.length)
    description: qsTr("All available ethernet devices")
    activeItem: session.ethernet.active

    model: Nmcli.ethernetDevices

    headerComponent: Component {
        RowLayout {
            spacing: Appearance.spacing.smaller

            Eyebrow {
                label: qsTr("Settings")
                color: Signal.palette.ink
            }

            Item {
                Layout.fillWidth: true
            }

            ToggleButton {
                toggled: !root.session.ethernet.active
                icon: "settings"
                accent: "signal"
                iconSize: Appearance.font.size.normal
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.smaller

                onClicked: {
                    if (root.session.ethernet.active)
                        root.session.ethernet.active = null;
                    else {
                        root.session.ethernet.active = root.view.model.get(0)?.modelData ?? null;
                    }
                }
            }
        }
    }

    delegate: Component {
        StyledRect {
            id: ethernetItem

            required property var modelData
            readonly property bool isActive: root.activeItem && modelData && root.activeItem.interface === modelData.interface

            width: ListView.view ? ListView.view.width : undefined
            implicitHeight: rowLayout.implicitHeight + Appearance.padding.normal * 2

            color: ethernetItem.isActive ? Signal.palette.signalWell : "transparent"
            radius: 0

            OnAirBar {
                edge: "left"
                active: ethernetItem.isActive
            }

            Accessible.role: Accessible.Button
            Accessible.name: (modelData.interface || qsTr("Unknown")) + (modelData.connected ? qsTr(", connected") : qsTr(", disconnected"))

            Interactive {
                id: stateLayer

                function onClicked(): void {
                    root.session.ethernet.active = modelData;
                }
            }

            RowLayout {
                id: rowLayout

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal

                spacing: Appearance.spacing.normal

                StyledRect {
                    implicitWidth: implicitHeight
                    implicitHeight: icon.implicitHeight + Appearance.padding.normal * 2

                    radius: Appearance.rounding.small
                    color: modelData.connected ? Signal.palette.signalWell : "transparent"

                    StyledRect {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Qt.alpha(modelData.connected ? Signal.palette.onSignalWell : Signal.palette.ink, stateLayer.pressed ? 0.1 : stateLayer.containsMouse ? 0.08 : 0)
                    }

                    Glyph {
                        id: icon

                        anchors.centerIn: parent
                        name: "plug-connected"
                        font.pointSize: Appearance.font.size.large
                        color: modelData.connected ? Signal.palette.onSignalWell : Signal.palette.ink
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: modelData.interface || qsTr("Unknown")
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Appearance.spacing.smaller

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData.connected ? qsTr("Connected") : qsTr("Disconnected")
                            color: modelData.connected ? Signal.palette.signal : Signal.palette.inkMuted
                            font.pointSize: Appearance.font.size.small
                            font.weight: modelData.connected ? 500 : 400
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledRect {
                    id: connectBtn

                    implicitWidth: implicitHeight
                    implicitHeight: connectIcon.implicitHeight + Appearance.padding.smaller * 2

                    radius: Appearance.rounding.small
                    color: Qt.alpha(Signal.palette.signalWell, modelData.connected ? 1 : 0)

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.connected ? qsTr("Disconnect") : qsTr("Connect")

                    Interactive {
                        color: modelData.connected ? Signal.palette.onSignalWell : Signal.palette.ink

                        function onClicked(): void {
                            if (modelData.connected && modelData.connection) {
                                Nmcli.disconnectEthernet(modelData.connection, () => {});
                            } else {
                                Nmcli.connectEthernet(modelData.connection || "", modelData.interface || "", () => {});
                            }
                        }
                    }

                    Glyph {
                        id: connectIcon

                        anchors.centerIn: parent
                        animate: true
                        name: modelData.connected ? "link-off" : "link"
                        color: modelData.connected ? Signal.palette.onSignalWell : Signal.palette.ink
                    }
                }
            }
        }
    }

    onItemSelected: function (item) {
        session.ethernet.active = item;
    }
}
