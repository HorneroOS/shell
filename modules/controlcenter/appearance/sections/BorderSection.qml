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

    title: qsTr("Border")
    showBackground: true

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Border rounding")
            value: rootPane.borderRounding
            from: 0.1
            to: 100
            decimals: 1
            suffix: "px"
            validator: DoubleValidator {
                bottom: 0.1
                top: 100
            }

            onValueModified: newValue => {
                rootPane.borderRounding = newValue;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SliderInput {
            Layout.fillWidth: true

            label: qsTr("Border thickness")
            value: rootPane.borderThickness
            from: 0.1
            to: 100
            decimals: 1
            suffix: "px"
            validator: DoubleValidator {
                bottom: 0.1
                top: 100
            }

            onValueModified: newValue => {
                rootPane.borderThickness = newValue;
                rootPane.saveConfig();
            }
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SizeSlider {
            target: Config.border
            key: "edgeWidth"
            label: qsTr("Frame edge line")
            from: 0
            to: 4
            defaultValue: 1
            stepSize: 1
            suffix: "px"
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("The line that separates the bar and frame from the desktop. High Contrast keeps it at 2 px or more.")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            wrapMode: Text.WordWrap
        }
    }

    SectionContainer {
        contentSpacing: Appearance.spacing.normal

        SizeSlider {
            target: Config.border
            key: "fillet"
            label: qsTr("Machined fillet")
            from: 0
            to: 16
            defaultValue: 6
            stepSize: 1
            suffix: "px"
        }

        StyledText {
            Layout.fillWidth: true
            text: qsTr("The small curve where a drawer or popout meets the bar or the frame, so it grows out of the bezel. 0 keeps the flush square junction. Floating and clear bars never get one.")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            wrapMode: Text.WordWrap
        }
    }
}
