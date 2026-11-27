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

    // Bar section hosts advertise the bar's type scale, typeface, weight
    // and region ink; non-bar surfaces (dashboards, desktop, popovers)
    // have no hostStyle ancestor and keep their standard Signal scale.
    readonly property var hostStyle: {
        let p = root.parent;
        while (p) {
            if ("hostTextSize" in p)
                return p;
            p = p.parent;
        }
        return null;
    }
    readonly property bool islandStyled: hostStyle !== null && hostStyle.hostTextSize > 0
    readonly property bool _mono: root.role === "eyebrow" || root.role === "value"
    readonly property bool _display: root.role === "readout" || root.role === "display"
    readonly property bool _micro: root.role === "caption" || root.role === "eyebrow"

    color: root._micro ? Theme.palette.inkMuted : (root.islandStyled && root.hostStyle.hostTextColor && root.hostStyle.hostTextColor.a > 0 ? root.hostStyle.hostTextColor : Theme.palette.ink)
    font.family: root.islandStyled && !root._display && root.hostStyle.hostTextFamily && root.hostStyle.hostTextFamily.length > 0 ? root.hostStyle.hostTextFamily : (root._mono ? Theme.font.family.mono : root._display ? Theme.font.family.display : Theme.font.family.sans)
    font.pointSize: {
        if (root.islandStyled && !root._display && root.role !== "title") {
            if (root._micro)
                return root.hostStyle.hostMicroSize > 0 ? root.hostStyle.hostMicroSize : root.hostStyle.hostTextSize * 11 / 12;
            return root.hostStyle.hostTextSize;
        }
        return root.role === "display" ? Theme.font.size.extraLarge : root.role === "readout" ? 22 : root.role === "title" ? Theme.font.size.larger : root.role === "subtitle" ? Theme.font.size.normal : root._micro ? Theme.font.size.small : Theme.font.size.smaller;
    }
    font.weight: root.role === "title" ? Font.DemiBold : root.role === "subtitle" || root._display ? Font.Medium : (root.islandStyled && root.hostStyle.hostTextWeight > 0 ? root.hostStyle.hostTextWeight : Font.Normal)
    font.capitalization: root.role === "eyebrow" ? Font.AllUppercase : Font.MixedCase
    // Derived from the token, not from font.pointSize: reading the sibling font
    // property inside a font group binding is a binding loop.
    font.letterSpacing: root.role === "eyebrow" ? (root.islandStyled ? root.font.pointSize : Theme.font.size.small) * 0.08 : 0
    font.features: ({
            "tnum": 1
        })
    verticalAlignment: root.islandStyled ? Text.AlignVCenter : Text.AlignTop
    textFormat: Text.PlainText
    wrapMode: root._mono || root._display || root.islandStyled ? Text.NoWrap : Text.WordWrap
}
