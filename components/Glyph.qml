import qs.config
import qs.utils
import QtQuick

// One Hornero Glyph by name: `Glyph { name: "wifi"; color: …; size: … }`.
// Outline-only (no fill/grade axes); stroke reads as a hairline at
// 16–24 px. Give a meaningful control its own Accessible.name.
StyledText {
    id: root

    property string name: ""
    property real size: Appearance.font.size.larger

    text: Glyphs.glyph(root.name)
    font.family: Glyphs.family
    font.pointSize: root.size
}
