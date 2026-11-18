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
// Rack rhythm (signal-visual-language §7.1): 8 inside a module, 12 between
// modules, 16 surface inset, 24 section break. Every gap and inset here is
// a spacing/padding token, so Appearance > Scales > Density (Compact, Cosy,
// Airy) moves the whole panel together. Only sizes are literal.
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
    // Top-row content height: the taller of the clock face and the weather
    // readout, so the row grows with font and density instead of clipping.
    readonly property real topRowContent: Math.max(dateTime.implicitHeight, weather.implicitHeight)

    rowSpacing: Appearance.spacing.normal
    columnSpacing: Appearance.spacing.normal

    Instruments.Frame {
        Layout.row: 0
        Layout.column: 0
        Layout.preferredWidth: root.leftWidth
        Layout.fillHeight: true
        implicitHeight: user.implicitHeight + headerHeight + Appearance.padding.larger
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
        implicitHeight: root.topRowContent + headerHeight + padding
        channel: "02"
        title: qsTr("Clock")

        DateTime {
            id: dateTime

            anchors.fill: parent
        }
    }

    Instruments.Frame {
        Layout.row: 0
        Layout.column: 2
        Layout.preferredWidth: root.rightWidth
        Layout.fillHeight: true
        implicitHeight: root.topRowContent + headerHeight + padding
        channel: "03"
        title: qsTr("Weather")
        context: Weather.ready ? Weather.city : ""

        Weather {
            id: weather

            anchors.fill: parent
        }
    }

    Instruments.Frame {
        Layout.row: 1
        Layout.column: 0
        Layout.preferredWidth: root.leftWidth
        Layout.fillHeight: true
        implicitHeight: calendar.implicitHeight + padding * 2
        padding: Appearance.padding.larger

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
        implicitHeight: resources.implicitHeight + headerHeight + padding
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
        implicitHeight: media.implicitHeight + padding * 2
        padding: Appearance.padding.larger

        Media {
            id: media

            anchors.fill: parent
            visibilities: root.visibilities
        }
    }
}
