import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Templates

Slider {
    id: root

    // Sliders have no visible label of their own; the owning row sets
    // this so the control is named for assistive tech.
    property string accessibleName: ""

    Accessible.role: Accessible.Slider
    Accessible.name: root.accessibleName

    onActiveFocusChanged: {
        if (activeFocus)
            FocusMode.reportFocus(root.pressed);
    }
    Keys.onTabPressed: event => FocusMode.handleTab(root, event, false)
    Keys.onBacktabPressed: event => FocusMode.handleTab(root, event, true)

    // Fill and thumb colours. Settings sliders keep the signal accent; the bar
    // overrides them with ink so amber only marks a live interaction.
    property color fillColour: Signal.palette.signal
    property color thumbColour: Signal.palette.signal
    // Rule track (Cockpit Clear, shell#536): a 1 px line with square ends and a
    // slim thumb instead of the capsule track, so the glyph halo stays light.
    property bool ruleTrack: false

    opacity: root.enabled ? 1 : 0.5

    background: Item {
        StyledRect {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: root.ruleTrack ? (root.implicitHeight - 1) / 2 : root.implicitHeight / 3
            anchors.bottomMargin: root.ruleTrack ? (root.implicitHeight - 1) / 2 : root.implicitHeight / 3

            implicitWidth: root.handle.x - root.implicitHeight / 6

            color: root.fillColour
            radius: root.ruleTrack ? 0 : Appearance.rounding.small
            topRightRadius: root.ruleTrack ? 0 : root.implicitHeight / 15
            bottomRightRadius: root.ruleTrack ? 0 : root.implicitHeight / 15
        }

        StyledRect {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.topMargin: root.ruleTrack ? (root.implicitHeight - 1) / 2 : root.implicitHeight / 3
            anchors.bottomMargin: root.ruleTrack ? (root.implicitHeight - 1) / 2 : root.implicitHeight / 3

            implicitWidth: parent.width - root.handle.x - root.handle.implicitWidth - root.implicitHeight / 6

            color: Signal.palette.lifted
            radius: root.ruleTrack ? 0 : Appearance.rounding.small
            topLeftRadius: root.ruleTrack ? 0 : root.implicitHeight / 15
            bottomLeftRadius: root.ruleTrack ? 0 : root.implicitHeight / 15
        }
    }

    handle: StyledRect {
        x: root.visualPosition * root.availableWidth - implicitWidth / 2

        implicitWidth: root.ruleTrack ? 2 : root.implicitHeight / 4.5
        implicitHeight: root.implicitHeight

        color: root.thumbColour
        radius: Appearance.rounding.small

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
        }
    }
    FocusRing {
        radius: Appearance.rounding.small
    }
}
