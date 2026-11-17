pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Detail-pane header: a compact instrument label (glyph, title, hairline)
// left-aligned over the settings it names, instead of a centred poster.
Item {
    id: root

    required property string icon
    required property string title

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Glyph {
                name: root.icon
                color: Signal.palette.signal
                font.pointSize: Appearance.font.size.larger
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pointSize: Appearance.font.size.large
                font.weight: Appearance.font.weight.strong
                elide: Text.ElideRight
                Accessible.role: Accessible.Heading
            }
        }

        Hairline {
            Layout.fillWidth: true
        }
    }
}
