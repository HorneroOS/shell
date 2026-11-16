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

    component Motion: QtObject {
        id: motion

        // Motion level of the active experience mode (Signal Visual
        // Language §11.3: full | standard | reduced | off), set by
        // services/Experience.qml. appearance.reducedMotion or the system
        // preference force `off` regardless of the mode.
        property string level: "standard"
        readonly property string effectiveLevel: (Config.appearance.reducedMotion || SystemMotion.reduced) ? "off" : (["full", "standard", "reduced", "off"].includes(level) ? level : "standard")
        // True when every duration is zero (only capped fades remain).
        readonly property bool reduced: effectiveLevel === "off"
        // Spatial motion (morph, stagger, settle overshoot) only at the
        // full and standard levels; at `reduced` components keep a short
        // 4 px move + fade and pick `standard` over the settle curves.
        readonly property bool spatial: effectiveLevel === "full" || effectiveLevel === "standard"
        readonly property real mediaGifSpeedAdjustment: Config.appearance.anim.mediaGifSpeedAdjustment
        readonly property real sessionGifSpeed: Config.appearance.anim.sessionGifSpeed
        readonly property Curves curves: Curves {}
        readonly property real _scale: Config.appearance.anim.durations.scale
        // `full` and `standard` share timings (§11.3); `reduced` halves
        // them; `off` zeroes them.
        readonly property real _k: reduced ? 0 : effectiveLevel === "reduced" ? _scale * 0.5 : _scale
        // Durations in ms. Reduced motion zeroes every duration; opacity
        // cross-fades use `fade`, which stays at most 90 ms. A plain map
        // because `short` is not a legal property name on every Qt parser.
        readonly property var durations: ({
                "scale": motion._scale,
                "quick": Math.round(90 * motion._k),
                "short": Math.round(160 * motion._k),
                "medium": Math.round(240 * motion._k),
                "long": Math.round(360 * motion._k),
                "scan": Math.round(480 * motion._k),
                "settleFast": Math.round(220 * motion._k),
                "settle": Math.round(320 * motion._k),
                "fade": motion.reduced ? 90 : Math.round(90 * motion._scale)
            })
    }
}
