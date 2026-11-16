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

    radius: Appearance.rounding.normal
    color: Signal.tPalette.panel

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Appearance.padding.large
        spacing: Appearance.spacing.normal

        StyledText {
            text: qsTr("Quick Toggles")
            font.pointSize: Appearance.font.size.normal
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
                accessibleName: qsTr("Toggle game mode")
                checked: GameMode.enabled
                visible: Compositor.supports("hyprlandTuning")
                onClicked: GameMode.enabled = !GameMode.enabled
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
        Layout.preferredWidth: implicitWidth + (stateLayer.pressed ? Appearance.padding.large : internalChecked ? Appearance.padding.smaller : 0)
        radius: stateLayer.pressed ? Appearance.rounding.small / 2 : internalChecked ? Appearance.rounding.small : Appearance.rounding.normal
        inactiveColour: Signal.layer(Signal.palette.lifted, 2)
        toggle: true
        radiusAnim.duration: Appearance.anim.durations.settleFast
        radiusAnim.easing.bezierCurve: Appearance.anim.curves.settleFast

        Behavior on Layout.preferredWidth {
            Anim {
                duration: Appearance.anim.durations.settleFast
                easing.bezierCurve: Appearance.anim.curves.settleFast
            }
        }
    }
}
