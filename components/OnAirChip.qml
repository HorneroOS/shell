import qs.services
import qs.config
import QtQuick

// On-air chip (signal-visual-language §4.1): mic, camera, screen share and
// recording tallies. Plex Mono 11 SemiBold uppercase `onSignal` on a
// `signal` fill, radius 3, 18 px tall. Static — shown only while the
// capture is real and active; the caller binds `visible` to the source.
Rectangle {
    id: root

    property string text: ""
    property string icon: ""

    implicitWidth: row.implicitWidth + 12
    implicitHeight: 18
    radius: Appearance.rounding.small
    color: Signal.palette.signal

    Accessible.role: Accessible.StaticText
    Accessible.name: root.text

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon.length > 0
            name: root.icon
            size: Appearance.font.size.small
            color: Signal.palette.onSignal
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            mono: true
            color: Signal.palette.onSignal
            font.pointSize: Appearance.font.size.small
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Appearance.font.size.small * 0.08
        }
    }
}
