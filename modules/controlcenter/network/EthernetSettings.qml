pragma ComponentBehavior: Bound

import ".."
import "../components"
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    height: implicitHeight

    required property Session session

    spacing: Appearance.spacing.normal

    SettingsHeader {
        icon: "plug-connected"
        title: qsTr("Ethernet settings")
    }

    Eyebrow {
        Layout.topMargin: Appearance.spacing.large
        label: qsTr("Ethernet devices")
        color: Signal.palette.ink
    }

    StyledText {
        text: qsTr("Available ethernet devices")
        color: Signal.palette.inkMuted
    }

    StyledRect {
        Layout.fillWidth: true
        implicitHeight: ethernetInfo.implicitHeight + Appearance.padding.large * 2

        radius: Appearance.rounding.small
        color: "transparent"
        border.width: 1
        border.color: Signal.palette.rule

        ColumnLayout {
            id: ethernetInfo

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Appearance.padding.large

            spacing: Appearance.spacing.small / 2

            StyledText {
                text: qsTr("Total devices")
            }

            StyledText {
                text: qsTr("%1").arg(Nmcli.ethernetDevices.length)
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }

            StyledText {
                Layout.topMargin: Appearance.spacing.normal
                text: qsTr("Connected devices")
            }

            StyledText {
                text: qsTr("%1").arg(Nmcli.ethernetDevices.filter(d => d.connected).length)
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }
        }
    }
}
