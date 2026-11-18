import Quickshell.Io

JsonObject {
    // Canonical Hornero Signal theme id. The built-ins (hornero-signal-
    // night/day/contrast) are complete role tables in services/Signal.qml;
    // any other id resolves through the shared theme registry and must
    // carry a schema-v2 palette (ThemePipeline).
    property string theme: "hornero-signal-night"
    // Shell-wide accessibility override; external applications keep their theme.
    property bool highContrast: false
    // Shell-wide reduced motion (also follows the system preference).
    property bool reducedMotion: false
    // Soft, rounder palette chips and tiles with a heart for the selected
    // one (the cozy touch). Off keeps the sharp Bezel chips.
    property bool cozyChips: true
    property Rounding rounding: Rounding {}
    property Spacing spacing: Spacing {}
    property Padding padding: Padding {}
    property FontStuff font: FontStuff {}
    property Anim anim: Anim {}
    property Transparency transparency: Transparency {}
    property Glow glow: Glow {}
    property Atmosphere atmosphere: Atmosphere {}
    // Hornero Chromatic preferences (RFC 0002 §8.3). Active only while
    // `theme` is "hornero-chromatic"; horneroctl reads these, the shell
    // edits them. Never hold a wallpaper path here: the source resolves
    // from the wallpaper pointer.
    property ChromaticPrefs chromatic: ChromaticPrefs {}
    // User accent laid over any theme (Appearance > Accent). "" everywhere
    // means the theme's own accent. Resolution: perExperience[mode] beats
    // perMode[dark|light] beats `color`.
    property AccentPrefs accent: AccentPrefs {}

    // Geometry on a 4 px grid (RFC 0001 §3.5). `full` is only for
    // genuinely circular elements (avatars, radio dots).
    component Rounding: JsonObject {
        property real scale: 1
        property int small: 3 * scale
        property int normal: 5 * scale
        property int large: 8 * scale
        property int full: 1000 * scale
    }

    component Spacing: JsonObject {
        property real scale: 1
        property int small: 4 * scale
        property int smaller: 8 * scale
        property int normal: 12 * scale
        property int larger: 16 * scale
        property int large: 24 * scale
    }

    component Padding: JsonObject {
        property real scale: 1
        property int small: 4 * scale
        property int smaller: 6 * scale
        property int normal: 8 * scale
        property int larger: 12 * scale
        property int large: 16 * scale
    }

    // IBM Plex superfamily (RFC 0001 §3.3, package ttf-ibm-plex). Glyphs
    // come from the bundled Hornero Glyphs font, not a family setting.
    component FontFamily: JsonObject {
        property string sans: "IBM Plex Sans"
        property string mono: "IBM Plex Mono"
        property string display: "IBM Plex Sans Condensed"
    }

    component FontSize: JsonObject {
        property real scale: 1
        property int small: 11 * scale
        property int smaller: 12 * scale
        property int normal: 13 * scale
        property int larger: 15 * scale
        property int large: 18 * scale
        property int extraLarge: 28 * scale
        property int display: 56 * scale
    }

    // Text weight. `shift` moves every weight token up or down in steps of
    // 100 (-200..+200): lighter and airier, or sturdier for readability.
    // Call sites use these tokens instead of literal 400/500/600.
    component FontWeight: JsonObject {
        property int shift: 0
        readonly property int regular: Math.max(100, Math.min(900, 400 + shift))
        readonly property int medium: Math.max(100, Math.min(900, 500 + shift))
        readonly property int strong: Math.max(100, Math.min(900, 600 + shift))
    }

    component FontStuff: JsonObject {
        property FontFamily family: FontFamily {}
        property FontSize size: FontSize {}
        property FontWeight weight: FontWeight {}
    }

    // Motion knobs only; the curve and duration tokens are derived in
    // config/Appearance.qml (Appearance.anim), so they are never persisted.
    component AnimDurations: JsonObject {
        property real scale: 1
    }

    component Anim: JsonObject {
        property real mediaGifSpeedAdjustment: 300
        property real sessionGifSpeed: 0.7
        // Spatial easing personality: "smooth" (factory, <= 4 % overshoot),
        // "snappy" (no overshoot) or "lively" (spring-like needle settle,
        // <= 6 % overshoot; the old "bouncy" value reads as lively).
        // Opacity and colour never overshoot in any style.
        property string curveStyle: "smooth"
        // Leading/trailing asymmetry: the trailing edge of a travelling
        // indicator takes this many times the leading edge's duration
        // (1 = no stretch, 2.5 = longest). Signal visual language §11.
        property real trailRatio: 1.6
        property AnimDurations durations: AnimDurations {}
    }

    component ChromaticModeChoice: JsonObject {
        property string variant: "auto"
    }

    component ChromaticPerMode: JsonObject {
        property ChromaticModeChoice dark: ChromaticModeChoice {}
        property ChromaticModeChoice light: ChromaticModeChoice {}
    }

    component ChromaticFallback: JsonObject {
        property string dark: "hornero-signal-night"
        property string light: "hornero-signal-day"
    }

    component AccentPrefs: JsonObject {
        // "" or #RRGGBB.
        property string color: ""
        property AccentPerMode perMode: AccentPerMode {}
        // experience mode id -> "" | #RRGGBB
        property var perExperience: ({})
    }

    component AccentPerMode: JsonObject {
        property string dark: ""
        property string light: ""
    }

    component ChromaticPrefs: JsonObject {
        // wallpaper | image | seed | house
        property string source: "wallpaper"
        // At most two #RRGGBB seeds (source seed, or manual accent).
        property var seeds: []
        // auto | balanced | vibrant | expressive | faithful | muted |
        // monochrome | high-contrast | neon
        property string variant: "auto"
        // auto | dark | light
        property string mode: "auto"
        // auto | standard | boosted | maximum
        property string contrast: "standard"
        // standard | deep
        property string surfaceDepth: "standard"
        property real chroma: 1
        property real hueShift: 0
        // off | auto | ask
        property string follow: "auto"
        property ChromaticPerMode perMode: ChromaticPerMode {}
        property ChromaticFallback fallback: ChromaticFallback {}
        // smooth | instant
        property string transition: "smooth"
    }

    // Glow strength multiplier (0 = no glow, 1 = Signal reference, up to
    // 1.5). Whether glow appears at all is still decided by the experience
    // mode and the glow budget (visual language section 9); this only scales
    // the alpha of the glows that are allowed.
    component Glow: JsonObject {
        property real intensity: 1
        // How many glowing items may show at once (visual language section 9
        // says three; 1..6 allowed). Mode rules still decide whether any glow shows.
        property int limit: 3
    }

    // Atmosphere (visual language section 17): the warm, cosy layer on top of
    // the Signal surfaces. Every value is a user setting; `enabled: false`
    // removes the whole layer. The shell additionally keeps it off in Focus,
    // Gaming and Studio modes and in High Contrast, and drops the dark-only
    // parts (vignette, scanlines) in day themes.
    //   lamp        warm light wash, 0 = none .. 1.5 (1 = reference)
    //   warmth      lamp tint: 0 = palette amber .. 1 = rose
    //   innerLight  soft inner top highlight, 0 .. 1.5
    //   vignette    gentle edge darkening, 0 .. 1
    //   grain       fine film grain, 0 .. 1
    //   scanlines   faint horizontal lines, 0 .. 1 (off by default)
    //   plateTracking  letter spacing of Plate labels, 0 .. 0.3 em
    //   mascot      show the hornero in empty states and greetings
    //   tone        microcopy voice: "cozy" or "plain"
    component Atmosphere: JsonObject {
        property bool enabled: true
        property real lamp: 0.8
        property real warmth: 0.2
        property real innerLight: 0.8
        property real vignette: 0.4
        property real grain: 0.3
        property real scanlines: 0
        property real plateTracking: 0.14
        property bool mascot: true
        property string tone: "cozy"
    }

    component Transparency: JsonObject {
        property bool enabled: false
        property real base: 0.85
        property real layers: 0.4
        // Per-surface alpha overrides: {bar, launcher, dashboard, session,
        // sidebar, utilities, notifications, osd, lock, layoutpicker} each
        // 0..1. A missing/non-numeric entry follows `base`. Always reassign
        // (never mutate in place) so QML bindings re-evaluate.
        property var elements: ({})
    }
}
