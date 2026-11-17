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

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    required property ShellScreen screen
    required property string kind // "audio" | "brightness"
    // Per-entry options: showValue prints the level ("72%") after the slider.
    property var options: ({})
    readonly property bool showValue: options?.showValue === true
    // Set by narrow bars: a shorter track keeps every group on screen.
    property bool compact: false

    readonly property bool isAudio: kind === "audio"
    readonly property Brightness.Monitor monitor: Brightness.getMonitorForScreen(screen)

    // A brightness slider without a backlight would show an invented 0%.
    readonly property bool available: isAudio || (monitor?.available ?? false)

    spacing: Appearance.spacing.small
    implicitWidth: icon.implicitWidth + spacing + slider.implicitWidth + (showValue ? spacing + valueText.implicitWidth : 0)
    implicitHeight: Math.max(icon.implicitHeight, slider.implicitHeight)

    Glyph {
        size: Density.iconPt
        id: icon

        Layout.alignment: Qt.AlignVCenter
        name: {
            if (!root.isAudio)
                return "brightness-half";
            if (Audio.muted || Audio.volume === 0)
                return "volume-off";
            return "volume";
        }
        color: root.tone.ink

        Behavior on text {
            Anim {}
        }
    }

    StyledSlider {
        id: slider

        Accessible.role: Accessible.Slider
        Accessible.name: root.isAudio ? qsTr("Volume") : qsTr("Brightness")
        Accessible.description: qsTr("%1. Scroll or use the arrow keys to adjust.").arg(root.isAudio && Audio.muted ? qsTr("Muted") : `${Math.round(value * 100)}%`)

        Layout.alignment: Qt.AlignVCenter
        implicitWidth: root.compact ? 64 : 110
        implicitHeight: Density.iconPx * 1.2
        // Ink at rest; amber only while the person is dragging it.
        ruleTrack: root.tone.active
        fillColour: slider.pressed ? root.tone.signal : root.tone.ink
        trackColour: root.tone.active ? Qt.alpha(root.tone.ink, 0.42) : Signal.palette.lifted
        thumbColour: slider.pressed ? root.tone.signal : root.tone.ink
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

    Tooltip {
        target: slider
        text: `${root.isAudio ? qsTr("Volume") : qsTr("Brightness")}: ${root.isAudio && Audio.muted ? qsTr("Muted") : `${Math.round(slider.value * 100)}%`}`
    }

    // Fixed width ("100%") so the bar does not jitter as the level changes.
    BarText {
        id: valueText

        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: valueMetrics.width
        visible: root.showValue
        horizontalAlignment: Text.AlignLeft
        text: `${Math.round(slider.value * 100)}%`
        color: root.tone.ink

        TextMetrics {
            id: valueMetrics

            text: "100%"
            font: valueText.font
        }
    }
}
