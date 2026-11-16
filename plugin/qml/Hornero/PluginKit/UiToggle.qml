import QtQuick
import QtQuick.Controls

// Signal rocker switch: a `sunken` well with a square thumb. Off: thumb
// in `inkMuted` on the leading side; on: `signalWell` well, `signal`
// outline and thumb on the trailing side. The thumb travels with
// `settleFast`; colour changes use `standard`/`quick`.
Switch {
    id: root

    // Two-way synced with `checked`; `toggled()` is inherited.
    property bool value: false
    property string tooltipText: ""
    property string accessibleName: root.text

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.CheckBox
    Accessible.description: root.tooltipText

    activeFocusOnTab: enabled
    hoverEnabled: enabled
    Keys.onReturnPressed: event => {
        if (enabled) {
            root.click();
            event.accepted = true;
        }
    }
    Keys.onEnterPressed: event => {
        if (enabled) {
            root.click();
            event.accepted = true;
        }
    }

    UiTooltip {
        target: root
        text: root.tooltipText
    }

    Component.onCompleted: {
        if (checked !== root.value)
            checked = root.value;
    }
    onValueChanged: {
        if (checked !== root.value)
            checked = root.value;
    }
    onCheckedChanged: {
        if (root.value !== checked)
            root.value = checked;
    }

    spacing: Theme.spacing.smaller

    indicator: Rectangle {
        id: track

        implicitWidth: 34
        implicitHeight: 18
        x: root.leftPadding
        y: parent.height / 2 - height / 2
        radius: Theme.rounding.small
        color: !root.enabled ? Theme.palette.sunken : root.checked ? Theme.palette.signalWell : root.hovered ? Theme.palette.raised : Theme.palette.sunken
        border.width: 1
        border.color: !root.enabled ? Theme.palette.rule : root.checked ? Theme.palette.signal : Theme.palette.ruleStrong

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration("quick")
            }
        }

        Rectangle {
            width: 12
            height: 12
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 3 : 3
            color: !root.enabled ? Theme.palette.inkFaint : root.checked ? Theme.palette.signal : Theme.palette.inkMuted

            Behavior on x {
                NumberAnimation {
                    duration: Theme.duration("settleFast")
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.anim.curves.settleFast
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: Theme.rounding.small + 2
            color: "transparent"
            border.width: 2
            border.color: Theme.palette.focus
            visible: root.activeFocus && Theme.keyboardFocus && root.enabled
        }
    }

    contentItem: Text {
        text: root.text
        color: root.enabled ? Theme.palette.ink : Theme.palette.inkFaint
        font.family: Theme.font.family.sans
        font.pointSize: Theme.font.size.smaller
        leftPadding: root.text.length > 0 ? track.width + root.spacing : track.width
        verticalAlignment: Text.AlignVCenter
    }
}
