import qs.components
import qs.services
import qs.config
import QtQuick

// One physical-looking key: the keybinding overlay, Control Center >
// Keybinds and the Welcome cheatsheet share this treatment.
StyledRect {
    id: root

    required property string text
    property bool accent: false
    property bool compact: false

    implicitWidth: capLabel.implicitWidth + (compact ? 10 : 16)
    implicitHeight: capLabel.implicitHeight + (compact ? 4 : 8)

    color: accent ? Signal.palette.signalWell : Signal.palette.lifted
    radius: Appearance.rounding.small
    border.width: 1
    border.color: accent ? Signal.palette.signal : Signal.palette.rule

    // A soft "pressed key" shadow line: cozy, physical, not flat.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        height: 2
        radius: 1 // fixed: 2 px key-shadow hairline, not a corner style
        color: root.accent ? Signal.palette.signal : Signal.palette.ruleStrong
        opacity: 0.55
    }

    StyledText {
        id: capLabel

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -1
        text: root.text
        mono: true
        font.pointSize: Appearance.font.size.smaller
        font.weight: Appearance.font.weight.strong
        color: root.accent ? Signal.palette.onSignalWell : Signal.palette.ink
    }
}
