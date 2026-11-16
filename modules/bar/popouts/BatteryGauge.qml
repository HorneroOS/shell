pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import Quickshell.Services.UPower
import QtQuick

// Battery gauge for the bar battery popout: a wide fill "tank" with the
// charge and the time left inside; the label changes colour exactly where
// the fill passes under it, and a sheen runs across the fill while
// charging. Semantic palette colours (secondary / error when low / success
// while charging) instead of fixed greens, so it follows every scheme.
//
// Design inspired by ItsXyzzy/caelestia-material-battery (GPL-3.0,
// https://github.com/ItsXyzzy/caelestia-material-battery): two layered
// copies of the content, the top one clipped to the fill. Hornero
// implementation on Appearance tokens.
Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool charging: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(root.device.state)
    readonly property real level: Math.max(0, Math.min(1, root.device.percentage))
    readonly property bool low: !root.charging && root.level <= 0.2
    readonly property bool reducedMotion: Appearance.anim.reduced || Appearance.anim.durations.scale <= 0

    readonly property color fillColour: root.charging ? Signal.palette.phosphor : root.low ? Signal.palette.alert : Signal.palette.cue
    readonly property color trackColour: root.charging ? Qt.alpha(Signal.palette.phosphor, 0.22) : root.low ? Qt.alpha(Signal.palette.alert, 0.22) : Signal.palette.cueWell
    readonly property color onTrack: Signal.palette.ink
    readonly property color onFill: Signal.on(root.fillColour)

    readonly property string timeLabel: {
        if (root.charging && Math.round(root.level * 100) >= 100)
            return qsTr("Fully charged");
        const secs = UPower.onBattery ? root.device.timeToEmpty : root.device.timeToFull;
        if (!(secs > 0))
            return UPower.onBattery ? qsTr("Estimating time left…") : qsTr("Charging");
        const h = Math.floor(secs / 3600);
        const m = Math.floor(secs / 60) % 60;
        const dur = h > 0 ? (m > 0 ? qsTr("%1h %2m").arg(h).arg(m) : qsTr("%1h").arg(h)) : qsTr("%1m").arg(Math.max(1, m));
        return UPower.onBattery ? qsTr("%1 left").arg(dur) : qsTr("%1 to full").arg(dur);
    }

    property real shownLevel: root.level

    implicitHeight: 104
    implicitWidth: Config.bar.sizes.batteryWidth

    Accessible.role: Accessible.ProgressBar
    Accessible.name: qsTr("Battery %1%, %2").arg(Math.round(root.level * 100)).arg(root.timeLabel)

    Behavior on shownLevel {
        Anim {}
    }

    component Contents: Item {
        id: contents

        required property color textColour

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Row {
                spacing: Appearance.spacing.small

                StyledText {
                    text: Math.round(root.level * 100) + "%"
                    font.pointSize: Appearance.font.size.extraLarge
                    font.weight: 600
                    color: contents.textColour
                }

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.charging
                    name: "bolt"
                    font.pointSize: Appearance.font.size.large
                    color: contents.textColour
                }
            }

            StyledText {
                text: root.timeLabel
                font.pointSize: Appearance.font.size.smaller
                color: contents.textColour
            }
        }
    }

    StyledRect {
        id: tank

        anchors.fill: parent
        radius: Appearance.rounding.large
        color: root.trackColour
        clip: true

        Behavior on color {
            CAnim {}
        }

        Contents {
            id: trackContents

            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            textColour: root.onTrack
        }

        Rectangle {
            id: fill

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: tank.width * root.shownLevel
            radius: Appearance.rounding.small
            color: root.fillColour
            clip: true

            Behavior on color {
                CAnim {}
            }

            // Same content, clipped to the fill: the label changes colour
            // exactly at the fill edge.
            Contents {
                x: trackContents.x
                y: trackContents.y
                width: trackContents.width
                height: trackContents.height
                textColour: root.onFill
            }

            Rectangle {
                id: sheen

                visible: root.charging && !root.reducedMotion
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.max(24, fill.width * 0.35)
                x: -width

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: Qt.alpha(root.onFill, 0)
                    }
                    GradientStop {
                        position: 0.5
                        color: Qt.alpha(root.onFill, 0.18)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.alpha(root.onFill, 0)
                    }
                }

                SequentialAnimation {
                    running: sheen.visible
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: sheen
                        property: "x"
                        from: -sheen.width
                        to: fill.width
                        duration: Appearance.anim.durations.scan * 2
                        easing.type: Easing.InOutQuad
                    }
                    PauseAnimation {
                        duration: Appearance.anim.durations.scan
                    }
                }
            }
        }
    }
}
