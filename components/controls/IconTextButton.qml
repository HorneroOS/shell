import ".."
import qs.components.controls
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    enum Type {
        Filled,
        Tonal,
        Text
    }

    property alias icon: iconLabel.name
    property alias text: label.text
    property bool checked
    property bool toggle

    Accessible.role: Accessible.Button
    Accessible.name: label.text
    property real horizontalPadding: Appearance.padding.normal
    property real verticalPadding: Appearance.padding.smaller
    property alias font: label.font
    property int type: IconTextButton.Filled

    property alias stateLayer: stateLayer
    property alias iconLabel: iconLabel
    property alias label: label

    property bool internalChecked
    property color activeColour: type === IconTextButton.Filled ? Signal.palette.signal : Signal.palette.cue
    property color inactiveColour: type === IconTextButton.Filled ? Signal.tPalette.panel : Signal.palette.cueWell
    property color activeOnColour: type === IconTextButton.Filled ? Signal.palette.onSignal : Signal.palette.onCue
    property color inactiveOnColour: type === IconTextButton.Filled ? Signal.palette.ink : Signal.palette.onCueWell

    signal clicked

    onCheckedChanged: internalChecked = checked

    radius: internalChecked ? Appearance.rounding.small : implicitHeight / 2 * Math.min(1, Appearance.rounding.scale)
    color: type === IconTextButton.Text ? "transparent" : internalChecked ? activeColour : inactiveColour

    implicitWidth: row.implicitWidth + horizontalPadding * 2
    implicitHeight: row.implicitHeight + verticalPadding * 2

    Interactive {
        id: stateLayer

        color: root.internalChecked ? root.activeOnColour : root.inactiveOnColour

        function onClicked(): void {
            if (root.toggle)
                root.internalChecked = !root.internalChecked;
            root.clicked();
        }
    }

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.spacing.small

        Glyph {
            id: iconLabel

            Layout.alignment: Qt.AlignVCenter
            Layout.topMargin: Math.round(fontInfo.pointSize * 0.0575)
            color: root.internalChecked ? root.activeOnColour : root.inactiveOnColour
        }

        StyledText {
            id: label

            Layout.alignment: Qt.AlignVCenter
            Layout.topMargin: -Math.round(iconLabel.fontInfo.pointSize * 0.0575)
            color: root.internalChecked ? root.activeOnColour : root.inactiveOnColour
        }
    }

    Behavior on radius {
        Anim {}
    }
}
