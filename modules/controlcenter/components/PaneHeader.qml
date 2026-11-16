pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Shared page header for Control Center panes (shell#454): the pane icon and
// title, its one-line description, and — for panes whose purpose is not
// obvious — a short plain-language introduction in a soft card. Every pane
// opens the same way, so the window reads as one app.
ColumnLayout {
    id: root

    required property string title
    property string icon: ""
    property string description: ""
    property string intro: ""

    Layout.fillWidth: true
    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        MaterialIcon {
            visible: root.icon.length > 0
            text: root.icon
            font.pointSize: Appearance.font.size.extraLarge
            color: Colours.palette.m3primary
        }

        StyledText {
            Layout.fillWidth: true
            text: root.title
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: 600
            elide: Text.ElideRight
            Accessible.role: Accessible.Heading
        }
    }

    StyledText {
        visible: root.description.length > 0
        Layout.fillWidth: true
        text: root.description
        font.pointSize: Appearance.font.size.normal
        color: Colours.palette.m3onSurfaceVariant
        wrapMode: Text.WordWrap
    }

    StyledRect {
        visible: root.intro.length > 0
        Layout.fillWidth: true
        Layout.topMargin: Appearance.spacing.small
        implicitHeight: introRow.implicitHeight + Appearance.padding.large * 2
        radius: Appearance.rounding.normal
        color: Colours.tPalette.m3surfaceContainerHigh

        RowLayout {
            id: introRow

            anchors.fill: parent
            anchors.margins: Appearance.padding.large
            spacing: Appearance.spacing.normal

            MaterialIcon {
                Layout.alignment: Qt.AlignTop
                text: "info"
                color: Colours.palette.m3secondary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.intro
                wrapMode: Text.WordWrap
                color: Colours.palette.m3onSurface
            }
        }
    }
}
