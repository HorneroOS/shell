import ".."
import qs.components.controls
import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    enum Type {
        Filled,
        Tonal,
        Text
    }

    property alias text: label.text
    property bool checked
    property bool toggle
    property bool disabled
    property real horizontalPadding: Appearance.padding.normal
    property real verticalPadding: Appearance.padding.smaller
    property alias font: label.font
    property int type: TextButton.Filled

    Accessible.role: Accessible.Button
    Accessible.name: label.text

    property alias stateLayer: stateLayer
    property alias label: label

    property bool internalChecked
    property color activeColour: type === TextButton.Filled ? Signal.palette.signal : Signal.palette.signalWell
    property color inactiveColour: {
        if (!toggle && type === TextButton.Filled)
            return Signal.palette.signal;
        return type === TextButton.Filled ? Signal.tPalette.panel : Signal.palette.cueWell;
    }
    property color activeOnColour: {
        if (type === TextButton.Text)
            return Signal.palette.signal;
        return type === TextButton.Filled ? Signal.palette.onSignal : Signal.palette.onSignalWell;
    }
    property color inactiveOnColour: {
        if (!toggle && type === TextButton.Filled)
            return Signal.palette.onSignal;
        if (type === TextButton.Text)
            return Signal.palette.signal;
        return type === TextButton.Filled ? Signal.palette.ink : Signal.palette.onCueWell;
    }

    signal clicked

    onCheckedChanged: internalChecked = checked

    // Signal Bezel: rectangular channel cells, radius `small` in every
    // state — no pill morph between checked and unchecked.
    radius: Appearance.rounding.small
    color: type === TextButton.Text ? "transparent" : internalChecked ? activeColour : inactiveColour
    opacity: root.disabled ? 0.5 : 1

    implicitWidth: label.implicitWidth + horizontalPadding * 2
    implicitHeight: label.implicitHeight + verticalPadding * 2

    Interactive {
        id: stateLayer

        color: root.internalChecked ? root.activeOnColour : root.inactiveOnColour
        disabled: root.disabled

        function onClicked(): void {
            if (root.toggle)
                root.internalChecked = !root.internalChecked;
            root.clicked();
        }
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        color: root.internalChecked ? root.activeOnColour : root.inactiveOnColour
    }

    Behavior on radius {
        Anim {}
    }
}
