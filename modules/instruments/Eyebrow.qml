import qs.components
import qs.services
import qs.config
import QtQuick

// Section label (RFC 0001 §2): IBM Plex Mono, uppercase, +8 % tracking,
// `inkMuted`, optionally prefixed by a channel number ("01 · AUDIO").
// Surface-local Signal piece; swap for the shared control kit when it
// lands.
StyledText {
    id: root

    property string channel: ""
    property string label: ""

    mono: true
    text: root.channel !== "" ? `${root.channel} · ${root.label}` : root.label
    color: Signal.palette.inkMuted
    font.pointSize: Appearance.font.size.small
    font.capitalization: Font.AllUppercase
    font.letterSpacing: Appearance.font.size.small * 0.08
    elide: Text.ElideRight
    Accessible.ignored: true
}
