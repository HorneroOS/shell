pragma ComponentBehavior: Bound

import Quickshell
import qs.components
import qs.services
import qs.config
import qs.modules.plugins
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    // Region tone: the plain Signal palette, or per-region ink on Cockpit Clear.
    property var tone: ClearInk.neutral

    required property ShellScreen screen

    property color colour: root.tone.ink
    // Orientation of the owning bar (set by Bar.qml); defaults to the
    // primary bar for standalone use.
    property bool vertical: Config.bar.isVerticalFor(screen.name)
    // Per-entry options (docs/LAYOUTS.md): showDate overrides the global
    // bar.clock.showDate for this layout.
    property var options: ({})
    readonly property bool showDate: typeof options?.showDate === "boolean" ? options.showDate : Config.bar.clock.showDate
    // Clean typography (Sans): the time is the same face as every other
    // value, one step larger; the Signal face is Plex Sans Condensed Medium.
    readonly property string timeFamily: Density.clean ? Appearance.font.family.sans : Appearance.font.family.display
    readonly property int timeWeight: Density.clean ? Density.textWeight : Font.Medium

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    StyledRect {
        visible: Config.bar.clock.background && !root.vertical && !root.tone.active
        anchors.fill: parent
        anchors.margins: -Appearance.padding.normal
        color: Signal.tPalette.panel
        radius: Appearance.rounding.small
    }

    GridLayout {
        id: layout

        anchors.centerIn: parent

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rows: root.vertical ? -1 : 1
        columns: root.vertical ? 1 : -1
        rowSpacing: Appearance.spacing.small
        columnSpacing: Appearance.spacing.small

        Loader {
            Layout.alignment: Qt.AlignCenter

            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: Glyph {
                size: Density.iconPt
                name: "clock"
                color: root.colour
            }
        }

        // Time (signal-visual-language §4.1): IBM Plex Sans Condensed Medium
        // 18, tabular figures. Hours and minutes sit in fixed-width cells so
        // the clock never changes width between "11:11" and "10:00".
        RowLayout {
            Layout.alignment: Qt.AlignCenter
            spacing: 1

            visible: !root.vertical

            TextMetrics {
                id: hourMetrics

                text: "00"
                font.pointSize: Density.clockPt
                font.family: root.timeFamily
                font.weight: root.timeWeight
                font.features: {
                    "tnum": 1
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignBaseline

                text: Time.hourStr
                font.pointSize: Density.clockPt
                font.family: root.timeFamily
                font.weight: root.timeWeight
                font.features: {
                    "tnum": 1
                }
                color: root.colour
                Layout.preferredWidth: hourMetrics.width
                horizontalAlignment: StyledText.AlignRight
            }

            StyledText {
                Layout.alignment: Qt.AlignBaseline
                text: ":"
                font.pointSize: Density.clockPt
                font.family: root.timeFamily
                font.weight: root.timeWeight
                color: root.colour
            }

            StyledText {
                Layout.alignment: Qt.AlignBaseline

                text: Time.minuteStr
                font.pointSize: Density.clockPt
                font.family: root.timeFamily
                font.weight: root.timeWeight
                font.features: {
                    "tnum": 1
                }
                color: root.colour
                Layout.preferredWidth: hourMetrics.width
                horizontalAlignment: StyledText.AlignLeft
            }

            BarText {
                Layout.leftMargin: Appearance.spacing.small / 2
                Layout.alignment: Qt.AlignBaseline
                visible: Config.services.useTwelveHourClock
                role: "label"
                text: Density.clean ? Time.amPmStr.toLowerCase() : Time.amPmStr
                color: root.tone.inkMuted
            }

            // Date: `inkMuted` after the time, on the time's baseline. Mono
            // type is upper case ("TUE 17 NOV"); clean type is sentence case.
            BarText {
                Layout.alignment: Qt.AlignBaseline
                Layout.leftMargin: Appearance.spacing.small
                visible: root.showDate

                role: "label"
                text: Density.clean ? Time.format("ddd d MMM") : Time.format("ddd d MMM").toUpperCase()
                color: root.tone.inkMuted
            }
        }

        // Keep a rail clock compact: the meridiem shares the minute row
        // instead of stretching the clock to a third full-size line.
        ColumnLayout {
            Layout.alignment: Qt.AlignCenter
            visible: root.vertical
            spacing: 0

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.hourStr
                font.pointSize: Density.textPt
                font.family: Appearance.font.family.mono
                color: root.colour
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Time.minuteStr
                font.pointSize: Density.textPt
                font.family: Appearance.font.family.mono
                color: root.colour
            }

            // Stacked under the minutes: a rail is too narrow for "14 AM".
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: Config.services.useTwelveHourClock && Time.amPmStr !== ""
                text: Time.amPmStr
                font.pointSize: Density.microPt
                font.family: Appearance.font.family.mono
                color: root.tone.inkMuted
            }
        }

        // Extension indicators that join this island (shell#439): same
        // icon colour and size as the native items around them.
        PluginBarWidgets {
            vertical: root.vertical
            section: "clock"
            iconColour: root.colour
            iconSize: Density.iconPt
            textSize: Density.textPt
            thickness: Density.inner
            screenName: root.screen.name
        }
    }
}
