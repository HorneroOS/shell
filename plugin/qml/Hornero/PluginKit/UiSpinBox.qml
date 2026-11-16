import QtQuick
import QtQuick.Controls

// Signal numeric stepper: a tabular Plex Mono value in a `sunken` well
// between two square step buttons. Arrow keys and PageUp/PageDown work
// natively; Enter commits an edited value.
SpinBox {
    id: root

    property string tooltipText: ""
    property string accessibleName: ""

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.SpinBox
    Accessible.description: root.tooltipText

    activeFocusOnTab: enabled
    hoverEnabled: enabled
    editable: true

    UiTooltip {
        target: root
        text: root.tooltipText
    }

    font.family: Theme.font.family.mono
    font.pointSize: Theme.font.size.smaller
    implicitHeight: 30
    topPadding: 0
    bottomPadding: 0
    leftPadding: 32
    rightPadding: 32

    contentItem: TextInput {
        z: 2
        text: root.displayText
        font: root.font
        color: root.enabled ? Theme.palette.ink : Theme.palette.inkFaint
        selectionColor: Theme.palette.cueWell
        selectedTextColor: Theme.palette.onCueWell
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !root.editable
        validator: root.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
    }

    up.indicator: Rectangle {
        x: root.mirrored ? 0 : root.width - width
        height: root.height
        implicitWidth: 28
        implicitHeight: 30
        radius: Theme.rounding.small
        color: root.up.pressed ? Theme.palette.lifted : root.up.hovered ? Theme.palette.raised : Theme.palette.panel
        border.width: 1
        border.color: Theme.palette.ruleStrong

        UiIcon {
            anchors.centerIn: parent
            name: "plus"
            size: Theme.font.size.normal
            color: root.enabled ? Theme.palette.ink : Theme.palette.inkFaint
        }
    }

    down.indicator: Rectangle {
        x: root.mirrored ? root.width - width : 0
        height: root.height
        implicitWidth: 28
        implicitHeight: 30
        radius: Theme.rounding.small
        color: root.down.pressed ? Theme.palette.lifted : root.down.hovered ? Theme.palette.raised : Theme.palette.panel
        border.width: 1
        border.color: Theme.palette.ruleStrong

        UiIcon {
            anchors.centerIn: parent
            name: "minus"
            size: Theme.font.size.normal
            color: root.enabled ? Theme.palette.ink : Theme.palette.inkFaint
        }
    }

    background: Rectangle {
        implicitWidth: 120
        implicitHeight: 30
        radius: Theme.rounding.small
        color: Theme.palette.sunken
        border.width: 1
        border.color: root.activeFocus ? Theme.palette.ink : Theme.palette.ruleStrong

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.rounding.small + 2
            color: "transparent"
            border.width: 2
            border.color: Theme.palette.focus
            visible: root.activeFocus && Theme.keyboardFocus && root.enabled
        }
    }
}
