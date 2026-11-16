import qs.components
import qs.services
import qs.config
import QtQuick

// Live state (Signal Bezel §4.1): Plex Mono 11 SemiBold uppercase
// `onSignal` on a `signal` fill, radius 3, padding 4 × 6. Static; shown
// only while the state it names is real.
Rectangle {
    id: root

    property alias text: label.text
    property color fill: Signal.palette.signal
    property color ink: Signal.palette.onSignal

    implicitWidth: label.implicitWidth + 12
    implicitHeight: label.implicitHeight + 6
    radius: Appearance.rounding.small
    color: root.fill

    StyledText {
        id: label

        anchors.centerIn: parent
        mono: true
        color: root.ink
        font.pointSize: Appearance.font.size.small
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: Appearance.font.size.small * 0.06
    }
}
