import qs.components
import qs.services
import qs.config
import qs.utils
import QtQuick
import QtQuick.Layouts

// Weather module. Shows what the weather service has; with no location or
// no forecast it says so instead of drawing placeholder numbers.
Item {
    id: root

    readonly property bool live: Weather.ready

    Component.onCompleted: Weather.reload()

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.spacing.large

        Glyph {
            Layout.alignment: Qt.AlignVCenter

            name: Weather.icon
            color: Weather.lastError && !root.live ? Signal.palette.alert : root.live ? Signal.palette.cue : Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.display * 0.8
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: Appearance.spacing.small

            StyledText {
                text: root.live ? Weather.temp : "\u2014"
                color: root.live ? Signal.palette.ink : Signal.palette.inkMuted
                font.family: Appearance.font.family.display
                font.weight: Font.Medium
                font.pointSize: Appearance.font.size.extraLarge * 1.3
            }

            StyledText {
                Layout.fillWidth: true

                text: root.live ? Weather.description : Weather.lastError ? qsTr("Weather unavailable") : qsTr("Set a location in Settings")
                color: Signal.palette.inkMuted
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }
}
