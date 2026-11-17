pragma ComponentBehavior: Bound

import qs.components
import qs.components.atmosphere
import qs.components.controls
import qs.services
import qs.config
import qs.utils
import qs.modules.instruments as Instruments
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property Brightness.Monitor monitor
    required property var visibilities

    required property real volume
    required property bool muted
    required property real sourceVolume
    required property bool sourceMuted
    required property real brightness
    // The one channel that just changed: "out", "mic" or "bri". Only that
    // strip is drawn, so a volume change never shows brightness.
    property string channel: "out"

    implicitWidth: layout.implicitWidth + 16
    implicitHeight: layout.implicitHeight + 16

    AtmosphereTexture {}

    // One channel strip: glyph, vertical segmented meter, tabular value.
    // Values above 100 % (boosted volume) turn `signal`.
    Row {
        id: layout

        anchors.centerIn: parent
        spacing: 0

        // Speaker volume
        Channel {
            shown: root.channel === "out"
            label: qsTr("OUT")
            glyph: Icons.getVolumeIcon(root.volume, root.muted)
            muted: root.muted

            onWheelStep: up => up ? Audio.incrementVolume() : Audio.decrementVolume()

            Instruments.SegmentSlider {
                anchors.fill: parent
                accessibleName: qsTr("Volume")
                value: root.volume
                to: Config.services.maxVolume
                threshold: 1 / Config.services.maxVolume
                count: 20
                onMoved: v => Audio.setVolume(v)
            }

            valueText: Math.round(root.volume * 100)
        }

        // Microphone volume
        Channel {
            shown: root.channel === "mic" && Config.osd.enableMicrophone
            label: qsTr("MIC")
            glyph: Icons.getMicVolumeIcon(root.sourceVolume, root.sourceMuted)
            muted: root.sourceMuted

            onWheelStep: up => up ? Audio.incrementSourceVolume() : Audio.decrementSourceVolume()

            Instruments.SegmentSlider {
                anchors.fill: parent
                accessibleName: qsTr("Microphone volume")
                value: root.sourceVolume
                to: Config.services.maxVolume
                threshold: 1 / Config.services.maxVolume
                count: 20
                onMoved: v => Audio.setSourceVolume(v)
            }

            valueText: Math.round(root.sourceVolume * 100)
        }

        // Brightness
        Channel {
            shown: root.channel === "bri" && Config.osd.enableBrightness && (root.monitor?.available ?? false)
            label: qsTr("BRI")
            glyph: root.brightness < 0.34 ? "brightness-down" : root.brightness < 0.67 ? "brightness-half" : "brightness-up"

            onWheelStep: up => {
                const monitor = root.monitor;
                if (!monitor)
                    return;
                monitor.setBrightness(monitor.brightness + (up ? 1 : -1) * Config.services.brightnessIncrement);
            }

            Instruments.SegmentSlider {
                anchors.fill: parent
                accessibleName: qsTr("Brightness")
                count: 20
                value: root.brightness
                onMoved: v => root.monitor?.setBrightness(v)
            }

            valueText: root.monitor?.available ? Math.round(root.brightness * 100) : "—"
        }
    }

    component Channel: Item {
        id: channel

        required property bool shown
        property string label
        property string glyph
        property bool muted: false
        property string valueText
        default property alias meter: meterSlot.data
        signal wheelStep(bool up)

        visible: shown || opacity > 0
        opacity: shown ? 1 : 0
        implicitWidth: shown ? 40 : 0
        implicitHeight: col.implicitHeight
        clip: true

        Behavior on implicitWidth {
            Anim {
                duration: Appearance.anim.durations.short
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }

        Behavior on opacity {
            Anim {
                duration: Appearance.anim.durations.fade
            }
        }

        // Hairline between adjacent strips.
        Rectangle {
            visible: channel.x > 0
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            width: 1
            color: Signal.palette.rule
        }

        CustomMouseArea {
            anchors.fill: parent

            function onWheel(event: WheelEvent) {
                if (event.angleDelta.y !== 0)
                    channel.wheelStep(event.angleDelta.y > 0);
            }
        }

        Column {
            id: col

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Instruments.Eyebrow {
                anchors.horizontalCenter: parent.horizontalCenter
                label: channel.label
            }

            Item {
                id: meterSlot

                anchors.horizontalCenter: parent.horizontalCenter
                width: 12
                height: Config.osd.sizes.sliderHeight - 50
            }

            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                name: channel.glyph
                color: channel.muted ? Signal.palette.alert : Signal.palette.inkMuted
                size: Appearance.font.size.larger
            }

            Instruments.Well {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: 36
                implicitHeight: 18

                StyledText {
                    anchors.centerIn: parent
                    mono: true
                    text: channel.valueText
                    color: channel.muted ? Signal.palette.inkMuted : Signal.palette.ink
                    font.pointSize: Appearance.font.size.small
                }
            }
        }
    }

    // Atmosphere: warm lamp, soft inner light, vignette, grain (section 17).
    AtmosphereLayer {
        lampOrigin: "topRight"
        lampReach: 0.9
        cornerRadius: Appearance.rounding.small
    }
}
