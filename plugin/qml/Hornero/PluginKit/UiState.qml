import QtQuick

Column {
    id: root

    property string kind: "empty"
    property string message: ""

    spacing: Theme.spacingSmall

    UiText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.kind === "loading" ? "…" : root.kind === "error" ? "!" : ""
        role: "title"
        color: root.kind === "error" ? Theme.error : Theme.onSurfaceVariant
        visible: text.length > 0
    }

    UiText {
        anchors.horizontalCenter: parent.horizontalCenter
        // Wrap inside the container (a popover or card column) instead of
        // running past its edges as one centred line.
        width: root.parent && root.parent.width > 0 ? Math.min(implicitWidth, root.parent.width) : implicitWidth
        text: root.message
        role: root.kind === "error" ? "body" : "caption"
        color: root.kind === "error" ? Theme.error : Theme.onSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
    }
}
