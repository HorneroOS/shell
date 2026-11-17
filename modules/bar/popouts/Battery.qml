pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell.Services.UPower
import QtQuick

Column {
    id: root

    spacing: Appearance.spacing.normal
    width: Config.bar.sizes.batteryWidth

    // Charge and time left as a gauge (see BatteryGauge.qml).
    BatteryGauge {
        visible: UPower.displayDevice.isLaptopBattery
        width: parent.width
    }

    StyledText {
        visible: !UPower.displayDevice.isLaptopBattery
        text: qsTr("No battery detected · Power profile: %1").arg(PowerProfile.toString(PowerProfiles.profile))
        color: Signal.palette.inkMuted
    }

    Loader {
        anchors.horizontalCenter: parent.horizontalCenter

        active: PowerProfiles.degradationReason !== PerformanceDegradationReason.None

        height: active ? (item?.implicitHeight ?? 0) : 0

        sourceComponent: StyledRect {
            implicitWidth: child.implicitWidth + Appearance.padding.normal * 2
            implicitHeight: child.implicitHeight + Appearance.padding.smaller * 2

            color: Signal.palette.alert
            radius: Appearance.rounding.small

            Column {
                id: child

                anchors.centerIn: parent

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Appearance.spacing.small

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -font.pointSize / 10

                        name: "alert-triangle"
                        color: Signal.palette.onAlert
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Performance Degraded")
                        color: Signal.palette.onAlert
                        font.family: Appearance.font.family.mono
                        font.weight: 500
                    }

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -font.pointSize / 10

                        name: "alert-triangle"
                        color: Signal.palette.onAlert
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: qsTr("Reason: %1").arg(PerformanceDegradationReason.toString(PowerProfiles.degradationReason))
                    color: Signal.palette.onAlert
                }
            }
        }
    }

    StyledRect {
        id: profiles

        property string current: {
            const p = PowerProfiles.profile;
            if (p === PowerProfile.PowerSaver)
                return saver.icon;
            if (p === PowerProfile.Performance)
                return perf.icon;
            return balance.icon;
        }

        anchors.horizontalCenter: parent.horizontalCenter

        implicitWidth: saver.implicitHeight + balance.implicitHeight + perf.implicitHeight + Appearance.padding.normal * 2 + Appearance.spacing.large * 2
        implicitHeight: Math.max(saver.implicitHeight, balance.implicitHeight, perf.implicitHeight) + Appearance.padding.small * 2

        color: Signal.tPalette.panel
        radius: Appearance.rounding.small

        StyledRect {
            id: indicator

            color: Signal.palette.signal
            radius: Appearance.rounding.small
            state: profiles.current

            states: [
                State {
                    name: saver.icon

                    Fill {
                        item: saver
                    }
                },
                State {
                    name: balance.icon

                    Fill {
                        item: balance
                    }
                },
                State {
                    name: perf.icon

                    Fill {
                        item: perf
                    }
                }
            ]

            transitions: Transition {
                AnchorAnimation {
                    duration: Appearance.anim.durations.medium
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.curves.standard
                }
            }
        }

        Profile {
            id: saver

            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.small

            profile: PowerProfile.PowerSaver
            icon: "leaf"
        }

        Profile {
            id: balance

            anchors.centerIn: parent

            profile: PowerProfile.Balanced
            icon: "scale"
        }

        Profile {
            id: perf

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.small

            profile: PowerProfile.Performance
            icon: "rocket"
        }
    }

    component Fill: AnchorChanges {
        required property Item item

        target: indicator
        anchors.left: item.left
        anchors.right: item.right
        anchors.top: item.top
        anchors.bottom: item.bottom
    }

    component Profile: Item {
        required property string icon
        required property int profile

        implicitWidth: icon.implicitHeight + Appearance.padding.small * 2
        implicitHeight: icon.implicitHeight + Appearance.padding.small * 2

        StateLayer {
            radius: Appearance.rounding.small
            color: profiles.current === parent.icon ? Signal.palette.onSignal : Signal.palette.ink

            function onClicked(): void {
                PowerProfiles.profile = parent.profile;
            }
        }

        Glyph {
            id: icon

            anchors.centerIn: parent

            name: parent.icon
            font.pointSize: Appearance.font.size.large
            color: profiles.current === text ? Signal.palette.onSignal : Signal.palette.ink
        }
    }
}
