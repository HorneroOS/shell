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
    property alias font: label.font

    Accessible.role: Accessible.Button
    Accessible.name: label.text
    property bool checked
    property bool toggle
    property bool disabled
    property int type: ButtonBase.Filled
    property real horizontalPadding: Appearance.padding.normal
    property real verticalPadding: Appearance.padding.smaller
    property color activeColour: type === ButtonBase.Filled ? Signal.palette.signal : Signal.palette.cue
    property color inactiveColour: type === ButtonBase.Filled ? Signal.tPalette.panel : Signal.palette.cueWell
    property color activeOnColour: type === ButtonBase.Filled ? Signal.palette.onSignal : Signal.palette.onCue
    property color inactiveOnColour: type === ButtonBase.Filled ? Signal.palette.ink : Signal.palette.onCueWell

    signal clicked

    property bool internalChecked
    onCheckedChanged: internalChecked = checked

    radius: internalChecked ? Appearance.rounding.small : implicitHeight / 2 * Math.min(1, Appearance.rounding.scale)
    color: type === ButtonBase.Text ? "transparent" : internalChecked ? activeColour : inactiveColour
    opacity: root.disabled ? 0.5 : 1
    implicitWidth: Math.max(row.implicitWidth + horizontalPadding * 2, implicitHeight)
    implicitHeight: row.implicitHeight + verticalPadding * 2

    property alias stateLayer: stateLayer
    property alias iconLabel: iconLabel
    property alias label: label

    Interactive {
        id: stateLayer

        color: root.internalChecked ? root.activeOnColour : root.inactiveOnColour
        disabled: root.disabled

        onClicked: {
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
            color: root.internalChecked ? root.activeOnColour : root.inactiveOnColour
        }

        StyledText {
            id: label

            Layout.alignment: Qt.AlignVCenter
            color: root.internalChecked ? root.activeOnColour : root.inactiveOnColour
        }
    }

    Behavior on radius {
        Anim {}
    }
}
