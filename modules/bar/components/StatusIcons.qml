pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.utils
import qs.components.controls
import qs.config
import qs.modules.plugins
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    required property ShellScreen screen

    property color colour: root.tone.ink
    readonly property alias items: iconGrid
    // Orientation of the owning bar (set by Bar.qml); defaults to the
    // primary bar for standalone use.
    property bool vertical: Config.bar.isVerticalFor(screen.name)
    // Clear bars draw no chips: the cluster sits on the wallpaper like the
    // rest of the bar (set by Bar.qml).
    property bool clear: false

    signal popoutRequested(string name, Item anchor)

    color: clear ? "transparent" : Signal.tPalette.panel
    radius: Appearance.rounding.small

    clip: true
    implicitWidth: vertical ? Density.inner : iconGrid.implicitWidth + Appearance.padding.smaller * 2
    implicitHeight: vertical ? iconGrid.implicitHeight + Appearance.padding.smaller * 2 - (Config.bar.status.showLockStatus && Compositor.supports("lockStatus") && !Compositor.capsLock && !Compositor.numLock ? iconGrid.rowSpacing : 0) : Density.inner

    GridLayout {
        id: iconGrid

        anchors.left: root.vertical ? parent.left : undefined
        anchors.right: parent.right
        anchors.top: root.vertical ? undefined : parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.vertical ? 0 : Appearance.padding.normal
        anchors.bottomMargin: root.vertical ? Appearance.padding.normal : 0

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        rowSpacing: Appearance.spacing.smaller / 2
        columnSpacing: Appearance.spacing.smaller / 2

        // Lock keys status
        WrappedLoader {
            name: "lockstatus"
            active: Config.bar.status.showLockStatus && Compositor.supports("lockStatus")

            sourceComponent: GridLayout {
                flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rows: root.vertical ? -1 : 1
                columns: root.vertical ? 1 : -1
                rowSpacing: 0
                columnSpacing: 0

                Item {
                    implicitWidth: root.vertical ? capslockIcon.implicitWidth : (Compositor.capsLock ? capslockIcon.implicitWidth : 0)
                    implicitHeight: root.vertical ? (Compositor.capsLock ? capslockIcon.implicitHeight : 0) : capslockIcon.implicitHeight

                    Glyph {
                        size: Density.iconPt
                        id: capslockIcon

                        anchors.centerIn: parent

                        scale: Compositor.capsLock ? 1 : 0.5
                        opacity: Compositor.capsLock ? 1 : 0

                        name: "letter-case-upper"
                        color: root.colour

                        Behavior on opacity {
                            Anim {}
                        }

                        Behavior on scale {
                            Anim {}
                        }
                    }

                    Behavior on implicitHeight {
                        Anim {}
                    }
                }

                Item {
                    Layout.topMargin: root.vertical && Compositor.capsLock && Compositor.numLock ? iconGrid.rowSpacing : 0
                    Layout.leftMargin: !root.vertical && Compositor.capsLock && Compositor.numLock ? iconGrid.columnSpacing : 0

                    implicitWidth: root.vertical ? numlockIcon.implicitWidth : (Compositor.numLock ? numlockIcon.implicitWidth : 0)
                    implicitHeight: root.vertical ? (Compositor.numLock ? numlockIcon.implicitHeight : 0) : numlockIcon.implicitHeight

                    Glyph {
                        size: Density.iconPt
                        id: numlockIcon

                        anchors.centerIn: parent

                        scale: Compositor.numLock ? 1 : 0.5
                        opacity: Compositor.numLock ? 1 : 0

                        name: "square-number-1"
                        color: root.colour

                        Behavior on opacity {
                            Anim {}
                        }

                        Behavior on scale {
                            Anim {}
                        }
                    }

                    Behavior on implicitHeight {
                        Anim {}
                    }
                }
            }
        }

        // Niri exposes portal screencast sessions through its event stream.
        // Keep the indicator generic: do not reveal the captured target or
        // the application that opened the session.
        Item {
            id: screencastIndicator

            visible: Compositor.hasScreencastSession
            implicitWidth: visible ? icon.implicitWidth : 0
            implicitHeight: visible ? icon.implicitHeight : 0
            Layout.alignment: Qt.AlignCenter

            Accessible.role: Accessible.StaticText
            Accessible.name: Compositor.hasActiveScreencast
                ? qsTr("Screen capture is active")
                : qsTr("Screen capture session is paused")

            Glyph {
                size: Density.iconPt
                id: icon

                anchors.centerIn: parent
                name: "video"
                color: Compositor.hasActiveScreencast
                    ? root.tone.alert
                    : root.tone.inkMuted
                Accessible.ignored: true
            }

            Tooltip {
                target: screencastIndicator
                text: Compositor.hasActiveScreencast
                    ? qsTr("A screen capture is active")
                    : qsTr("A screen capture session is paused")
            }
        }

        // Audio icon
        PopoutTrigger {
            name: "audio"
            accessibleLabel: qsTr("Volume controls")
            active: Config.bar.status.showAudio

            sourceComponent: Glyph {
                size: Density.iconPt
                animate: true
                name: Icons.getVolumeIcon(Audio.volume, Audio.muted)
                color: root.colour
            }
        }

        // Microphone icon
        PopoutTrigger {
            name: "audio"
            accessibleLabel: qsTr("Microphone controls")
            active: Config.bar.status.showMicrophone

            sourceComponent: Glyph {
                size: Density.iconPt
                animate: true
                name: Icons.getMicVolumeIcon(Audio.sourceVolume, Audio.sourceMuted)
                color: root.colour
            }
        }

        // Keyboard layout icon
        PopoutTrigger {
            name: "kblayout"
            accessibleLabel: qsTr("Keyboard layout controls")
            active: Config.bar.status.showKbLayout && Compositor.supports("keyboardLayoutSwitch")

            sourceComponent: StyledText {
                font.pointSize: Density.textPt
                animate: true
                text: Compositor.keyboardLayoutShort
                color: root.colour
                font.family: Appearance.font.family.mono
            }
        }

        // Network icon
        PopoutTrigger {
            name: "network"
            accessibleLabel: qsTr("Network controls")
            active: Config.bar.status.showNetwork && (!Nmcli.activeEthernet || Config.bar.status.showWifi)

            sourceComponent: Glyph {
                size: Density.iconPt
                animate: true
                name: Nmcli.active ? Icons.getNetworkIcon(Nmcli.active.strength ?? 0) : "wifi-off"
                color: root.colour
            }
        }

        // Ethernet icon
        PopoutTrigger {
            name: "ethernet"
            accessibleLabel: qsTr("Ethernet controls")
            active: Config.bar.status.showNetwork && Nmcli.activeEthernet

            sourceComponent: Glyph {
                size: Density.iconPt
                animate: true
                name: "plug-connected"
                color: root.colour
            }
        }

        // Bluetooth section
        PopoutTrigger {
            Layout.preferredHeight: root.vertical ? implicitHeight : -1
            Layout.preferredWidth: root.vertical ? -1 : implicitWidth

            name: "bluetooth"
            accessibleLabel: qsTr("Bluetooth controls")
            active: Config.bar.status.showBluetooth

            sourceComponent: GridLayout {
                flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
                rows: root.vertical ? -1 : 1
                columns: root.vertical ? 1 : -1
                rowSpacing: Appearance.spacing.smaller / 2
                columnSpacing: Appearance.spacing.smaller / 2

                // Bluetooth icon
                Glyph {
                    size: Density.iconPt
                    animate: true
                    name: {
                        if (!Bluetooth.defaultAdapter?.enabled)
                            return "bluetooth-off";
                        if (Bluetooth.devices.values.some(d => d.connected))
                            return "bluetooth-connected";
                        return "bluetooth";
                    }
                    color: root.colour
                }

                // Connected bluetooth devices
                Repeater {
                    model: ScriptModel {
                        values: Bluetooth.devices.values.filter(d => d.state !== BluetoothDeviceState.Disconnected)
                    }

                    Glyph {
                        size: Density.iconPt
                        id: device

                        required property BluetoothDevice modelData

                        animate: true
                        name: Icons.getBluetoothIcon(modelData?.icon)
                        color: root.colour

                        SequentialAnimation on opacity {
                            running: device.modelData?.state !== BluetoothDeviceState.Connected
                            alwaysRunToEnd: true
                            loops: Animation.Infinite

                            Anim {
                                from: 1
                                to: 0
                                duration: Appearance.anim.durations.long
                                easing.bezierCurve: Appearance.anim.curves.exit
                            }
                            Anim {
                                from: 0
                                to: 1
                                duration: Appearance.anim.durations.long
                                easing.bezierCurve: Appearance.anim.curves.enter
                            }
                        }
                    }
                }
            }

            Behavior on Layout.preferredHeight {
                Anim {}
            }
        }

        // Battery icon
        PopoutTrigger {
            name: "battery"
            accessibleLabel: qsTr("Power controls")
            active: Config.bar.status.showBattery

            sourceComponent: Glyph {
                size: Density.iconPt
                animate: true
                name: {
                    if (!UPower.displayDevice.isLaptopBattery) {
                        if (PowerProfiles.profile === PowerProfile.PowerSaver)
                            return "leaf";
                        if (PowerProfiles.profile === PowerProfile.Performance)
                            return "rocket";
                        return "scale";
                    }

                    const perc = UPower.displayDevice.percentage;
                    const charging = [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state);
                    if (perc === 1)
                        return charging ? "battery-charging" : "battery-4";
                    if (charging)
                        return "battery-charging";
                    return perc > 0.75 ? "battery-4" : perc > 0.5 ? "battery-3" : perc > 0.25 ? "battery-2" : perc > 0.1 ? "battery-1" : "battery";
                }
                color: !UPower.onBattery || UPower.displayDevice.percentage > 0.2 ? root.colour : root.tone.alert
            }
        }

        // Extension indicators that join this island (shell#439): same
        // icon colour and size as the native items around them.
        PluginBarWidgets {
            vertical: root.vertical
            section: "status"
            iconColour: root.colour
            iconSize: Density.iconPt
            textSize: Density.textPt
            thickness: Density.inner
            screenName: root.screen.name
        }
    }

    component WrappedLoader: Loader {
        required property string name

        Layout.alignment: root.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
        visible: active
    }

    // Keep the bar's pointer-driven hit test as the single hover owner while
    // exposing these same popouts to keyboard and assistive technology.
    component PopoutTrigger: WrappedLoader {
        required property string accessibleLabel

        focus: active
        activeFocusOnTab: active
        Accessible.role: Accessible.Button
        Accessible.name: accessibleLabel

        onActiveFocusChanged: {
            if (activeFocus)
                FocusMode.reportFocus(false);
        }

        Keys.onReturnPressed: event => {
            root.popoutRequested(name, this);
            event.accepted = true;
        }
        Keys.onEnterPressed: event => {
            root.popoutRequested(name, this);
            event.accepted = true;
        }
        Keys.onSpacePressed: event => {
            root.popoutRequested(name, this);
            event.accepted = true;
        }

        FocusRing {
            radius: Appearance.rounding.small
        }
    }
}
