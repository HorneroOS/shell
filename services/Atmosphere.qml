pragma Singleton

import "atmosphere.js" as Model
import qs.services
import qs.config
import Quickshell
import Quickshell.Services.UPower
import QtQuick

// Atmosphere (visual language section 17): the warm, cosy layer on top of
// the Signal surfaces. Warm lamp light, soft inner highlights, a gentle
// vignette, film grain and optional scanlines, plus the hornero mascot and
// the microcopy voice. This singleton is the one place the layer is
// decided; surfaces only read it (components/atmosphere/AtmosphereLayer).
//
// Always user-tunable (appearance.atmosphere.*, Control Center >
// Appearance > Atmosphere) and never forced:
// - lamp, vignette, grain and scanlines drop in the power-saver profile;
// - off entirely with `enabled: false`;
// - off in High Contrast, and in Focus, Gaming and Studio modes (a stable,
//   colour-neutral canvas), whatever the user's values say;
// - day themes keep a softened lamp and highlights, drop vignette and
//   scanlines;
// - the lamp draws from the shared glow budget (Experience.acquireGlow),
//   so it never crowds out the on-air bar or the scope traces.
Singleton {
    id: root

    readonly property var settings: Model.clean(Config.appearance.atmosphere)
    // Mode and accessibility guardrails, independent of the user's values.
    readonly property bool allowed: !Config.appearance.highContrast && !Experience.focus && !Experience.gaming && !Experience.studio
    readonly property bool active: settings.enabled && allowed

    // Power-saver profile: lamp, vignette, grain and scanlines drop first.
    readonly property bool lowPower: PowerProfiles.profile === PowerProfile.PowerSaver
    // Levels ignore `enabled` and the mode guards on purpose: surfaces fade
    // their whole layer out on those, so the lamp dims over `fadeMs`
    // instead of snapping.
    readonly property var levels: Model.levels(Object.assign({}, settings, {
        "enabled": true
    }), Signal.light, lowPower)
    // Lamp fade on mode or setting changes: 400 to 600 ms (the `scan`
    // duration, 480 ms), instant under reduced motion and low power.
    readonly property int fadeMs: lowPower ? 0 : Appearance.anim.durations.scan

    // Accent chips derived from the live palette (custom and Chromatic
    // palettes get them too); readable on all six surfaces.
    readonly property var chips: {
        Signal.paletteRevision;
        const p = Signal.palette;
        return Model.chips({
            ground: String(p.ground), sunken: String(p.sunken), base: String(p.base),
            panel: String(p.panel), raised: String(p.raised), lifted: String(p.lifted),
            ink: String(p.ink), glow: String(p.glow), signal: String(p.signal),
            alert: String(p.alert), term5: String(p.term5)
        }, settings.warmth);
    }
    readonly property color lamp: chips.lamp
    readonly property color blush: chips.blush
    // Legible alert text on any surface (tooltips included).
    readonly property color alertText: chips.alertText
    readonly property real plateTracking: settings.plateTracking
    // Warm-white used for inner highlights: ink pulled toward the lamp.
    readonly property color highlight: Model.mix(String(Signal.palette.ink), String(chips.lamp), 0.45)

    readonly property bool mascot: active && settings.mascot
    readonly property string tone: settings.tone
    // Scanlines are an instrument detail: they follow the user's strength
    // but never appear in light themes or High Contrast (section 10).
    readonly property bool scanlines: levels.scanlines > 0
}
