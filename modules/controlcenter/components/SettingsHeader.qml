pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Detail-column header: a 24 px glyph and the title on one line over a
// hairline, left-aligned like the pane headers. The title carries the
// Heading role.
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
        height: implicitHeight
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.normal

            Glyph {
                name: root.icon
                color: Signal.palette.signal
                font.pointSize: Appearance.font.size.extraLarge
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                elide: Text.ElideRight
                font.pointSize: Appearance.font.size.large
                font.weight: 600
                Accessible.role: Accessible.Heading
            }
        }

        Hairline {
            Layout.fillWidth: true
        }
    }
}
