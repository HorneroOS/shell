import QtQuick

Rectangle {
    id: root

    property string text: ""
    property string tone: "neutral"

    implicitWidth: label.implicitWidth + Theme.spacing * 2
    implicitHeight: label.implicitHeight + Theme.spacingSmall * 2
    radius: height / 2
    color: root.tone === "primary" ? Theme.primaryContainer : root.tone === "error" ? Theme.errorContainer : Theme.surfaceContainerHighest

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: root.tone === "primary" ? Theme.onPrimaryContainer : root.tone === "error" ? Theme.onErrorContainer : Theme.onSurfaceVariant
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
    }
}
