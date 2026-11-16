import QtQuick

Text {
    id: root

    property string role: "body"

    color: root.role === "caption" ? Theme.onSurfaceVariant : Theme.onSurface
    font.family: Theme.fontFamily
    // Points, like native StyledText (pixel sizes rendered ~25% smaller).
    font.pointSize: root.role === "display" ? Theme.fontSizeDisplay : root.role === "title" ? Theme.fontSizeTitle : root.role === "caption" ? Theme.fontSizeSmall : Theme.fontSizeBody
    font.weight: root.role === "title" ? Font.DemiBold : Font.Normal
    wrapMode: Text.WordWrap
}
