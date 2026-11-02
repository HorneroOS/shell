pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

DeviceList {
    id: root

    required property Session session
    readonly property bool smallDiscoverable: width <= 540
    readonly property bool smallPairable: width <= 480

    title: qsTr("Devices (%1)").arg(Bluetooth.devices.values.length)
    description: qsTr("All available bluetooth devices")
    activeItem: session.bt.active

    model: ScriptModel {
        id: deviceModel

        values: [...Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || a.address || "").localeCompare(b.name || b.address || ""))
        onValuesChanged: root.session.bt.pruneStaleActive()
    }

    headerComponent: Component {
        RowLayout {
            spacing: Appearance.spacing.smaller

            StyledText {
                text: qsTr("Bluetooth")
                font.pointSize: Appearance.font.size.large
                font.weight: 500
            }

            Item {
                Layout.fillWidth: true
            }

            ToggleButton {
                toggled: root.session.bt.effectiveAdapter?.enabled ?? false
                icon: "power"
                accent: "Tertiary"
                iconSize: Appearance.font.size.normal
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.smaller
                tooltip: qsTr("Toggle Bluetooth")

                onClicked: root.session.bt.setPowered(!toggled)
            }

            ToggleButton {
                toggled: root.session.bt.effectiveAdapter?.discoverable ?? false
                icon: root.smallDiscoverable ? "group_search" : ""
                label: root.smallDiscoverable ? "" : qsTr("Discoverable")
                iconSize: Appearance.font.size.normal
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.smaller
                tooltip: qsTr("Make discoverable")

                onClicked: {
                    const adapter = root.session.bt.effectiveAdapter;
                    if (adapter) {
                        adapter.discoverableTimeout = 120;
                        adapter.discoverable = !adapter.discoverable;
                    }
                }
            }

            ToggleButton {
                toggled: root.session.bt.effectiveAdapter?.pairable ?? false
                icon: "missing_controller"
                label: root.smallPairable ? "" : qsTr("Pairable")
                iconSize: Appearance.font.size.normal
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.smaller
                tooltip: qsTr("Make pairable")

                onClicked: {
                    const adapter = root.session.bt.effectiveAdapter;
                    if (adapter) {
                        adapter.pairableTimeout = 120;
                        adapter.pairable = !adapter.pairable;
                    }
                }
            }

            ToggleButton {
                toggled: root.session.bt.effectiveAdapter?.discovering ?? false
                icon: "bluetooth_searching"
                accent: "Secondary"
                iconSize: Appearance.font.size.normal
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.smaller
                tooltip: qsTr("Scan for devices")

                onClicked: {
                    if (toggled)
                        root.session.bt.stopDiscoveryIfOwned();
                    else
                        root.session.bt.startDiscovery();
                }
            }

            ToggleButton {
                toggled: !root.session.bt.active
                icon: "settings"
                accent: "Primary"
                iconSize: Appearance.font.size.normal
                horizontalPadding: Appearance.padding.normal
                verticalPadding: Appearance.padding.smaller
                tooltip: qsTr("Bluetooth settings")

                onClicked: {
                    if (root.session.bt.active)
                        root.session.bt.active = null;
                    else {
                        root.session.bt.active = root.model.values[0] ?? null;
                    }
                }
            }
        }
    }

    delegate: Component {
        StyledRect {
            id: device

            required property BluetoothDevice modelData
            readonly property bool loading: modelData && (modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting)
            readonly property bool connected: modelData && modelData.state === BluetoothDeviceState.Connected

            width: ListView.view ? ListView.view.width : undefined
            implicitHeight: deviceInner.implicitHeight + Appearance.padding.normal * 2

            color: Qt.alpha(Colours.tPalette.m3surfaceContainer, root.activeItem === modelData ? Colours.tPalette.m3surfaceContainer.a : 0)
            radius: Appearance.rounding.normal

            Accessible.role: Accessible.Button
            Accessible.name: (modelData ? modelData.name : qsTr("Unknown")) + (device.connected ? qsTr(", connected") : "")

            Interactive {
                id: stateLayer

                function onClicked(): void {
                    if (device.modelData)
                        root.session.bt.active = device.modelData;
                }
            }

            RowLayout {
                id: deviceInner

                anchors.fill: parent
                anchors.margins: Appearance.padding.normal

                spacing: Appearance.spacing.normal

                StyledRect {
                    implicitWidth: implicitHeight
                    implicitHeight: icon.implicitHeight + Appearance.padding.normal * 2

                    radius: Appearance.rounding.normal
                    color: device.connected ? Colours.palette.m3primaryContainer : (device.modelData && device.modelData.bonded) ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainerHigh

                    StyledRect {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Qt.alpha(device.connected ? Colours.palette.m3onPrimaryContainer : (device.modelData && device.modelData.bonded) ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface, stateLayer.pressed ? 0.1 : stateLayer.containsMouse ? 0.08 : 0)
                    }

                    MaterialIcon {
                        id: icon

                        anchors.centerIn: parent
                        text: Icons.getBluetoothIcon(device.modelData ? device.modelData.icon : "")
                        color: device.connected ? Colours.palette.m3onPrimaryContainer : (device.modelData && device.modelData.bonded) ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        font.pointSize: Appearance.font.size.large
                        fill: device.connected ? 1 : 0

                        Behavior on fill {
                            Anim {}
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true

                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: device.modelData ? (device.modelData.name || device.modelData.address || qsTr("Unknown")) : qsTr("Unknown")
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: (device.modelData ? device.modelData.address : "") + (device.connected ? qsTr(" (Connected)") : (device.modelData && device.modelData.bonded) ? qsTr(" (Paired)") : "")
                        color: Colours.palette.m3outline
                        font.pointSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }
                }

                StyledRect {
                    id: connectBtn

                    implicitWidth: implicitHeight
                    implicitHeight: connectIcon.implicitHeight + Appearance.padding.smaller * 2

                    radius: Appearance.rounding.full
                    color: Qt.alpha(Colours.palette.m3primaryContainer, device.connected ? 1 : 0)

                    CircularIndicator {
                        anchors.fill: parent
                        running: device.loading
                    }

                    Interactive {
                        color: device.connected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        disabled: device.loading

                        function onClicked(): void {
                            if (device.loading)
                                return;

                            if (device.connected)
                                root.session.bt.disconnectDevice(device.modelData);
                            else
                                root.session.bt.connectDevice(device.modelData);
                        }
                    }

                    MaterialIcon {
                        id: connectIcon

                        anchors.centerIn: parent
                        animate: true
                        text: device.connected ? "link_off" : "link"
                        color: device.connected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface

                        opacity: device.loading ? 0 : 1

                        Behavior on opacity {
                            Anim {}
                        }
                    }
                }
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: !root.session.bt.hasAdapter
        wrapMode: Text.WordWrap
        text: qsTr("No Bluetooth adapter found. The Bluetooth service may be stopped, or this machine has no Bluetooth hardware.")
        color: Colours.palette.m3outline
    }

    TextButton {
        visible: !root.session.bt.hasAdapter
        inactiveColour: Colours.palette.m3secondaryContainer
        inactiveOnColour: Colours.palette.m3onSecondaryContainer
        text: qsTr("Restart Bluetooth service")

        onClicked: root.session.bt.restartService()
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.session.bt.hasAdapter && !root.session.bt.adapterPowered
        wrapMode: Text.WordWrap
        text: qsTr("Bluetooth is off. Turn it on to find nearby devices.")
        color: Colours.palette.m3outline
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.session.bt.hasAdapter && root.session.bt.adapterPowered && Bluetooth.devices.values.length === 0
        wrapMode: Text.WordWrap
        text: qsTr("No devices found. Use Scan to look for nearby devices.")
        color: Colours.palette.m3outline
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.session.bt.lastError !== ""
        wrapMode: Text.WordWrap
        text: root.session.bt.lastError
        color: Colours.palette.m3error
    }

    TextButton {
        visible: root.session.bt.lastError !== ""
        inactiveColour: Colours.palette.m3secondaryContainer
        inactiveOnColour: Colours.palette.m3onSecondaryContainer
        text: qsTr("Dismiss")

        onClicked: root.session.bt.clearError()
    }

    onItemSelected: item => session.bt.active = item
}
