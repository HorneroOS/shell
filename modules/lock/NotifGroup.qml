pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import qs.utils
import qs.modules.instruments as Instruments
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

// One app's notifications on the lock screen: a fixed row with the app
// name, a count and the newest line. Reading only — expand by unlocking.
// Urgency is named in words (URGENT), never colour alone.
Rectangle {
    id: root

    required property string modelData

    readonly property list<var> notifs: Notifs.list.filter(notif => notif.appName === modelData)
    readonly property bool critical: notifs.some(n => n.urgency === NotificationUrgency.Critical)

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: content.implicitHeight + Appearance.padding.normal * 2

    radius: Appearance.rounding.small
    color: Signal.palette.raised
    border.width: 1
    border.color: root.critical ? Signal.palette.alert : Signal.palette.rule

    ColumnLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Appearance.padding.normal
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Appearance.spacing.small

            Instruments.Eyebrow {
                Layout.fillWidth: true

                label: root.modelData
            }

            Instruments.OnAirChip {
                visible: root.critical
                fill: Signal.palette.alert
                ink: Signal.palette.onAlert
                text: qsTr("Urgent")
            }

            StyledText {
                mono: true
                text: String(root.notifs.length)
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.small
            }
        }

        StyledText {
            id: line

            readonly property var latest: root.notifs[0] ?? null

            Layout.fillWidth: true

            text: latest ? `${latest.summary} ${latest.body}`.replace(/\n/g, " ") : ""
            elide: Text.ElideRight
            maximumLineCount: 1

            Component.onCompleted: latest?.lock(this)
            Component.onDestruction: latest?.unlock(this)
        }
    }
}
