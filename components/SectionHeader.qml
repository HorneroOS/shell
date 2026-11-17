import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Section header inside a settings column: hairline, eyebrow title and an
// optional one-line description. The eyebrow carries the Heading role.
ColumnLayout {
    id: root

    required property string title
    property string description: ""

    spacing: 0

    Hairline {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.large
    }

    Eyebrow {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
        label: root.title
        color: Signal.palette.ink
        Accessible.ignored: false
        Accessible.role: Accessible.Heading
        Accessible.name: root.title
    }

    StyledText {
        visible: root.description !== ""
        Layout.fillWidth: true
        text: root.description
        color: Signal.palette.inkMuted
        font.pointSize: Appearance.font.size.small
        wrapMode: Text.WordWrap
    }
}
