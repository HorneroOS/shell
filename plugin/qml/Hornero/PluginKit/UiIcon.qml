import QtQuick

// Native icon for extensions: the shell's MaterialIcon (Material Symbols
// Rounded with FILL/GRAD/opsz axes), so an extension can show the same
// glyphs as native bar items and cards. `icon` is a Material Symbols name
// (e.g. "timer", "calculate", "graphic_eq"). Decorative by default: give a
// meaningful control its own Accessible.name.
Text {
    id: root

    property string icon: ""
    property real fill: 0
    property string role: "body"
    // Explicit point size (e.g. a host island style); 0 = by role.
    property int size: 0

    text: root.icon
    color: Theme.onSurface
    font.family: Theme.iconFontFamily
    font.pointSize: root.size > 0 ? root.size : root.role === "large" ? Theme.iconSizeLarge : root.role === "small" ? Theme.fontSizeBody : Theme.iconSize
    font.variableAxes: ({
            FILL: root.fill.toFixed(1),
            GRAD: Theme.light ? 0 : -25,
            opsz: fontInfo.pixelSize,
            wght: fontInfo.weight
        })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Accessible.ignored: true
}
