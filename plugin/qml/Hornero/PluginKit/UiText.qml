import QtQuick

Text {
    id: root

    property string role: "body"

    color: root.role === "caption" ? Theme.onSurfaceVariant : Theme.onSurface
    font.family: Theme.fontFamily
    // Points, like native StyledText (pixel sizes rendered ~25% smaller).
    // "subtitle" is the native popout header (normal size, medium weight —
    // modules/bar/popouts section titles), for popover/panel headings that
    // must read like the shell's own popouts instead of a card title.
    font.pointSize: root.role === "display" ? Theme.fontSizeDisplay : root.role === "title" ? Theme.fontSizeTitle : root.role === "subtitle" ? Theme.fontSize : root.role === "caption" ? Theme.fontSizeSmall : Theme.fontSizeBody
    font.weight: root.role === "title" ? Font.DemiBold : root.role === "subtitle" ? Font.Medium : Font.Normal
    wrapMode: Text.WordWrap
}
