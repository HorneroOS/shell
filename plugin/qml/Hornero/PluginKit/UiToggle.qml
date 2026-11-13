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

    indicator: Rectangle {
        implicitWidth: 44
        implicitHeight: 24
        x: 0
        y: parent.height / 2 - height / 2
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus ? (root.checked ? Theme.onPrimary : Theme.primary) : Theme.outline
        opacity: root.enabled ? 1 : 0.5

        Rectangle {
            x: root.checked ? parent.width - width - 3 : 3
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: width / 2
            color: root.checked ? Theme.onPrimary : Theme.onSurfaceVariant
        }
    }

    contentItem: Text {
        text: root.text
        color: Theme.onSurface
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        leftPadding: root.indicator.width + Theme.spacingSmall
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1 : 0.5
    }
}
