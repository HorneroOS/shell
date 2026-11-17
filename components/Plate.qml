import qs.services
import qs.config
import QtQuick

// Engraved plate label (visual language section 17.4): IBM Plex Sans
// Condensed SemiBold, capitals, wide tracking, fixed-width figures. For
// enums only (a mode, a state, a channel name), never for sentences.
// Tracking is the user's setting (appearance.atmosphere.plateTracking,
// Control Center > Appearance > Atmosphere). A screen should use at most
// four type treatments: UI, readout (mono + tnum), eyebrow, plate/display.
StyledText {
    id: root

    property real size: Appearance.font.size.small
    property real tracking: Atmosphere.plateTracking

    text: ""
    color: Signal.palette.inkMuted
    font.family: Appearance.font.family.display
    font.weight: Font.DemiBold
    font.pointSize: root.size
    font.capitalization: Font.AllUppercase
    font.letterSpacing: root.size * root.tracking
    tabular: true
    elide: Text.ElideRight

    Accessible.ignored: true
}
