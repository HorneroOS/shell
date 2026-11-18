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

CollapsibleSection {
    id: root

    required property var rootPane

    // Density presets (rack rhythm, signal-visual-language §7.1): one step
    // writes the spacing and padding scales together, so every gap and inset
    // keeps its 8 / 12 / 16 / 24 ratio. Cosy is the factory default. The
    // sliders below stay the fine control; any other pair reads as Custom.
    readonly property var densities: [
        {
            id: "compact",
            label: qsTr("Compact"),
            scale: 0.75
        },
        {
            id: "cosy",
            label: qsTr("Cosy"),
            scale: 1.0
        },
        {
            id: "airy",
            label: qsTr("Airy"),
            scale: 1.25
        }
    ]
    readonly property int densityIndex: {
        const eq = (a, b) => Math.abs(a - b) < 0.005;
        for (let i = 0; i < densities.length; i++)
            if (eq(rootPane.spacingScale, densities[i].scale) && eq(rootPane.paddingScale, densities[i].scale))
                return i;
        return -1;
    }

    function applyDensity(index: int): void {
        const d = root.densities[index];
        if (!d)
            return;
        rootPane.spacingScale = d.scale;
        rootPane.paddingScale = d.scale;
        rootPane.saveConfig();
    }

    title: qsTr("Scales")
    showBackground: true

    SectionContainer {
        contentSpacing: Appearance.spacing.small

        StyledText {
            text: qsTr("Density")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.smaller
        }

        SegmentedControl {
            accessibleName: qsTr("Density")
            model: root.densities
            currentIndex: root.densityIndex
            onActivated: index => root.applyDensity(index)
        }

        StyledText {
            Layout.fillWidth: true
            text: root.densityIndex < 0 ? qsTr("Custom: spacing %1×, padding %2×. Pick a preset or reset to Cosy.").arg(rootPane.spacingScale.toFixed(2)).arg(rootPane.paddingScale.toFixed(2)) : qsTr("Spacing and padding move together, so gaps keep their rhythm: 8 inside a module, 12 between modules, 16 inset.")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            wrapMode: Text.WordWrap
        }

        TextButton {
            text: qsTr("Reset density")
            type: TextButton.Tonal
            enabled: root.densityIndex !== 1
            Accessible.name: qsTr("Reset density to Cosy")
            onClicked: root.applyDensity(1)
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Padding scale")
            value: rootPane.paddingScale
            from: 0.5
            to: 2.0
            decimals: 1
            suffix: "×"
            validator: DoubleValidator {
                bottom: 0.5
                top: 2.0
            }

            onValueModified: newValue => {
                rootPane.paddingScale = newValue;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Rounding scale")
            value: rootPane.roundingScale
            from: 0.1
            to: 5.0
            decimals: 1
            suffix: "×"
            validator: DoubleValidator {
                bottom: 0.1
                top: 5.0
            }

            onValueModified: newValue => {
                rootPane.roundingScale = newValue;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Spacing scale")
            value: rootPane.spacingScale
            from: 0.1
            to: 2.0
            decimals: 1
            suffix: "×"
            validator: DoubleValidator {
                bottom: 0.1
                top: 2.0
            }

            onValueModified: newValue => {
                rootPane.spacingScale = newValue;
                rootPane.saveConfig();
            }
        }
    }
}
