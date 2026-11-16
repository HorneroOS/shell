pragma Singleton

import Quickshell
import QtQuick

// Shorthand for the appearance tokens: `Appearance.xxx` instead of
// `Config.appearance.xxx`. Motion tokens (RFC 0001 §3.6 + amendment 1)
// are derived here from the persisted knobs and are not user settings.
Singleton {
    readonly property AppearanceConfig.Rounding rounding: Config.appearance.rounding
    readonly property AppearanceConfig.Spacing spacing: Config.appearance.spacing
    readonly property AppearanceConfig.Padding padding: Config.appearance.padding
    readonly property AppearanceConfig.FontStuff font: Config.appearance.font
    readonly property Motion anim: Motion {}
    readonly property AppearanceConfig.Transparency transparency: Config.appearance.transparency

    component Curves: QtObject {
        readonly property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        readonly property list<real> enter: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property list<real> exit: [0.3, 0, 1, 1, 1, 1]
        readonly property list<real> sweep: [0.65, 0, 0.35, 1, 1, 1]
        // Small (<= 4 %) overshoot for spatial motion only: position, size,
        // shape. Never for opacity or colour.
        readonly property list<real> settle: [0.32, 1.24, 0.42, 1, 1, 1]
        readonly property list<real> settleFast: [0.34, 1.3, 0.5, 1, 1, 1]
    }

    // Durations in ms. Reduced motion zeroes every duration; opacity
    // cross-fades use `fade`, which stays at most 90 ms.
    component Durations: QtObject {
        required property bool reduced
        readonly property real scale: Config.appearance.anim.durations.scale
        readonly property real _k: reduced ? 0 : scale
        readonly property int quick: 90 * _k
        readonly property int short: 160 * _k
        readonly property int medium: 240 * _k
        readonly property int long: 360 * _k
        readonly property int scan: 480 * _k
        readonly property int settleFast: 220 * _k
        readonly property int settle: 320 * _k
        readonly property int fade: reduced ? 90 : 90 * scale
    }

    component Motion: QtObject {
        id: motion

        // appearance.reducedMotion or the system preference.
        readonly property bool reduced: Config.appearance.reducedMotion || SystemMotion.reduced
        readonly property real mediaGifSpeedAdjustment: Config.appearance.anim.mediaGifSpeedAdjustment
        readonly property real sessionGifSpeed: Config.appearance.anim.sessionGifSpeed
        readonly property Curves curves: Curves {}
        readonly property Durations durations: Durations {
            reduced: motion.reduced
        }
    }
}
