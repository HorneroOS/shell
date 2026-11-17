pragma Singleton

import qs.config
import qs.services
import QtQuick
import "Colour.js" as Colour

// PluginKit 3 design tokens: Hornero Signal (RFC 0001 §3), exactly the
// names the shell itself uses, so an extension is styled with the same
// language as a native surface.
//
//   Theme.palette.<role>       colour roles (RFC §3.1): ground sunken base
//                              panel raised lifted ink inkMuted inkFaint
//                              rule ruleStrong focus signal onSignal
//                              signalWell onSignalWell cue … glow
//   Theme.chromatic            read-only status of the dynamic palette
//                              ({active, variant, mode, seeds, fingerprint})
//                              or null; never a wallpaper path
//   Theme.revision             integer that increments once per settled
//                              palette change (after a transition, not per
//                              step); repaint canvases when it changes
//   Theme.contrast(a, b)       WCAG contrast ratio of two colours
//   Theme.ensureContrast(fg, bg, min)
//                              fg moved in lightness only until it reaches
//                              `min`:1 on bg (data-driven colours)
//   Theme.font.family.<f>      sans | mono | display (IBM Plex)
//   Theme.font.size.<s>        small 11 · smaller 12 · normal 13 ·
//                              larger 15 · large 18 · extraLarge 28 ·
//                              display 56 (points, like native text)
//   Theme.rounding.<r>         small 3 · normal 5 · large 8 · full
//   Theme.spacing.<s>          small 4 · smaller 8 · normal 12 ·
//                              larger 16 · large 24
//   Theme.padding.<p>          small 4 · smaller 6 · normal 8 ·
//                              larger 12 · large 16
//   Theme.anim.curves.<c>      standard enter exit sweep settle settleFast
//   Theme.anim.durations[<d>]  quick short medium long scan settleFast
//                              settle fade (ms; 0 under reduced motion,
//                              `fade` stays ≤ 90 ms)
//
// The Material-era names (primary, surfaceContainer, onSurface, …) and
// the flat spacing/rounding integers were removed in PluginKit 3; see
// docs/PLUGINS.md "Migrating to PluginKit 3".
QtObject {
    id: root

    // Colour roles. The object swaps to the high-contrast table when the
    // host enables it, so bindings through it always follow the host.
    readonly property var palette: Signal.palette
    readonly property bool light: Signal.light
    readonly property bool highContrast: Config.appearance.highContrast

    // Hornero Chromatic (RFC 0002 §13.4). Null for curated themes and
    // while High Contrast shows the protected table.
    readonly property var chromatic: root.highContrast ? null : Signal.chromatic
    readonly property int revision: Signal.paletteRevision

    function contrast(a: color, b: color): real {
        return Colour.contrast(Colour.toHex(a), Colour.toHex(b));
    }

    function ensureContrast(fg: color, bg: color, min: real): color {
        return Colour.ensureContrast(Colour.toHex(fg), Colour.toHex(bg), min);
    }

    readonly property var font: Appearance.font
    readonly property var rounding: Appearance.rounding
    readonly property var spacing: Appearance.spacing
    readonly property var padding: Appearance.padding
    readonly property var anim: Appearance.anim

    // Experience mode (RFC §5a): focus | everyday | signal | gaming |
    // studio. Extensions read it to change density, never to fake data.
    readonly property string experience: ExperienceBridge.mode
    // Motion level (signal-visual-language §11.3): full | standard |
    // reduced | off. Reduced motion (host setting or system preference)
    // always forces "off".
    readonly property string motionLevel: Appearance.anim.effectiveLevel
    readonly property bool reducedMotion: root.motionLevel === "off" || root.motionLevel === "reduced"

    // Luminous accent (RFC amendment 2, visual language §9). Only live
    // telemetry traces may glow, only in the `signal` experience, never
    // in day themes, high contrast, focus or gaming, never animated.
    // UiScope/UiSparkline apply it; extensions do not draw glow by hand.
    readonly property bool glowEnabled: ExperienceBridge.glow
    readonly property real glowBlur: 4
    readonly property real glowAlpha: Math.min(1, 0.4 * ExperienceBridge.glowIntensity)
    // Static CRT scanlines inside scope wells (§10): Signal mode only.
    readonly property bool scanlines: ExperienceBridge.scanlines
    // Instrument density (`icons` / `values` / `labels`): how much
    // labelling the experience wants; Signal raises it to `labels`.
    readonly property string density: ExperienceBridge.density

    // Shared telemetry cadence (§6.5): 1 Hz everyday, 2 Hz in signal
    // mode, paused while gaming unless an instrument is visible.
    readonly property int telemetryIntervalMs: ExperienceBridge.telemetryIntervalMs

    // Elevation: one restrained shadow (RFC §3.5).
    readonly property real shadowAlpha: 0.35
    readonly property real shadowBlur: 12
    readonly property real shadowOffset: 4

    // Keyboard-only focus: rings show iff the control has focus AND the
    // last input was a keyboard (docs/FOCUS.md).
    readonly property bool keyboardFocus: FocusMode.keyboard

    // Duration helper honouring reduced motion and the host scale.
    function duration(name: string): int {
        return Appearance.anim.durations[name] ?? 0;
    }
}
