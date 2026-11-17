import qs.components
import qs.services
import qs.config
import qs.modules.instruments as Instruments
import QtQuick
import QtQuick.Layouts

// Lock weather footer: icon, temperature, condition. Only shown while the
// weather service has a forecast; no placeholder when it has none.
RowLayout {
    id: root

    spacing: Appearance.spacing.normal

    Glyph {
        Layout.alignment: Qt.AlignVCenter

        name: Weather.icon
        color: Signal.palette.cue
        font.pointSize: Appearance.font.size.extraLarge
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        StyledText {
            text: Weather.temp
            font.family: Appearance.font.family.display
            font.weight: Font.Medium
            font.pointSize: Appearance.font.size.large
        }

        StyledText {
            Layout.fillWidth: true

            text: Weather.description
            color: Signal.palette.inkMuted
            font.pointSize: Appearance.font.size.small
            elide: Text.ElideRight
        }
    }

    Instruments.Eyebrow {
        Layout.alignment: Qt.AlignTop

        label: Weather.city
    }
}
