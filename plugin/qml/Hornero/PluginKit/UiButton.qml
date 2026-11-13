import QtQuick
import QtQuick.Controls

Button {
    id: root

    property string variant: "primary"
    property string tooltipText: ""
    property string accessibleName: root.text

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.Button
    Accessible.description: root.tooltipText

    UiTooltip {
        target: root
        text: root.tooltipText
    }

    contentItem: Text {
        text: root.text
        color: root.variant === "ghost" ? Theme.primary : Theme.onPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1 : 0.5
    }

    background: Rectangle {
        color: root.variant === "ghost" ? "transparent" : Theme.primary
        radius: Theme.rounding
        border.width: root.activeFocus ? 2 : root.variant === "ghost" ? 1 : 0
        border.color: root.activeFocus ? (root.variant === "ghost" ? Theme.primary : Theme.onPrimary) : Theme.outline
        opacity: root.enabled ? 1 : 0.5
    }
}
