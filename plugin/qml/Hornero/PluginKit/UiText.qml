import QtQuick

Text {
    id: root

    property string role: "body"

    color: root.role === "caption" ? Theme.onSurfaceVariant : Theme.onSurface
    font.family: Theme.fontFamily
    font.pixelSize: root.role === "title" ? Theme.fontSizeLarge : root.role === "caption" ? Theme.fontSizeSmall : Theme.fontSize
    font.bold: root.role === "title"
    wrapMode: Text.WordWrap
}
