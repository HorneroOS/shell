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

    title: qsTr("Animations")
    showBackground: true

    // Accessibility toggles: semantic shortcuts for the animation scale slider
    SwitchRow {
        label: qsTr("Disable animations")
        checked: rootPane.animDurationsScale <= 0.05
        onToggled: checked => {
            rootPane.animDurationsScale = checked ? 0.01 : 1.0;
            rootPane.saveConfig();
        }
    }

    SwitchRow {
        label: qsTr("Reduce motion")
        checked: rootPane.animDurationsScale > 0.05 && rootPane.animDurationsScale <= 0.35
        enabled: rootPane.animDurationsScale > 0.05
        onToggled: checked => {
            rootPane.animDurationsScale = checked ? 0.3 : 1.0;
            rootPane.saveConfig();
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Animation duration scale")
            value: rootPane.animDurationsScale
            from: 0.01
            to: 5.0
            decimals: 2
            suffix: "×"
            validator: DoubleValidator {
                bottom: 0.01
                top: 5.0
            }

            onValueModified: newValue => {
                rootPane.animDurationsScale = newValue;
                rootPane.saveConfig();
            }
        }
    }

    // Leading/trailing asymmetry (signal-visual-language §11): how far the
    // trailing edge of a travelling indicator (dashboard tabs, workspace
    // plate) lags the leading edge. 1.0 moves both edges together.
    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Trailing edge stretch")
            value: Config.appearance.anim.trailRatio
            from: 1.0
            to: 2.5
            decimals: 1
            suffix: "×"
            validator: DoubleValidator {
                bottom: 1.0
                top: 2.5
            }

            onValueModified: newValue => {
                Config.appearance.anim.trailRatio = Math.max(1, Math.min(2.5, newValue));
                Config.save();
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Indicators stretch toward their target and catch up. Applies at the Signal and Everyday motion levels; reduced motion moves both edges together.")
            font.pointSize: Appearance.font.size.small
            color: Signal.palette.inkMuted
            wrapMode: Text.WordWrap
        }

        TextButton {
            text: qsTr("Reset motion feel")
            type: TextButton.Tonal
            enabled: Config.appearance.anim.curveStyle !== "smooth" || Math.abs(Config.appearance.anim.trailRatio - 1.6) > 0.005
            Accessible.name: qsTr("Reset motion style to Smooth and trailing edge stretch to 1.6")
            onClicked: {
                Config.appearance.anim.curveStyle = "smooth";
                Config.appearance.anim.trailRatio = 1.6;
                Config.save();
            }
        }
    }
}
