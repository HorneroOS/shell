pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.atmosphere
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Atmosphere (visual language section 17): warm lamp light, soft inner
// highlights, vignette, grain and scanlines, the hornero mascot and the
// microcopy voice. Every value is a persisted setting with a reset; the
// preview strip shows the live result, and "Cozy" in Look sets a preset.
CollapsibleSection {
    id: root

    required property var rootPane

    readonly property var factory: ({
            "enabled": true,
            "lamp": 0.8,
            "warmth": 0.2,
            "innerLight": 0.8,
            "vignette": 0.4,
            "grain": 0.3,
            "scanlines": 0,
            "plateTracking": 0.14,
            "mascot": true,
            "tone": "cozy"
        })
    readonly property var atmo: Config.appearance.atmosphere

    function resetAll(): void {
        Undo.offerValues("atmosphere-reset", qsTr("Atmosphere reset to factory"), [
            {
                "obj": Config.appearance.atmosphere,
                "keys": Object.keys(root.factory)
            }
        ], qsTr("Undo brings back your lamp, warmth, grain and voice."));
        for (const k of Object.keys(root.factory))
            root.atmo[k] = root.factory[k];
        Config.save();
    }

    title: qsTr("Atmosphere")
    showBackground: true

    SectionContainer {
        contentSpacing: Appearance.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("A warm layer over the Signal surfaces: lamp light, soft highlights, a gentle vignette, film grain, the hornero and a friendlier voice. Everything here is optional and subtle by default.")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            wrapMode: Text.WordWrap
        }

        SwitchRow {
            label: qsTr("Atmosphere")
            checked: root.atmo.enabled
            onToggled: checked => {
                root.atmo.enabled = checked;
                Config.save();
            }
        }

        // Live preview: the real layer on a panel-coloured card.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            radius: Appearance.rounding.small
            color: Signal.palette.panel
            border.width: 1
            border.color: Signal.palette.rule
            clip: true

            Accessible.role: Accessible.StaticText
            Accessible.name: qsTr("Atmosphere preview")

            AtmosphereLayer {
                lampOrigin: "topRight"
                lampReach: 0.9
                cornerRadius: Appearance.rounding.small
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: Appearance.spacing.normal

                HorneroSprite {
                    pixel: 4
                    force: true
                }

                ColumnLayout {
                    spacing: 2

                    StyledText {
                        text: Atmosphere.active ? Microcopy.greeting : qsTr("Atmosphere is off")
                        color: Signal.palette.ink
                        font.pointSize: Appearance.font.size.normal
                    }

                    StyledText {
                        text: Microcopy.line("notifications.empty")
                        color: Signal.palette.inkMuted
                        font.pointSize: Appearance.font.size.small
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.atmo.enabled && !Atmosphere.allowed
            text: Config.appearance.highContrast ? qsTr("High Contrast is on, so the atmosphere stays hidden.") : qsTr("The current experience mode keeps the atmosphere hidden (Focus, Gaming and Studio use a plain canvas).")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            wrapMode: Text.WordWrap
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.small

        SizeSlider {
            target: root.atmo
            key: "lamp"
            label: qsTr("Lamp light")
            from: 0
            to: 1.5
            defaultValue: root.factory.lamp
            stepSize: 0.05
            decimals: 2
            suffix: "×"
        }

        SizeSlider {
            target: root.atmo
            key: "warmth"
            label: qsTr("Lamp tint (amber to rose)")
            from: 0
            to: 1
            defaultValue: root.factory.warmth
            stepSize: 0.05
            decimals: 2
            suffix: ""
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Repeater {
                model: [
                    {
                        name: qsTr("Lamp"),
                        colour: Atmosphere.lamp
                    },
                    {
                        name: qsTr("Blush"),
                        colour: Atmosphere.blush
                    }
                ]

                RowLayout {
                    required property var modelData

                    spacing: Appearance.spacing.small
                    Accessible.role: Accessible.StaticText
                    Accessible.name: qsTr("%1 accent colour %2").arg(modelData.name).arg(String(modelData.colour))

                    Rectangle {
                        implicitWidth: 18
                        implicitHeight: 18
                        radius: Appearance.rounding.small
                        color: parent.modelData.colour
                        border.width: 1
                        border.color: Signal.palette.rule
                    }

                    StyledText {
                        text: parent.modelData.name
                        font.pointSize: Appearance.font.size.small
                        color: Signal.palette.inkMuted
                        Accessible.ignored: true
                    }
                }
            }
        }

        SizeSlider {
            target: root.atmo
            key: "innerLight"
            label: qsTr("Soft inner highlight")
            from: 0
            to: 1.5
            defaultValue: root.factory.innerLight
            stepSize: 0.05
            decimals: 2
            suffix: "×"
        }

        SizeSlider {
            target: root.atmo
            key: "vignette"
            label: qsTr("Vignette")
            from: 0
            to: 1
            defaultValue: root.factory.vignette
            stepSize: 0.05
            decimals: 2
            suffix: ""
        }

        SizeSlider {
            target: root.atmo
            key: "grain"
            label: qsTr("Film grain")
            from: 0
            to: 1
            defaultValue: root.factory.grain
            stepSize: 0.05
            decimals: 2
            suffix: ""
        }

        SizeSlider {
            target: root.atmo
            key: "scanlines"
            label: qsTr("Scanlines")
            from: 0
            to: 1
            defaultValue: root.factory.scanlines
            stepSize: 0.05
            decimals: 2
            suffix: ""
        }

        SizeSlider {
            target: root.atmo
            key: "plateTracking"
            label: qsTr("Plate label tracking")
            from: 0
            to: 0.3
            defaultValue: root.factory.plateTracking
            stepSize: 0.01
            decimals: 2
            suffix: " em"
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("The lamp shares the glow budget with the on-air bar and scope traces, and day themes keep a softer lamp without vignette or scanlines.")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            wrapMode: Text.WordWrap
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.small

        SwitchRow {
            label: qsTr("Hornero mascot")
            checked: root.atmo.mascot
            onToggled: checked => {
                root.atmo.mascot = checked;
                Config.save();
            }
        }

        StyledText {
            text: qsTr("Microcopy voice")
            font.pointSize: Appearance.font.size.normal
            color: Signal.palette.ink
        }

        Flow {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Repeater {
                model: [
                    {
                        id: "cozy",
                        label: qsTr("Cozy"),
                        blurb: qsTr("Warm, short lines in empty states and greetings.")
                    },
                    {
                        id: "plain",
                        label: qsTr("Plain"),
                        blurb: qsTr("Neutral wording, no personality.")
                    }
                ]

                TextButton {
                    required property var modelData

                    text: modelData.label
                    toggle: true
                    checked: root.atmo.tone === modelData.id
                    type: TextButton.Tonal
                    Accessible.name: qsTr("%1 voice: %2").arg(modelData.label).arg(modelData.blurb)
                    onClicked: {
                        root.atmo.tone = modelData.id;
                        Config.save();
                    }
                }
            }
        }
    }

    SectionContainer {
        TextButton {
            text: qsTr("Reset atmosphere to factory")
            type: TextButton.Tonal
            Accessible.name: qsTr("Reset every atmosphere setting to its factory value")
            onClicked: root.resetAll()
        }
    }
}
