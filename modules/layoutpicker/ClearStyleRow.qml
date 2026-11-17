import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Cockpit Clear foreground style (signal-visual-language §12.3). Shown in
// the Layout Picker and in Settings > Layout. High Contrast forces
// Contrast, so the control is disabled and says so.
ColumnLayout {
    id: root

    readonly property var names: ClearInk.styles
    readonly property bool forced: Config.appearance.highContrast

    spacing: Appearance.spacing.small

    StyledText {
        text: qsTr("Cockpit Clear text style")
        font.pointSize: Appearance.font.size.small
        font.weight: Font.Medium
        color: Signal.palette.ink
    }

    SegmentedControl {
        accessibleName: qsTr("Cockpit Clear text style")
        disabled: root.forced
        model: root.names.map(n => ClearInk.styleLabel(n))
        currentIndex: Math.max(0, root.names.indexOf(root.forced ? "contrast" : ClearInk.configuredStyle))
        onActivated: index => ClearInk.setStyle(root.names[index])
    }

    StyledText {
        text: qsTr("Ink")
        font.pointSize: Appearance.font.size.small
        font.weight: Font.Medium
        color: Signal.palette.ink
    }

    SegmentedControl {
        accessibleName: qsTr("Cockpit Clear ink polarity")
        model: ClearInk.polarities.map(n => ClearInk.polarityLabel(n))
        currentIndex: Math.max(0, ClearInk.polarities.indexOf(ClearInk.configuredPolarity))
        onActivated: index => ClearInk.setKnob("polarity", ClearInk.polarities[index])
    }

    SpinBoxRow {
        label: qsTr("Shadow strength (%)")
        value: Math.round(Config.bar.clearInk.strength * 100)
        min: 0
        max: 150
        step: 5
        onValueModified: value => ClearInk.setKnob("strength", value / 100)
    }

    SpinBoxRow {
        label: qsTr("Outline width (%)")
        value: Math.round(Config.bar.clearInk.outline * 100)
        min: 0
        max: 200
        step: 10
        onValueModified: value => ClearInk.setKnob("outline", value / 100)
    }

    StyledText {
        Layout.fillWidth: true
        text: root.forced ? qsTr("High Contrast is on: Contrast style is used.") : qsTr("Auto keeps one ink and a soft shadow, and flips only where the wallpaper needs it. Outline is a firm ring, Shadow a soft drop, Contrast both with heavier weight. Ink, strength and width fine-tune any style.")
        wrapMode: Text.WordWrap
        font.pointSize: Appearance.font.size.smaller
        color: Signal.palette.inkMuted
    }
}
