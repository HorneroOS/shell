import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

// Header for a connection (network, VPN, device): glyph and name on one
// line over a hairline. Same anatomy as SettingsHeader.
ColumnLayout {
    id: root

    required property string icon
    required property string title

    spacing: Appearance.spacing.small

    RowLayout {
        Layout.fillWidth: true
        spacing: Appearance.spacing.normal

        Glyph {
            animate: true
            name: root.icon
            color: Signal.palette.signal
            font.pointSize: Appearance.font.size.extraLarge
        }

        StyledText {
            Layout.fillWidth: true
            animate: true
            text: root.title
            elide: Text.ElideRight
            font.pointSize: Appearance.font.size.large
            font.weight: Appearance.font.weight.strong
            Accessible.role: Accessible.Heading
        }
    }

    Hairline {
        Layout.fillWidth: true
    }
}
