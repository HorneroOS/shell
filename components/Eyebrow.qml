import qs.services
import qs.config
import QtQuick

// Eyebrow label (RFC 0001 §2): IBM Plex Mono, uppercase, +8 % tracking,
// `inkMuted`, optionally prefixed by a channel number — `01 · AUDIO`.
// Bars use at most four characters (`OUT`, `CPU`); panels any length.
StyledText {
    id: root

    property string label: ""
    property string channel: ""

    text: (root.channel.length > 0 ? `${root.channel} · ` : "") + root.label
    mono: true
    color: Signal.palette.inkMuted
    font.pointSize: Appearance.font.size.small
    font.capitalization: Font.AllUppercase
    font.letterSpacing: Appearance.font.size.small * 0.08
    elide: Text.ElideRight

    Accessible.ignored: true
}
