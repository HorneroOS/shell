import qs.services
import qs.config
import QtQuick

// Text of a bar item: one typographic voice for every value, date, label
// and title in the bars (Bars > Size & shape: text size, weight, typeface).
//   role "value"   tabular figures at the item text size (default)
//   role "label"   plain item text, proportional
//   role "eyebrow" small caps label; tracked only in the Mono typeface
// The face is `Density.dataFamily` (Plex Mono or Plex Sans); clean (Sans)
// type is sentence case and untracked.
StyledText {
    id: root

    property string role: "value"

    font.family: Density.dataFamily
    font.pointSize: root.role === "eyebrow" ? Density.microPt : Density.textPt
    font.weight: Density.textWeight
    font.letterSpacing: root.role === "eyebrow" ? Density.eyebrowTracking : 0
    font.capitalization: root.role === "eyebrow" && !Density.clean ? Font.AllUppercase : Font.MixedCase
    tabular: root.role === "value"
}
