import QtQuick
import QtQuick.Controls

// Signal multi-line text input: the UiTextField well for notes and
// longer text. Wraps at word boundaries; put it in a Flickable or give
// it a fixed height and let it grow for long content.
TextArea {
    id: root

    property string tooltipText: ""
    property string accessibleName: root.placeholderText
    property bool mono: false

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.EditableText
    Accessible.description: root.tooltipText

    activeFocusOnTab: enabled
    hoverEnabled: enabled
    wrapMode: TextEdit.Wrap

    UiTooltip {
        target: root
        text: root.tooltipText
    }

    color: root.enabled ? Theme.palette.ink : Theme.palette.inkFaint
    placeholderTextColor: Theme.palette.inkMuted
    selectionColor: Theme.palette.cueWell
    selectedTextColor: Theme.palette.onCueWell
    font.family: root.mono ? Theme.font.family.mono : Theme.font.family.sans
    font.pointSize: Theme.font.size.smaller
    leftPadding: Theme.padding.normal
    rightPadding: Theme.padding.normal
    topPadding: Theme.padding.normal
    bottomPadding: Theme.padding.normal

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 72
        radius: Theme.rounding.small
        color: Theme.palette.sunken
        border.width: 1
        border.color: !root.enabled ? Theme.palette.rule : root.hovered || root.activeFocus ? Theme.palette.ink : Theme.palette.ruleStrong

        Rectangle {
            visible: root.activeFocus
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 2
            color: Theme.palette.focus
        }

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
