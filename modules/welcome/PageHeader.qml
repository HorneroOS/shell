import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Shared header for Welcome pages: a glyph tile, the title in Plex Sans
// Condensed and a short subtitle, left-aligned with the cards below.
// Callers pass already-translated strings (qsTr at the call site).
RowLayout {
    id: root

    required property string icon
    required property string title
    required property string subtitle

    Layout.fillWidth: true
    Layout.bottomMargin: Appearance.spacing.small
    spacing: Appearance.spacing.large

    Rectangle {
        Layout.alignment: Qt.AlignTop
        implicitWidth: 56
        implicitHeight: 56
        radius: Appearance.rounding.small
        color: Signal.palette.sunken
        border.width: 1
        border.color: Signal.palette.rule

        Glyph {
            anchors.centerIn: parent

            name: root.icon
            color: Signal.palette.signal
            font.pointSize: Appearance.font.size.extraLarge
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.small

        StyledText {
            Layout.fillWidth: true

            text: root.title
            font.family: Appearance.font.family.display
            font.pointSize: Appearance.font.size.extraLarge
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            Layout.maximumWidth: 640

            text: root.subtitle
            color: Signal.palette.inkMuted
            wrapMode: Text.WordWrap
        }
    }
}
