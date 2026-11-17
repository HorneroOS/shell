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
    readonly property int iconPx: Model.icon(factor, content)
    readonly property int textPx: Model.text(factor, content)
    readonly property int microPx: Model.micro(factor, content)
    readonly property int clockPx: Model.clock(factor, content)
    // Point sizes for font.pointSize / Glyph sizes.
    readonly property real iconPt: Model.pt(iconPx)
    readonly property real textPt: Model.pt(textPx)
    readonly property real microPt: Model.pt(microPx)
    readonly property real clockPt: Model.pt(clockPx)
    readonly property int segmentPad: Model.segmentPadding(factor, false)
    readonly property int segmentPadRail: Model.segmentPadding(factor, true)

    function pt(px: real): real {
        return Model.pt(px);
    }

    function thickness(base: real): int {
        return Model.thickness(base, factor);
    }
}
