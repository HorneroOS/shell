pragma Singleton

import qs.config
import qs.services
import qs.utils
import QtQuick

// Content colours (on*) live in ThemeBase: Qt parses a property named
// onX declared beside a property X in one file as the X-changed signal
// handler, so the colour silently resolves to black (shell#427).
ThemeBase {
    // Expose the effective palette mode, including accessibility overrides.
    readonly property bool light: Signal.light
    readonly property color primary: Signal.palette.signal

    readonly property color surface: Signal.palette.base
    readonly property color surfaceContainer: Signal.palette.panel

    readonly property color error: Signal.palette.alert
    readonly property color background: Signal.palette.ground

    readonly property color surfaceDim: Signal.palette.ground
    readonly property color surfaceBright: Signal.palette.lifted
    readonly property color surfaceContainerLowest: Signal.palette.ground
    readonly property color surfaceContainerLow: Signal.palette.sunken
    readonly property color surfaceContainerHigh: Signal.palette.raised
    readonly property color surfaceContainerHighest: Signal.palette.lifted
    readonly property color surfaceVariant: Signal.palette.raised
    readonly property color primaryContainer: Signal.palette.signalWell

    readonly property color secondary: Signal.palette.cue

    readonly property color secondaryContainer: Signal.palette.cueWell

    readonly property color tertiary: Signal.palette.phosphor

    readonly property color tertiaryContainer: Signal.palette.phosphorWell

    readonly property color errorContainer: Signal.palette.alertWell

    readonly property color outline: Signal.palette.ruleStrong
    readonly property color outlineVariant: Signal.palette.rule
    // Essential component borders must reach 3:1 (WCAG 1.4.11);
    // outlineVariant does not, outline does in every builtin palette.
    readonly property color componentBorder: Signal.palette.ruleStrong
    readonly property color success: Signal.palette.phosphor
    readonly property string fontFamily: Appearance.font.family.sans
    readonly property string monoFontFamily: Appearance.font.family.mono
    readonly property int fontSizeSmall: Appearance.font.size.small
    readonly property int fontSize: Appearance.font.size.normal
    readonly property int fontSizeLarge: Appearance.font.size.large
    // Native type scale (StyledText uses points, not pixels): body is the
    // shell default text size, titles match native card headers.
    readonly property int fontSizeBody: Appearance.font.size.smaller
    readonly property int fontSizeTitle: Appearance.font.size.larger
    readonly property int fontSizeDisplay: Appearance.font.size.extraLarge
    // Native icons (components/Glyph.qml): the bundled Hornero Glyphs font.
    readonly property string iconFontFamily: Glyphs.family
    readonly property int iconSize: Appearance.font.size.larger
    readonly property int iconSizeLarge: Appearance.font.size.large
    readonly property int spacingSmall: Appearance.spacing.small
    readonly property int spacing: Appearance.spacing.normal
    readonly property int spacingLarge: Appearance.spacing.large
    // Native popout content margins (modules/bar/popouts/Content.qml pads
    // every native popout with the large padding token).
    readonly property int padding: Appearance.padding.normal
    readonly property int paddingLarge: Appearance.padding.large
    readonly property int roundingSmall: Appearance.rounding.small
    readonly property int rounding: Appearance.rounding.normal
    readonly property int roundingLarge: Appearance.rounding.large
    // Accessibility inheritance (shell issue 376): plugins get the host's focus,
    // contrast and motion preferences through Theme instead of
    // inventing their own. The palette above already swaps to the
    // high-contrast palette when the host enables it (Signal owns
    // that), so `highContrast` is exposed only for layout/emphasis
    // decisions. Reduced motion is the host's appearance.reducedMotion
    // setting, the system preference, or animation speed 0;
    // `motionDuration()` applies it and the host animation-speed scale
    // to a nominal duration.
    readonly property color focusRing: Signal.palette.focus
    readonly property bool highContrast: Config.appearance.highContrast
    readonly property real animationScale: Appearance.anim.durations.scale
    readonly property bool reducedMotion: Appearance.anim.reduced || animationScale <= 0

    function motionDuration(ms: int): int {
        return reducedMotion ? 0 : Math.round(ms * animationScale);
    }

    // Native state and motion contract (shell components/controls
    // StateLayer, FocusRing and Interactive). Durations already carry the
    // host's scale; reduced motion zeroes them. Plugins never hard-code
    // these numbers, so an extension moves exactly like a native control.
    readonly property int durationSmall: reducedMotion ? 0 : Appearance.anim.durations.short
    readonly property int durationNormal: reducedMotion ? 0 : Appearance.anim.durations.medium
    readonly property var curveStandard: Appearance.anim.curves.standard
    readonly property var curveStandardDecel: Appearance.anim.curves.enter
    readonly property int durationExpressiveFastSpatial: reducedMotion ? 0 : Appearance.anim.durations.settleFast
    readonly property var curveExpressiveFastSpatial: Appearance.anim.curves.settleFast
    // Keyboard-only focus: rings show iff the control has focus AND the
    // last input was a keyboard (docs/FOCUS.md). Pointer users never see them.
    readonly property bool keyboardFocus: FocusMode.keyboard
    // Opacity of the state layer drawn over a control (native StateLayer).
    readonly property real stateHoverOpacity: 0.08
    readonly property real statePressedOpacity: 0.12
}
