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
        Layout.fillWidth: true
        text: root.forced ? qsTr("High Contrast is on: Contrast style is used.") : qsTr("Auto picks light or dark ink per region of the wallpaper. Outline and Shadow are fixed; Contrast adds a heavier outline and weight.")
        wrapMode: Text.WordWrap
        font.pointSize: Appearance.font.size.smaller
        color: Signal.palette.inkMuted
    }
}
