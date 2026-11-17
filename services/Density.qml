pragma Singleton

import qs.config
import QtQuick
import Quickshell
import "density.js" as Model

// Bar density factor and the sizes derived from it (see density.js).
// Measured on the first screen; per-bar tuning stays in the presets
// (`thickness`, `sizes.innerWidth`, `sizes.contentScale`) and
// `bar.sizes.densityScale`.
Singleton {
    id: root

    readonly property real screenHeight: Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080
    readonly property real factor: Model.factor(screenHeight, Config.bar.sizes.densityScale, Config.bar.sizes.autoDensity)
    readonly property string mode: factor < 0.95 ? "compact" : "regular"

    readonly property int inner: Model.inner(Config.bar.sizes.innerWidth, factor)
    readonly property real content: Config.bar.sizes.contentScale
    // Item style (Bars > Size & shape): icon size, text size, item gap, weight.
    readonly property real iconScale: Config.bar.sizes.iconScale
    readonly property real textScale: Config.bar.sizes.textScale
    readonly property real itemSpacing: Config.bar.sizes.itemSpacing
    readonly property int iconPx: Model.icon(factor, content, iconScale)
    readonly property int textPx: Model.text(factor, content, textScale)
    readonly property int microPx: Model.micro(factor, content, textScale)
    // Clean type sets the clock one step above the other values; the
    // Signal face keeps its Condensed Medium display size.
    readonly property int clockPx: clean ? Math.round(textPx * 1.15) : Model.clock(factor, content, textScale)
    // Values, dates and labels: the Signal mono data face, or plain sans
    // (clean: sentence case, no tracking, tabular figures where aligned).
    readonly property bool clean: Config.bar.typeface === "sans"
    readonly property string dataFamily: clean ? Appearance.font.family.sans : Appearance.font.family.mono
    readonly property int textWeight: Model.textWeight(Config.bar.sizes.textWeight, Config.appearance.font.weight.shift)
    // Tracking in em for caps eyebrows; clean type is never tracked.
    readonly property real eyebrowTracking: clean ? 0 : 0.8
    // Point sizes for font.pointSize / Glyph sizes.
    readonly property real iconPt: Model.pt(iconPx)
    readonly property real textPt: Model.pt(textPx)
    readonly property real microPt: Model.pt(microPx)
    readonly property real clockPt: Model.pt(clockPx)
    readonly property int segmentPad: Model.segmentPadding(factor, false, itemSpacing)
    readonly property int segmentPadRail: Model.segmentPadding(factor, true, itemSpacing)

    function pt(px: real): real {
        return Model.pt(px);
    }

    function thickness(base: real): int {
        return Model.thickness(base, factor);
    }
}
