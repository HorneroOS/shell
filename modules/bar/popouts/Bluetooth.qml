pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts
import "../../controlcenter/network"

ColumnLayout {
    id: root

    required property Item wrapper
    readonly property var adapter: Bluetooth.defaultAdapter ?? null
    readonly property bool hasAdapter: adapter !== null
    readonly property string deviceStatus: {
        if (!root.hasAdapter)
            return qsTr("No Bluetooth adapter found");
        if (!root.adapter.enabled)
            return qsTr("Turn on Bluetooth to find nearby devices");
        if (root.adapter.discovering)
            return qsTr("Looking for nearby devices…");
        const devices = Bluetooth.devices.values;
        if (devices.length > 0) {
            let available = qsTr("%1 device%2 available").arg(devices.length).arg(devices.length === 1 ? "" : "s");
            const connected = devices.filter(d => d.connected).length;
            if (connected > 0)
                available += qsTr(" (%1 connected)").arg(connected);
            return available;
        }
        return qsTr("No nearby devices. Turn on Discovering to search.");
    }

    // Rack rhythm: rows inside one popout module sit 8 apart.
    spacing: Appearance.spacing.smaller

    StyledText {
        Layout.topMargin: Appearance.padding.normal
        Layout.rightMargin: Appearance.padding.small
        text: qsTr("Bluetooth")
        font.weight: Appearance.font.weight.medium
    }

    Toggle {
        label: qsTr("Enabled")
        visible: root.hasAdapter
        checked: root.adapter?.enabled ?? false
        toggle.onToggled: {
            if (root.adapter)
                root.adapter.enabled = checked;
        }
    }

    Toggle {
        label: qsTr("Discovering")
        visible: root.hasAdapter
        checked: root.adapter?.discovering ?? false
        toggle.onToggled: {
            if (root.adapter)
                root.adapter.discovering = checked;
        }
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.small
        Layout.fillWidth: true
        Layout.rightMargin: Appearance.padding.small
        text: root.deviceStatus
        color: Signal.palette.inkMuted
        font.pointSize: Appearance.font.size.small
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: ScriptModel {
            values: [...Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name || a.address || "").localeCompare(b.name || b.address || "")).slice(0, 5)
        }

        RowLayout {
            id: device

            required property BluetoothDevice modelData
            readonly property bool loading: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting

            Layout.fillWidth: true
            Layout.rightMargin: Appearance.padding.small
            spacing: Appearance.spacing.small

            opacity: 0
            scale: 0.7

            Component.onCompleted: {
                opacity = 1;
                scale = 1;
            }

            Behavior on opacity {
                Anim {}
            }

            Behavior on scale {
                Anim {}
            }

            Glyph {
                name: Icons.getBluetoothIcon(device.modelData.icon)
            }

            StyledText {
                Layout.leftMargin: Appearance.spacing.small / 2
                Layout.rightMargin: Appearance.spacing.small / 2
                Layout.fillWidth: true
                text: device.modelData.name || device.modelData.address || qsTr("Unknown")
            }

            StyledRect {
                id: connectBtn

                implicitWidth: implicitHeight
                implicitHeight: connectIcon.implicitHeight + Appearance.padding.small

                radius: Appearance.rounding.small
                color: Qt.alpha(Signal.palette.signal, device.modelData.state === BluetoothDeviceState.Connected ? 1 : 0)

                CircularIndicator {
                    anchors.fill: parent
                    running: device.loading
                }

                StateLayer {
                    color: device.modelData.state === BluetoothDeviceState.Connected ? Signal.palette.onSignal : Signal.palette.ink
                    disabled: device.loading

                    function onClicked(): void {
                        // Unbonded devices must pair first; toggling
                        // `connected` directly bypasses pairing (and its
                        // passkey confirmation) in BlueZ.
                        if (device.modelData.state === BluetoothDeviceState.Connected)
                            device.modelData.connected = false;
                        else if (device.modelData.bonded)
                            device.modelData.connected = true;
                        else
                            device.modelData.pair();
                    }
                }

                Glyph {
                    id: connectIcon

                    anchors.centerIn: parent
                    animate: true
                    name: device.modelData.connected ? "link-off" : "link"
                    color: device.modelData.state === BluetoothDeviceState.Connected ? Signal.palette.onSignal : Signal.palette.ink

                    opacity: device.loading ? 0 : 1

                    Behavior on opacity {
                        Anim {}
                    }
                }
            }

            Loader {
                active: device.modelData.bonded
                sourceComponent: Item {
                    implicitWidth: connectBtn.implicitWidth
                    implicitHeight: connectBtn.implicitHeight

                    StateLayer {
                        radius: Appearance.rounding.small

                        function onClicked(): void {
                            device.modelData.forget();
                        }
                    }

                    Glyph {
                        anchors.centerIn: parent
                        name: "trash"
                    }
                }
            }
        }
    }

    IconTextButton {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.normal
        inactiveColour: Signal.palette.signalWell
        inactiveOnColour: Signal.palette.onSignalWell
        verticalPadding: Appearance.padding.small
        text: qsTr("Open settings")
        icon: "settings"

        onClicked: root.wrapper.detach("bluetooth")
    }

    component Toggle: RowLayout {
        required property string label
        property alias checked: toggle.checked
        property alias toggle: toggle

        Layout.fillWidth: true
        Layout.rightMargin: Appearance.padding.small
        spacing: Appearance.spacing.normal

        StyledText {
            Layout.fillWidth: true
            text: parent.label
        }

        StyledSwitch {
            id: toggle
        }
    }
}
