import qs.components
import qs.services
import qs.config
import QtQuick

// Clock module: Plex Sans Condensed Medium numerals (the lock-screen
// face, signal-visual-language §4.1), date in Plex Mono. The separator is
// a static colon — nothing blinks.
Item {
    id: root

    implicitHeight: face.implicitHeight

    Column {
        id: face

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.spacing.small

        Row {
            spacing: 2

            StyledText {
                text: Time.hourStr
                font.family: Appearance.font.family.display
                font.weight: Font.Medium
                font.pointSize: Appearance.font.size.display * 0.85
                font.letterSpacing: -Appearance.font.size.display * 0.85 * 0.015
                font.features: {
                    "tnum": 1
                }
            }

            StyledText {
                text: ":"
                color: Signal.palette.inkMuted
                font.family: Appearance.font.family.display
                font.weight: Font.Medium
                font.pointSize: Appearance.font.size.display * 0.85
                font.letterSpacing: -Appearance.font.size.display * 0.85 * 0.015
            }

            StyledText {
                text: Time.minuteStr
                font.family: Appearance.font.family.display
                font.weight: Font.Medium
                font.pointSize: Appearance.font.size.display * 0.85
                font.letterSpacing: -Appearance.font.size.display * 0.85 * 0.015
                font.features: {
                    "tnum": 1
                }
            }

            StyledText {
                anchors.baseline: parent.children[0].baseline
                visible: Config.services.useTwelveHourClock
                leftPadding: Appearance.spacing.small
                mono: true
                text: Time.amPmStr
                color: Signal.palette.inkMuted
                font.pointSize: Appearance.font.size.normal
            }
        }

        StyledText {
            mono: true
            text: Time.format("dddd d MMMM yyyy")
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Appearance.font.size.small * 0.08
        }
    }
}
