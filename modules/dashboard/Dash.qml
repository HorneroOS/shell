import qs.components
import qs.components.filedialog
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import "dash"
import Quickshell
import QtQuick.Layouts

// Dashboard home (Signal Bezel): an instrument panel, not a card grid.
// Three columns on the 4 px grid; every module is a `panel` frame with a
// 1 px `rule` border and radius `small`, labelled by an eyebrow and bound
// to real services only (clock, weather, system usage, MPRIS).
//
//   STATION  | CLOCK            | WEATHER
//   CALENDAR | RESOURCES (scope, meters, dimension lines)
//   MEDIA strip
GridLayout {
    id: root

    required property PersistentProperties visibilities
    required property PersistentProperties state
    required property FileDialog facePicker

    readonly property int leftWidth: 296
    readonly property int midWidth: 336
    readonly property int rightWidth: 320

    columns: 3
    rowSpacing: Appearance.spacing.small
    columnSpacing: Appearance.spacing.small

    Instruments.Frame {
        Layout.row: 0
        Layout.column: 0
        Layout.preferredWidth: root.leftWidth
        Layout.fillHeight: true
        implicitHeight: user.implicitHeight + headerHeight + 12
        channel: "01"
        title: qsTr("Station")

        User {
            id: user

            anchors.left: parent.left
            anchors.right: parent.right
            visibilities: root.visibilities
            state: root.state
            facePicker: root.facePicker
        }
    }

    Instruments.Frame {
        Layout.row: 0
        Layout.column: 1
        Layout.preferredWidth: root.midWidth
        Layout.fillHeight: true
        implicitHeight: 148
        channel: "02"
        title: qsTr("Clock")

        DateTime {
            anchors.fill: parent
        }
    }

    Instruments.Frame {
        Layout.row: 0
        Layout.column: 2
        Layout.preferredWidth: root.rightWidth
        Layout.fillHeight: true
        implicitHeight: 148
        channel: "03"
        title: qsTr("Weather")
        context: Weather.ready ? Weather.city : ""

        Weather {
            anchors.fill: parent
        }
    }

    Instruments.Frame {
        Layout.row: 1
        Layout.column: 0
        Layout.preferredWidth: root.leftWidth
        Layout.fillHeight: true
        implicitHeight: calendar.implicitHeight + 24
        padding: 12

        Calendar {
            id: calendar

            anchors.left: parent.left
            anchors.right: parent.right
            state: root.state
        }
    }

    Instruments.Frame {
        Layout.row: 1
        Layout.column: 1
        Layout.columnSpan: 2
        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: resources.implicitHeight + headerHeight + 16
        channel: "04"
        title: qsTr("Resources")
        context: resources.windowLabel

        Resources {
            id: resources

            anchors.left: parent.left
            anchors.right: parent.right
        }
    }

    Instruments.Frame {
        Layout.row: 2
        Layout.column: 0
        Layout.columnSpan: 3
        Layout.fillWidth: true
        implicitHeight: 76
        padding: 10

        Media {
            anchors.fill: parent
            visibilities: root.visibilities
        }
    }
}
