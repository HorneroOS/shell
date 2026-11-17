pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import QtQuick
import QtQuick.Layouts

// Sub-page header (Bluetooth, Network, VPN settings): the same anatomy as
// PaneHeader (eyebrow, 28 px title with its glyph) so sub-pages open like
// the panes they belong to. The title carries the Heading role.
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

        Instruments.Eyebrow {
            Layout.fillWidth: true
            label: qsTr("Settings")
        }

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
                font.pointSize: Appearance.font.size.extraLarge
                font.weight: Appearance.font.weight.strong
                Accessible.role: Accessible.Heading
            }
        }

        Hairline {
            Layout.fillWidth: true
        }
    }
}
