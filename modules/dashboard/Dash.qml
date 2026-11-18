pragma ComponentBehavior: Bound

import qs.components
import qs.components.filedialog
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import "dash"
import Quickshell
import QtQuick
import QtQuick.Layouts

// Dashboard home (Signal Bezel): an instrument panel, not a card grid.
// Every module is a `panel` frame with a 1 px `rule` border and radius
// `small`, labelled by an eyebrow with its channel number, bound to real
// services only (clock, weather, system usage, MPRIS). Radii stay 3 in
// every composition: hierarchy comes from size and position.
//
// dashboard.composition (Control Center > Dashboard > Layout):
//
//   console (default)                     classic
//   CLOCK (wide) | STATION   | DECK       STATION  | CLOCK     | WEATHER
//   CALENDAR     | RESOURCES | (tall)     CALENDAR | RESOURCES
//   WEATHER strip            |            MEDIA strip
//
//   compact: the classic grid without the media row.
//
// Children are declared in reading order so keyboard focus follows it.
Item {
    id: root

    required property PersistentProperties visibilities
    required property PersistentProperties state
    required property FileDialog facePicker

    readonly property string composition: ["console", "classic", "compact"].includes(Config.dashboard.composition) ? Config.dashboard.composition : "console"
    readonly property int gap: Appearance.spacing.normal

    implicitWidth: layout.item?.implicitWidth ?? 0
    implicitHeight: layout.item?.implicitHeight ?? 0

    Loader {
        id: layout

        anchors.fill: parent
        sourceComponent: root.composition === "console" ? consoleLayout : gridLayout
    }

    // --- console: wide clock, tall deck hero, thin weather strip ----------
    Component {
        id: consoleLayout

        GridLayout {
            readonly property int clockWidth: 336
            readonly property int stationWidth: 296
            readonly property int deckWidth: 320

            columns: 3
            rowSpacing: root.gap
            columnSpacing: root.gap

            Instruments.Frame {
                Layout.row: 0
                Layout.column: 0
                Layout.preferredWidth: parent.clockWidth
                Layout.fillHeight: true
                implicitHeight: 148
                channel: "01"
                title: qsTr("Clock")

                DateTime {
                    anchors.fill: parent
                    graduations: true
                }
            }

            Instruments.Frame {
                Layout.row: 0
                Layout.column: 1
                Layout.preferredWidth: parent.stationWidth
                Layout.fillHeight: true
                implicitHeight: user.implicitHeight + headerHeight + 12
                channel: "02"
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
                Layout.column: 2
                Layout.rowSpan: 3
                Layout.preferredWidth: parent.deckWidth
                Layout.fillHeight: true
                implicitHeight: deck.implicitHeight + headerHeight + 16
                channel: "03"
                title: qsTr("Deck")
                context: deck.hasPlayer ? Players.getIdentity(deck.player) : qsTr("No player")

                Media {
                    id: deck

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    layout: "tower"
                    visibilities: root.visibilities
                }
            }

            Instruments.Frame {
                Layout.row: 1
                Layout.column: 0
                Layout.preferredWidth: parent.clockWidth
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
                Layout.preferredWidth: parent.stationWidth
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

            // Thin weather strip: the eyebrow sits inline, no header row.
            Instruments.Frame {
                Layout.row: 2
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                implicitHeight: 52
                padding: 10

                RowLayout {
                    anchors.fill: parent
                    spacing: Appearance.spacing.normal

                    Instruments.Eyebrow {
                        Layout.alignment: Qt.AlignVCenter
                        channel: "05"
                        label: qsTr("Weather")
                    }

                    Weather {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        strip: true
                    }

                    Instruments.Eyebrow {
                        Layout.alignment: Qt.AlignVCenter
                        visible: Weather.ready
                        label: Weather.ready ? Weather.city : ""
                    }
                }
            }
        }
    }

    // --- classic (the previous home grid) and compact (no media row) ------
    Component {
        id: gridLayout

        GridLayout {
            readonly property int leftWidth: 296
            readonly property int midWidth: 336
            readonly property int rightWidth: 320

            columns: 3
            rowSpacing: root.gap
            columnSpacing: root.gap

            Instruments.Frame {
                Layout.row: 0
                Layout.column: 0
                Layout.preferredWidth: parent.leftWidth
                Layout.fillHeight: true
                implicitHeight: gridUser.implicitHeight + headerHeight + 12
                channel: "01"
                title: qsTr("Station")

                User {
                    id: gridUser

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
                Layout.preferredWidth: parent.midWidth
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
                Layout.preferredWidth: parent.rightWidth
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
                Layout.preferredWidth: parent.leftWidth
                Layout.fillHeight: true
                implicitHeight: gridCalendar.implicitHeight + 24
                padding: 12

                Calendar {
                    id: gridCalendar

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
                implicitHeight: gridResources.implicitHeight + headerHeight + 16
                channel: "04"
                title: qsTr("Resources")
                context: gridResources.windowLabel

                Resources {
                    id: gridResources

                    anchors.left: parent.left
                    anchors.right: parent.right
                }
            }

            Instruments.Frame {
                Layout.row: 2
                Layout.column: 0
                Layout.columnSpan: 3
                Layout.fillWidth: true
                visible: root.composition !== "compact"
                implicitHeight: 76
                padding: 10

                Media {
                    anchors.fill: parent
                    layout: "strip"
                    visibilities: root.visibilities
                }
            }
        }
    }
}
