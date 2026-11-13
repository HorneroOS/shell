import QtQuick
import QtQuick.Controls

Slider {
    id: root

    property string accessibleName: "Slider"
    property string tooltipText: ""

    from: 0
    to: 1
    value: 0

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.Slider
    Accessible.description: root.tooltipText

    UiTooltip {
        target: root
        text: root.tooltipText
    }

    opacity: root.enabled ? 1 : 0.5

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 4
        width: root.availableWidth
        height: implicitHeight
        radius: height / 2
        color: Theme.surfaceContainerHighest

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: height / 2
            color: Theme.primary
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 18
        implicitHeight: 18
        radius: width / 2
        color: Theme.primary
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.onPrimary
    }
}
