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
        text: root.message
        role: root.kind === "error" ? "body" : "caption"
        color: root.kind === "error" ? Theme.error : Theme.onSurfaceVariant
        horizontalAlignment: Text.AlignHCenter
    }
}
