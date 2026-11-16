import QtQuick
import QtQuick.Controls

// Signal text input: a `sunken` well with a 1 px `ruleStrong` outline
// (control boundary, 3:1), `ink` text, `inkMuted` placeholder, a 2 px
// `focus` underline while focused and the keyboard focus ring. `mono:
// true` sets Plex Mono with tabular figures for expressions, numbers
// and codes.
TextField {
    id: root

    property string tooltipText: ""
    property string accessibleName: root.placeholderText
    property bool mono: false

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.EditableText
    Accessible.description: root.tooltipText

    activeFocusOnTab: enabled
    hoverEnabled: enabled

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
    font.features: ({
            "tnum": 1
        })
    leftPadding: Theme.padding.normal
    rightPadding: Theme.padding.normal
    topPadding: Theme.padding.smaller
    bottomPadding: Theme.padding.smaller

    background: Rectangle {
        implicitWidth: 200
        implicitHeight: 30
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
