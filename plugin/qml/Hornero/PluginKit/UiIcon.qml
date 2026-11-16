import QtQuick
import qs.utils

// One Hornero Glyph (RFC 0001 §3.4): the shell's bundled Tabler Icons
// outline subset, the same glyphs native surfaces use.
//
//   UiIcon { name: "player-play" }
//
// `name` is a Hornero Glyph name (full list:
// assets/fonts/hornero-glyphs.names in the shell). Glyphs are outline
// only — there is no fill axis. Unknown names render nothing and log one
// warning; scripts/validate_plugin.py rejects them before install.
// Decorative by default: give a meaningful control its own
// Accessible.name.
Text {
    id: root

    property string name: ""
    // Point size; 0 = the default glyph size (bar glyphs are 18 px per
    // the visual language, set by the bar host's island style).
    property real size: 0

    text: Glyphs.glyph(root.name)
    color: Theme.palette.ink
    font.family: Glyphs.family
    font.pointSize: root.size > 0 ? root.size : Theme.font.size.larger
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    Accessible.ignored: true
}
