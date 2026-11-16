pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    anchors.top: parent.top
    anchors.bottom: parent.bottom
    implicitWidth: Config.dashboard.sizes.dateTimeWidth

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        StyledText {
            Layout.bottomMargin: -(font.pointSize * 0.4)
            Layout.alignment: Qt.AlignHCenter
            text: Time.hourStr
            color: Signal.palette.cue
            font.pointSize: Appearance.font.size.extraLarge
            font.family: Appearance.font.family.display
            font.weight: 600
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "•••"
            color: Signal.palette.signal
            font.pointSize: Appearance.font.size.extraLarge * 0.9
            font.family: Appearance.font.family.display
        }

        StyledText {
            Layout.topMargin: -(font.pointSize * 0.4)
            Layout.alignment: Qt.AlignHCenter
            text: Time.minuteStr
            color: Signal.palette.cue
            font.pointSize: Appearance.font.size.extraLarge
            font.family: Appearance.font.family.display
            font.weight: 600
        }

        Loader {
            Layout.alignment: Qt.AlignHCenter

            active: Config.services.useTwelveHourClock
            visible: active

            sourceComponent: StyledText {
                text: Time.amPmStr
                color: Signal.palette.signal
                font.pointSize: Appearance.font.size.large
                font.family: Appearance.font.family.display
                font.weight: 600
            }
        }
    }
}
