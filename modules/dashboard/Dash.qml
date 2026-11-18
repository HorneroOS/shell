pragma ComponentBehavior: Bound

import qs.components
import qs.components.filedialog
import qs.components.motion
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
// Rack rhythm (signal-visual-language §7.1): 8 inside a module, 12 between
// modules, 16 surface inset, 24 section break. Every gap and inset here is
// a spacing/padding token, so Appearance > Scales > Density (Compact, Cosy,
// Airy) moves the whole panel together. Only sizes (column widths) are
// literal; frame heights are content implicitHeight plus tokens.
//
// dashboard.composition (Control Center > Dashboard > Layout):
//
//   console (default)                     classic
//   CLOCK        | STATION   | DECK       STATION  | CLOCK     | WEATHER
//   CALENDAR     | RESOURCES | (tall)     CALENDAR | RESOURCES
//   WEATHER strip            |            MEDIA strip
//
//   compact: the classic grid without the media row.
//
// Frames are declared in reading order, so keyboard focus and the
// staggered reveal both follow it.
Item {
    id: root

    required property PersistentProperties visibilities
    required property PersistentProperties state
    required property FileDialog facePicker

    readonly property string composition: ["console", "classic", "compact"].includes(Config.dashboard.composition) ? Config.dashboard.composition : "console"

    implicitWidth: layout.item?.implicitWidth ?? 0
    implicitHeight: layout.item?.implicitHeight ?? 0

    // Staggered reveal (§11.1 rule 2): on every open the frames scan in
    // from the bar side, 60 ms after the sheet and 24 ms apart, in reading
    // order. Input is live from the first frame; off/reduced skip it. A
    // composition switch reveals the new layout the same way.
    function reveal(): void {
        if (root.visible && root.visibilities.dashboard && layout.item)
            stagger.play(layout.item);
    }

    Component.onCompleted: Qt.callLater(root.reveal)

    Connections {
        target: root.visibilities

        function onDashboardChanged(): void {
            if (root.visibilities.dashboard)
                Qt.callLater(root.reveal);
            else
                stagger.stop();
        }
    }

    Stagger {
        id: stagger

        dx: 0
        dy: 1
    }

    Loader {
        id: layout

        anchors.fill: parent
        sourceComponent: root.composition === "console" ? consoleLayout : gridLayout
        onLoaded: Qt.callLater(root.reveal)
    }

    // --- console: clock with seconds ruler, tall deck hero, weather strip --
    Component {
        id: consoleLayout

        GridLayout {
            id: grid

            // The middle column carries the resources scope, which needs the
            // room; the deck hero is tall rather than wide.
            readonly property int clockWidth: 336
            readonly property int stationWidth: 404
            readonly property int deckWidth: 300

            columns: 3
            rowSpacing: Appearance.spacing.normal
            columnSpacing: Appearance.spacing.normal

            Instruments.Frame {
                Layout.row: 0
                Layout.column: 0
                Layout.preferredWidth: grid.clockWidth
                Layout.fillHeight: true
                implicitHeight: dateTime.implicitHeight + headerHeight + padding
                channel: "01"
                title: qsTr("Clock")

                DateTime {
                    id: dateTime

                    anchors.fill: parent
                    graduations: true
                }
            }

            Instruments.Frame {
                Layout.row: 0
                Layout.column: 1
                Layout.preferredWidth: grid.stationWidth
                Layout.fillHeight: true
                implicitHeight: user.implicitHeight + headerHeight + Appearance.padding.larger
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
                Layout.preferredWidth: grid.deckWidth
                Layout.fillHeight: true
                implicitHeight: deck.implicitHeight + headerHeight + padding
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
                Layout.preferredWidth: grid.clockWidth
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
                Layout.preferredWidth: grid.stationWidth
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

            // Thin weather strip: the eyebrow sits inline, no header row.
            Instruments.Frame {
                Layout.row: 2
                Layout.column: 0
                Layout.columnSpan: 2
                Layout.fillWidth: true
                implicitHeight: stripRow.implicitHeight + padding * 2
                padding: Appearance.padding.larger

                RowLayout {
                    id: stripRow

                    anchors.fill: parent
                    spacing: Appearance.spacing.normal

                    Instruments.Eyebrow {
                        Layout.alignment: Qt.AlignVCenter
                        channel: "05"
                        label: qsTr("Weather")
                    }

                    Weather {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
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

    // --- classic (the earlier home grid) and compact (no media row) -------
    Component {
        id: gridLayout

        GridLayout {
            id: grid

            readonly property int leftWidth: 296
            readonly property int midWidth: 336
            readonly property int rightWidth: 320
            // Top-row content height: the taller of the clock face and the
            // weather readout, so the row grows with font and density.
            readonly property real topRowContent: Math.max(gridDateTime.implicitHeight, gridWeather.implicitHeight)

            columns: 3
            rowSpacing: Appearance.spacing.normal
            columnSpacing: Appearance.spacing.normal

            Instruments.Frame {
                Layout.row: 0
                Layout.column: 0
                Layout.preferredWidth: grid.leftWidth
                Layout.fillHeight: true
                implicitHeight: gridUser.implicitHeight + headerHeight + Appearance.padding.larger
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
                Layout.preferredWidth: grid.midWidth
                Layout.fillHeight: true
                implicitHeight: grid.topRowContent + headerHeight + padding
                channel: "02"
                title: qsTr("Clock")

                DateTime {
                    id: gridDateTime

                    anchors.fill: parent
                }
            }

            Instruments.Frame {
                Layout.row: 0
                Layout.column: 2
                Layout.preferredWidth: grid.rightWidth
                Layout.fillHeight: true
                implicitHeight: grid.topRowContent + headerHeight + padding
                channel: "03"
                title: qsTr("Weather")
                context: Weather.ready ? Weather.city : ""

                Weather {
                    id: gridWeather

                    anchors.fill: parent
                }
            }

            Instruments.Frame {
                Layout.row: 1
                Layout.column: 0
                Layout.preferredWidth: grid.leftWidth
                Layout.fillHeight: true
                implicitHeight: gridCalendar.implicitHeight + padding * 2
                padding: Appearance.padding.larger

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
                implicitHeight: gridResources.implicitHeight + headerHeight + padding
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
                implicitHeight: gridMedia.implicitHeight + padding * 2
                padding: Appearance.padding.larger

                // Not even created in compact, so it holds no sampler there.
                Loader {
                    id: gridMedia

                    anchors.fill: parent
                    active: root.composition !== "compact"

                    sourceComponent: Media {
                        layout: "strip"
                        visibilities: root.visibilities
                    }
                }
            }
        }
    }
}
