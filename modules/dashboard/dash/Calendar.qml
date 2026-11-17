pragma ComponentBehavior: Bound

import qs.components
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Month sheet: rectangular day cells on a fixed grid. Today is a filled
// `signal` cell (plus its numeral turns `onSignal`), weekends use `cue`,
// days from neighbouring months are dimmed. Wheel pages months, a middle
// click returns to today.
CustomMouseArea {
    id: root

    required property var state

    readonly property int currMonth: state.currentDate.getMonth()
    readonly property int currYear: state.currentDate.getFullYear()
    readonly property alias title: grid.title

    implicitHeight: inner.implicitHeight

    acceptedButtons: Qt.MiddleButton
    onClicked: root.state.currentDate = new Date()

    function onWheel(event: WheelEvent): void {
        if (event.angleDelta.y > 0)
            root.state.currentDate = new Date(root.currYear, root.currMonth - 1, 1);
        else if (event.angleDelta.y < 0)
            root.state.currentDate = new Date(root.currYear, root.currMonth + 1, 1);
    }

    ColumnLayout {
        id: inner

        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Appearance.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            NavCell {
                glyph: "chevron-left"
                name: qsTr("Previous month")

                function onClicked(): void {
                    root.state.currentDate = new Date(root.currYear, root.currMonth - 1, 1);
                }
            }

            Item {
                Layout.fillWidth: true
                implicitHeight: 28

                StateLayer {
                    anchors.centerIn: parent
                    width: monthYearDisplay.implicitWidth + 24
                    height: parent.height
                    radius: Appearance.rounding.small
                    disabled: {
                        const now = new Date();
                        return root.currMonth === now.getMonth() && root.currYear === now.getFullYear();
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Go to current month")

                    function onClicked(): void {
                        root.state.currentDate = new Date();
                    }
                }

                StyledText {
                    id: monthYearDisplay

                    anchors.centerIn: parent
                    mono: true
                    text: grid.title
                    color: Signal.palette.ink
                    font.pointSize: Appearance.font.size.small
                    font.weight: Font.Medium
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Appearance.font.size.small * 0.08
                }
            }

            NavCell {
                glyph: "chevron-right"
                name: qsTr("Next month")

                function onClicked(): void {
                    root.state.currentDate = new Date(root.currYear, root.currMonth + 1, 1);
                }
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale
            spacing: 2

            delegate: StyledText {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                mono: true
                text: model.shortName.slice(0, 2)
                font.pointSize: Appearance.font.size.small
                color: (model.day === 0 || model.day === 6) ? Signal.palette.cue : Signal.palette.inkMuted
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Signal.palette.rule
        }

        MonthGrid {
            id: grid

            Layout.fillWidth: true

            month: root.currMonth
            year: root.currYear
            spacing: 2
            locale: Qt.locale()

            delegate: Rectangle {
                id: day

                required property var model
                readonly property bool inMonth: model.month === grid.month
                readonly property bool weekend: model.date.getUTCDay() === 0 || model.date.getUTCDay() === 6

                implicitWidth: 32
                implicitHeight: 28
                radius: Appearance.rounding.small
                color: model.today ? Signal.palette.signal : "transparent"

                Accessible.role: Accessible.StaticText
                Accessible.name: day.model.date.toLocaleDateString(grid.locale, "dddd d MMMM") + (day.model.today ? ", " + qsTr("today") : "")

                StyledText {
                    anchors.centerIn: parent

                    mono: true
                    text: grid.locale.toString(day.model.day)
                    color: day.model.today ? Signal.palette.onSignal : !day.inMonth ? Qt.alpha(Signal.palette.inkMuted, 0.55) : day.weekend ? Signal.palette.cue : Signal.palette.ink
                    font.pointSize: Appearance.font.size.small
                    font.weight: day.model.today ? Font.DemiBold : Font.Normal
                    Accessible.ignored: true
                }
            }
        }
    }

    component NavCell: Item {
        id: nav

        required property string glyph
        required property string name

        function onClicked(): void {
        }

        implicitWidth: 32
        implicitHeight: 28

        StateLayer {
            radius: Appearance.rounding.small

            Accessible.role: Accessible.Button
            Accessible.name: nav.name

            function onClicked(): void {
                nav.onClicked();
            }
        }

        Glyph {
            anchors.centerIn: parent

            name: nav.glyph
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.normal
        }
    }
}
