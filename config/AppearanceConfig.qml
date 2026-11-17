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
    property Rounding rounding: Rounding {}
    property Spacing spacing: Spacing {}
    property Padding padding: Padding {}
    property FontStuff font: FontStuff {}
    property Anim anim: Anim {}
    property Transparency transparency: Transparency {}
    property Glow glow: Glow {}
    // Hornero Chromatic preferences (RFC 0002 §8.3). Active only while
    // `theme` is "hornero-chromatic"; horneroctl reads these, the shell
    // edits them. Never hold a wallpaper path here: the source resolves
    // from the wallpaper pointer.
    property ChromaticPrefs chromatic: ChromaticPrefs {}

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

    component FontStuff: JsonObject {
        property FontFamily family: FontFamily {}
        property FontSize size: FontSize {}
    }

    // Motion knobs only; the curve and duration tokens are derived in
    // config/Appearance.qml (Appearance.anim), so they are never persisted.
    component AnimDurations: JsonObject {
        property real scale: 1
    }

    component Anim: JsonObject {
        property real mediaGifSpeedAdjustment: 300
        property real sessionGifSpeed: 0.7
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
