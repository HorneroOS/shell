import QtQuick
import QtQuick.Controls

Switch {
    id: root

    // Two-way synced with `checked`; `toggled()` is inherited from
    // Switch/AbstractButton and must not be redeclared here.
    property bool value: false
    property string tooltipText: ""
    property string accessibleName: root.text

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.CheckBox
    Accessible.description: root.tooltipText

    // Keyboard contract (shell issue 376): one deterministic tab stop while
    // enabled (declaration order is tab order), Space is native to
    // Switch, Enter/Return are added here so both toggle.
    activeFocusOnTab: enabled
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

    // Native switch (components/controls/StyledSwitch.qml): the thumb grows
    // while pressed, carries an 8% hover / 10% press layer, and both animate
    // over the normal duration. The focus ring is keyboard-only.
    HoverHandler {
        id: hover

        enabled: root.enabled
    }

    indicator: Rectangle {
        implicitWidth: 44
        implicitHeight: 24
        x: 0
        y: parent.height / 2 - height / 2
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: 1
        border.color: Theme.outline
        opacity: root.enabled ? 1 : 0.5

        Rectangle {
            id: thumb

            readonly property real restWidth: 18
            readonly property real pressedWidth: 23.4

            x: root.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: root.down ? pressedWidth : restWidth
            height: 18
            radius: height / 2
            color: root.checked ? Theme.onPrimary : Theme.onSurfaceVariant

            Behavior on width {
                NumberAnimation {
                    duration: Theme.durationNormal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Theme.curveStandard
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: root.checked ? Theme.primary : Theme.onSurface
                opacity: root.down ? 0.1 : hover.hovered ? 0.08 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durationNormal
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Theme.curveStandard
                    }
                }
            }
        }

        // Keyboard-only focus ring (shell FocusRing contract).
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            radius: height / 2 + 2
            color: "transparent"
            border.width: 2
            border.color: Theme.focusRing
            visible: root.activeFocus && Theme.keyboardFocus && root.enabled
        }
    }

    contentItem: Text {
        text: root.text
        color: Theme.onSurface
        font.family: Theme.fontFamily
        font.pointSize: Theme.fontSizeBody
        leftPadding: root.indicator.width + Theme.spacingSmall
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1 : 0.5
    }
}
