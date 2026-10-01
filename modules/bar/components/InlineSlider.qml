pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Layouts

// Inline volume/brightness slider for the bar (horizontal layouts).
// Mirrors the classic Hornero top/bottom bar look: icon + slim slider.
RowLayout {
    id: root

    required property ShellScreen screen
    required property string kind // "audio" | "brightness"
    // Per-entry options: showValue prints the level ("72%") after the slider.
    property var options: ({})
    readonly property bool showValue: options?.showValue === true
    // Set by narrow bars: a shorter track keeps every group on screen.
    property bool compact: false

    readonly property bool isAudio: kind === "audio"
    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(screen)

    spacing: Appearance.spacing.small
    implicitWidth: icon.implicitWidth + spacing + slider.implicitWidth + (showValue ? spacing + valueText.implicitWidth : 0)
    implicitHeight: Math.max(icon.implicitHeight, slider.implicitHeight)

    MaterialIcon {
        id: icon

        Layout.alignment: Qt.AlignVCenter
        text: {
            if (!root.isAudio)
                return "brightness_6";
            if (Audio.muted || Audio.volume === 0)
                return "volume_off";
            return "volume_up";
        }
        color: Colours.palette.m3onSurfaceVariant

        Behavior on text {
            Anim {}
        }
    }

    StyledSlider {
        id: slider

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: root.compact ? 64 : 110
        implicitHeight: Appearance.font.size.normal * 1.6
        from: 0
        to: 1
        value: root.isAudio ? Audio.volume : (root.monitor?.brightness ?? 0)

        onMoved: {
            if (root.isAudio)
                Audio.setVolume(value);
            else if (root.monitor)
                root.monitor.setBrightness(value);
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (root.isAudio) {
                    if (event.angleDelta.y > 0)
                        Audio.incrementVolume();
                    else
                        Audio.decrementVolume();
                } else if (root.monitor) {
                    const delta = Config.services.brightnessIncrement * (event.angleDelta.y > 0 ? 1 : -1);
                    root.monitor.setBrightness(Math.max(0, Math.min(1, root.monitor.brightness + delta)));
                }
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
            z: -1
        }
    }

    // Fixed width ("100%") so the bar does not jitter as the level changes.
    StyledText {
        id: valueText

        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: valueMetrics.width
        visible: root.showValue
        horizontalAlignment: Text.AlignLeft
        text: `${Math.round(slider.value * 100)}%`
        font.pointSize: Appearance.font.size.smaller
        font.family: Appearance.font.family.mono
        color: Colours.palette.m3onSurfaceVariant

        TextMetrics {
            id: valueMetrics

            text: "100%"
            font: valueText.font
        }
    }
}
