import QtQuick
import qs.utils

// Native icon for extensions: a Hornero Glyph (the shell's bundled
// Tabler Icons outline subset, components/Glyph.qml), so an extension
// shows the same glyphs as native bar items and cards. `icon` is a
// Hornero Glyph name (e.g. "clock", "calculator", "wave-sine"; full list
// in assets/fonts/hornero-glyphs.names). Material-era icon names and the
// `fill` axis are gone (breaking change, docs/PLUGINS.md). Decorative by
// default: give a meaningful control its own Accessible.name.
Text {
    id: root

    property string icon: ""
    property string role: "body"
    // Explicit point size (e.g. a host island style); 0 = by role.
    property int size: 0

    text: Glyphs.glyph(root.icon)
    color: Theme.onSurface
    font.family: Theme.iconFontFamily
    font.pointSize: root.size > 0 ? root.size : root.role === "large" ? Theme.iconSizeLarge : root.role === "small" ? Theme.fontSizeBody : Theme.iconSize
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Accessible.ignored: true
}
