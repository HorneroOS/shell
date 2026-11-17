import qs.components
import qs.components.controls
import qs.services
import qs.config
import qs.modules.controlcenter
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property var visibilities
    required property Item popouts

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Appearance.padding.large * 2

    radius: Appearance.rounding.small
    color: Signal.palette.panel
    border.width: 1
    border.color: Signal.palette.rule

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        StyledText {
            text: qsTr("Quick toggles")
            font.family: Appearance.font.family.mono
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Appearance.font.size.small * 0.08
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Appearance.spacing.small

            Toggle {
                icon: "wifi"
                accessibleName: qsTr("Toggle Wi-Fi")
                checked: Network.wifiEnabled
                onClicked: Network.toggleWifi()
            }

            Toggle {
                icon: "bluetooth"
                accessibleName: qsTr("Toggle Bluetooth")
                checked: Bluetooth.defaultAdapter?.enabled ?? false
                onClicked: {
                    const adapter = Bluetooth.defaultAdapter;
                    if (adapter)
                        adapter.enabled = !adapter.enabled;
                }
            }

            Toggle {
                icon: "microphone"
                accessibleName: qsTr("Toggle microphone")
                checked: !Audio.sourceMuted
                onClicked: {
                    const audio = Audio.source?.audio;
                    if (audio)
                        audio.muted = !audio.muted;
                }
            }

            Toggle {
                icon: "settings"
                accessibleName: qsTr("Open network settings")
                inactiveOnColour: Signal.palette.inkMuted
                toggle: false
                onClicked: {
                    root.visibilities.utilities = false;
                    root.popouts.detach("network");
                }
            }

            Toggle {
                icon: "device-gamepad"
                accessibleName: qsTr("Toggle gaming mode")
                checked: Experience.gaming
                onClicked: Experience.toggle("gaming")
            }

            Toggle {
                icon: "bell-off"
                accessibleName: qsTr("Toggle do not disturb")
                checked: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }

            Toggle {
                icon: "key"
                accessibleName: qsTr("Toggle VPN")
                checked: VPN.connected
                enabled: !VPN.connecting
                visible: Config.utilities.vpn.provider.some(p => typeof p === "object" ? (p.enabled === true) : false)
                onClicked: VPN.toggle()
            }
        }
    }

    component Toggle: IconButton {
        Layout.fillWidth: true
        // Fixed cell: pressed and checked change fill, never size or radius.
        radius: Appearance.rounding.small
        inactiveColour: Signal.palette.lifted
        toggle: true
    }
}
