import QtQuick

// Section label with an optional channel number (visual language §7.1):
// `UiEyebrow { channel: 2; text: "Telemetry" }` reads `02 · TELEMETRY`.
// `context` is the right-aligned secondary eyebrow (`60 S WINDOW`).
Item {
    id: root

    property string text: ""
    // 0 = no channel number.
    property int channel: 0
    property string context: ""

    implicitWidth: label.implicitWidth + (contextLabel.visible ? Theme.spacing.larger + contextLabel.implicitWidth : 0)
    implicitHeight: label.implicitHeight

    Accessible.role: Accessible.Heading
    Accessible.name: root.text

    UiText {
        id: label

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        role: "eyebrow"
        text: root.channel > 0 ? `${String(root.channel).padStart(2, "0")} · ${root.text}` : root.text
    }

    UiText {
        id: contextLabel

        visible: root.context.length > 0
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, Math.max(0, root.width - label.implicitWidth - Theme.spacing.larger))
        role: "eyebrow"
        text: root.context
        elide: Text.ElideLeft
        horizontalAlignment: Text.AlignRight
    }
}
