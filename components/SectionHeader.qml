import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property string title
    property string description: ""

    spacing: 0

    Hairline {
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.large
    }

    StyledText {
        Layout.topMargin: Appearance.spacing.small
        text: root.title
        font.pointSize: Appearance.font.size.larger
        font.weight: 600
        Accessible.role: Accessible.Heading
    }

    StyledText {
        visible: root.description !== ""
        text: root.description
        color: Signal.palette.inkMuted
    }
}
