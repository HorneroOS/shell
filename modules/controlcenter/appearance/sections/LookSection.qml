pragma ComponentBehavior: Bound

import ".."
import "../../components"
import qs.components
import qs.components.controls
import qs.components.containers
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Looks: named bundles of the scalar appearance tokens (rounding, spacing,
// padding, font size, animation pace, glow). Applying a look only writes
// those scalars, so each one stays individually adjustable in Scales, Fonts,
// Animations and below; nothing is forced. Colours are a separate choice
// (Themes / Chromatic).
CollapsibleSection {
    id: root

    required property var rootPane

    // The factory look ("Hornero") is the all-ones default.
    readonly property var looks: [
        {
            id: "hornero",
            label: qsTr("Hornero"),
            blurb: qsTr("The factory look: crisp Signal bezel, reference spacing."),
            rounding: 1, spacing: 1, padding: 1, font: 1, motion: 1, glow: 1, weight: 0, curve: "smooth",
            atmosphere: ({ lamp: 0.8, warmth: 0.2, innerLight: 0.8, vignette: 0.4, grain: 0.3, scanlines: 0, plateTracking: 0.14, mascot: true, tone: "cozy" })
        },
        {
            id: "cozy",
            label: qsTr("Cozy"),
            blurb: qsTr("Softer corners, roomier spacing, a gentler glow, a warmer lamp and unhurried motion."),
            rounding: 1.2, spacing: 1.1, padding: 1.15, font: 1.05, motion: 1.2, glow: 1.2, weight: 0, curve: "lively",
            atmosphere: ({ lamp: 1.2, warmth: 0.45, innerLight: 1.1, vignette: 0.5, grain: 0.4, scanlines: 0, plateTracking: 0.14, mascot: true, tone: "cozy" })
        }
    ]

    function sameLook(look: var): bool {
        const p = root.rootPane;
        const eq = (a, b) => Math.abs(a - b) < 0.005;
        return eq(p.roundingScale, look.rounding) && eq(p.spacingScale, look.spacing) && eq(p.paddingScale, look.padding) && eq(p.fontSizeScale, look.font) && eq(p.animDurationsScale, look.motion) && eq(Config.appearance.glow.intensity, look.glow) && Config.appearance.font.weight.shift === look.weight && Config.appearance.anim.curveStyle === look.curve && sameAtmosphere(look.atmosphere);
    }

    // A look also sets the atmosphere knobs (Appearance > Atmosphere); the
    // on/off switch stays the user's own choice.
    function sameAtmosphere(a: var): bool {
        const cur = Config.appearance.atmosphere;
        const eq = (x, y) => Math.abs(x - y) < 0.005;
        return eq(cur.lamp, a.lamp) && eq(cur.warmth, a.warmth) && eq(cur.innerLight, a.innerLight) && eq(cur.vignette, a.vignette) && eq(cur.grain, a.grain) && eq(cur.scanlines, a.scanlines) && eq(cur.plateTracking, a.plateTracking) && cur.mascot === a.mascot && cur.tone === a.tone;
    }

    function writeLook(look: var): bool {
        const p = root.rootPane;
        p.roundingScale = look.rounding;
        p.spacingScale = look.spacing;
        p.paddingScale = look.padding;
        p.fontSizeScale = look.font;
        p.animDurationsScale = look.motion;
        Config.appearance.glow.intensity = look.glow;
        Config.appearance.font.weight.shift = look.weight;
        Config.appearance.anim.curveStyle = look.curve;
        for (const k of Object.keys(look.atmosphere))
            Config.appearance.atmosphere[k] = look.atmosphere[k];
        p.saveConfig();
        return true;
    }

    // Applies at once and offers Undo with the exact previous values. The
    // values are remembered in Undo (Config objects only), not in this pane.
    function apply(look: var): void {
        Undo.offerValues("look", qsTr("Look: %1").arg(look.label), [
            {
                "obj": Config.appearance.rounding,
                "keys": ["scale"]
            },
            {
                "obj": Config.appearance.spacing,
                "keys": ["scale"]
            },
            {
                "obj": Config.appearance.padding,
                "keys": ["scale"]
            },
            {
                "obj": Config.appearance.font.size,
                "keys": ["scale"]
            },
            {
                "obj": Config.appearance.anim.durations,
                "keys": ["scale"]
            },
            {
                "obj": Config.appearance.glow,
                "keys": ["intensity"]
            },
            {
                "obj": Config.appearance.font.weight,
                "keys": ["shift"]
            },
            {
                "obj": Config.appearance.anim,
                "keys": ["curveStyle"]
            },
            {
                "obj": Config.appearance.atmosphere,
                "keys": Object.keys(look.atmosphere)
            }
        ], qsTr("Undo restores every scale, the glow and the atmosphere knobs."));
        root.writeLook(look);
    }

    title: qsTr("Look")
    showBackground: true

    SectionContainer {
        contentSpacing: Appearance.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("A look sets corner softness, spacing, text size, motion pace, glow and the atmosphere in one step. Fine-tune any of them afterwards, or press Reset to return to the factory look.")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            wrapMode: Text.WordWrap
        }

        Flow {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Repeater {
                model: root.looks

                TextButton {
                    required property var modelData

                    text: modelData.label
                    toggle: true
                    checked: root.sameLook(modelData)
                    type: TextButton.Tonal
                    Accessible.name: qsTr("%1 look: %2").arg(modelData.label).arg(modelData.blurb)
                    onClicked: root.apply(modelData)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: {
                for (const l of root.looks)
                    if (root.sameLook(l))
                        return l.blurb;
                return qsTr("Custom: a mix of your own adjustments.");
            }
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            wrapMode: Text.WordWrap
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.small

        SizeSlider {
            target: Config.appearance.glow
            key: "intensity"
            label: qsTr("Glow intensity")
            from: 0
            to: 1.5
            defaultValue: 1
            stepSize: 0.05
            decimals: 2
            suffix: "×"
        }

        SizeSlider {
            target: Config.appearance.glow
            key: "limit"
            label: qsTr("Glowing items at once")
            from: 1
            to: 6
            defaultValue: 3
            stepSize: 1
            suffix: ""
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Scales the glows the experience mode already allows. 0 turns glow off; Gaming and Focus keep it off regardless.")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            wrapMode: Text.WordWrap
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.small

        StyledText {
            text: qsTr("Control Center window")
            font.pointSize: Appearance.font.size.normal
        }

        SizeSlider {
            target: Config.controlCenter.sizes
            key: "heightMult"
            label: qsTr("Height (share of the screen)")
            from: 0.5
            to: 0.95
            defaultValue: 0.7
            stepSize: 0.05
            suffix: "×"
            decimals: 2
        }
        SizeSlider {
            target: Config.controlCenter.sizes
            key: "ratio"
            label: qsTr("Width to height ratio")
            from: 1.2
            to: 2.4
            defaultValue: 1.7777777777777777
            stepSize: 0.05
            suffix: "×"
            decimals: 2
        }
        SizeSlider {
            target: Config.controlCenter
            key: "undoSeconds"
            label: qsTr("How long Undo stays after a change")
            from: 3
            to: 60
            defaultValue: 10
            stepSize: 1
            suffix: " s"
        }
        SwitchRow {
            label: qsTr("Preview themes and colours while pointing at them")
            checked: Config.controlCenter.appearanceHoverPreview
            onToggled: checked => {
                Config.controlCenter.appearanceHoverPreview = checked;
                Config.save();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.small

        SizeSlider {
            target: Config.appearance.font.weight
            key: "shift"
            label: qsTr("Text weight shift")
            from: -200
            to: 200
            defaultValue: 0
            stepSize: 100
            suffix: ""
        }

        StyledText {
            text: qsTr("Motion style")
            font.pointSize: Appearance.font.size.normal
        }

        Flow {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Repeater {
                model: [
                    {
                        id: "smooth",
                        label: qsTr("Smooth")
                    },
                    {
                        id: "snappy",
                        label: qsTr("Snappy")
                    },
                    {
                        id: "lively",
                        label: qsTr("Lively")
                    }
                ]

                TextButton {
                    required property var modelData

                    text: modelData.label
                    toggle: true
                    checked: Appearance.anim.curves.style === modelData.id
                    type: TextButton.Tonal
                    Accessible.name: qsTr("%1 motion style").arg(modelData.label)
                    onClicked: {
                        Config.appearance.anim.curveStyle = modelData.id;
                        Config.save();
                    }
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Smooth (factory) settles like a needle, at most 4 % past the mark; Snappy never overshoots; Lively adds a spring, capped at 6 %. Opacity and colour never overshoot, and reduced motion still wins.")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            wrapMode: Text.WordWrap
        }
    }

    SectionContainer {
        TextButton {
            text: qsTr("Reset look to factory")
            type: TextButton.Tonal
            Accessible.name: qsTr("Reset the look to the factory Hornero look")
            onClicked: root.apply(root.looks[0])
        }
    }
}
