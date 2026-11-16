import QtQuick

// PluginKit text in the Signal type system (RFC 0001 §3.3).
//
//   role: "body"     Plex Sans 12, ink — default UI text
//         "caption"  Plex Sans 11, inkMuted — secondary text
//         "subtitle" Plex Sans 13 medium, ink — popover/panel headings
//         "title"    Plex Sans 15 semibold, ink — card titles
//         "eyebrow"  Plex Mono 11, uppercase, +8 % tracking, inkMuted —
//                    section labels (`02 · TELEMETRY`)
//         "value"    Plex Mono 12, tabular figures, ink — readout values
//         "readout"  Plex Sans Condensed 22 medium, tabular — large numbers
//         "display"  Plex Sans Condensed 28 medium — clocks, hero values
//
// Numbers are always tabular. Give `color` a palette role when the text
// carries state (`Theme.palette.alert`, `Theme.palette.signal`).
Text {
    id: root

    property string role: "body"

    readonly property bool _mono: root.role === "eyebrow" || root.role === "value"
    readonly property bool _display: root.role === "readout" || root.role === "display"

    color: root.role === "caption" || root.role === "eyebrow" ? Theme.palette.inkMuted : Theme.palette.ink
    font.family: root._mono ? Theme.font.family.mono : root._display ? Theme.font.family.display : Theme.font.family.sans
    font.pointSize: root.role === "display" ? Theme.font.size.extraLarge : root.role === "readout" ? 22 : root.role === "title" ? Theme.font.size.larger : root.role === "subtitle" ? Theme.font.size.normal : root.role === "caption" || root.role === "eyebrow" ? Theme.font.size.small : Theme.font.size.smaller
    font.weight: root.role === "title" ? Font.DemiBold : root.role === "subtitle" || root._display ? Font.Medium : Font.Normal
    font.capitalization: root.role === "eyebrow" ? Font.AllUppercase : Font.MixedCase
    font.letterSpacing: root.role === "eyebrow" ? font.pointSize * 0.08 : 0
    font.features: ({
            "tnum": 1
        })
    textFormat: Text.PlainText
    wrapMode: root._mono || root._display ? Text.NoWrap : Text.WordWrap
}
