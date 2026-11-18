import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// "My tweaks for this layout": save the current bar sizes, type face and
// scales as the override row of the active layout; they are laid back on top
// whenever that layout is applied from the shell (services/Layouts.qml).
ColumnLayout {
    id: root

    // The catalogue id of the live layout, "" when custom or unknown.
    required property string layoutId

    readonly property int saved: root.layoutId.length > 0 ? Layouts.count(root.layoutId) : 0

    spacing: Appearance.spacing.small

    StyledText {
        text: qsTr("My tweaks for this layout")
        font.pointSize: Appearance.font.size.small
        font.weight: Font.Medium
        color: Signal.palette.ink
    }

    StyledText {
        Layout.fillWidth: true
        text: root.layoutId.length === 0 ? qsTr("Pick a catalogue layout first: tweaks are remembered per layout.") : root.saved > 0 ? qsTr("%1 saved values are laid back on top each time this layout is applied.").arg(root.saved) : qsTr("Save your current bar sizes, text face and scales for this layout. Applying it later keeps them instead of the preset's values.")
        font.pointSize: Appearance.font.size.smaller
        color: Signal.palette.inkMuted
        wrapMode: Text.WordWrap
    }

    RowLayout {
        spacing: Appearance.spacing.small

        TextButton {
            text: root.saved > 0 ? qsTr("Update my tweaks") : qsTr("Save my tweaks")
            type: TextButton.Tonal
            enabled: root.layoutId.length > 0
            Accessible.name: qsTr("Save the current bar sizes and scales as the tweaks of this layout")
            onClicked: Layouts.remember(root.layoutId)
        }

        TextButton {
            text: qsTr("Apply my tweaks")
            type: TextButton.Tonal
            visible: root.saved > 0
            Accessible.name: qsTr("Apply the saved tweaks of this layout now")
            onClicked: Layouts.applyNow(root.layoutId)
        }

        TextButton {
            text: qsTr("Forget")
            type: TextButton.Tonal
            visible: root.saved > 0
            Accessible.name: qsTr("Forget the saved tweaks of this layout")
            onClicked: Layouts.forget(root.layoutId)
        }
    }
}
