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
            rounding: 1, spacing: 1, padding: 1, font: 1, motion: 1, glow: 1
        },
        {
            id: "cozy",
            label: qsTr("Cozy"),
            blurb: qsTr("Softer corners, roomier spacing, a gentler glow and unhurried motion."),
            rounding: 1.6, spacing: 1.1, padding: 1.15, font: 1.05, motion: 1.2, glow: 1.2
        }
    ]

    function sameLook(look: var): bool {
        const p = root.rootPane;
        const eq = (a, b) => Math.abs(a - b) < 0.005;
        return eq(p.roundingScale, look.rounding) && eq(p.spacingScale, look.spacing) && eq(p.paddingScale, look.padding) && eq(p.fontSizeScale, look.font) && eq(p.animDurationsScale, look.motion) && eq(Config.appearance.glow.intensity, look.glow);
    }

    function apply(look: var): void {
        const p = root.rootPane;
        p.roundingScale = look.rounding;
        p.spacingScale = look.spacing;
        p.paddingScale = look.padding;
        p.fontSizeScale = look.font;
        p.animDurationsScale = look.motion;
        Config.appearance.glow.intensity = look.glow;
        p.saveConfig();
    }

    title: qsTr("Look")
    showBackground: true

    SectionContainer {
        contentSpacing: Appearance.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("A look sets corner softness, spacing, text size, motion pace and glow in one step. Fine-tune any of them afterwards, or press Reset to return to the factory look.")
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
