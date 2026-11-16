pragma Singleton

import qs.config
import qs.services
import QtQuick

// Content colours (on*) live in ThemeBase: Qt parses a property named
// onX declared beside a property X in one file as the X-changed signal
// handler, so the colour silently resolves to black (shell#427).
ThemeBase {
    // Expose the effective palette mode, including accessibility overrides.
    readonly property bool light: Colours.light
    readonly property color primary: Colours.palette.m3primary

    readonly property color surface: Colours.palette.m3surface
    readonly property color surfaceContainer: Colours.palette.m3surfaceContainer

    readonly property color error: Colours.palette.m3error
    readonly property color background: Colours.palette.m3background

    readonly property color surfaceDim: Colours.palette.m3surfaceDim
    readonly property color surfaceBright: Colours.palette.m3surfaceBright
    readonly property color surfaceContainerLowest: Colours.palette.m3surfaceContainerLowest
    readonly property color surfaceContainerLow: Colours.palette.m3surfaceContainerLow
    readonly property color surfaceContainerHigh: Colours.palette.m3surfaceContainerHigh
    readonly property color surfaceContainerHighest: Colours.palette.m3surfaceContainerHighest
    readonly property color surfaceVariant: Colours.palette.m3surfaceVariant
    readonly property color primaryContainer: Colours.palette.m3primaryContainer

    readonly property color secondary: Colours.palette.m3secondary

    readonly property color secondaryContainer: Colours.palette.m3secondaryContainer

    readonly property color tertiary: Colours.palette.m3tertiary

    readonly property color tertiaryContainer: Colours.palette.m3tertiaryContainer

    readonly property color errorContainer: Colours.palette.m3errorContainer

    readonly property color outline: Colours.palette.m3outline
    readonly property color outlineVariant: Colours.palette.m3outlineVariant
    // Essential component borders must reach 3:1 (WCAG 1.4.11);
    // outlineVariant does not, outline does in every builtin palette.
    readonly property color componentBorder: Colours.palette.m3outline
    readonly property color success: Colours.palette.m3success
    readonly property string fontFamily: Appearance.font.family.sans
    readonly property string monoFontFamily: Appearance.font.family.mono
    readonly property int fontSizeSmall: Appearance.font.size.small
    readonly property int fontSize: Appearance.font.size.normal
    readonly property int fontSizeLarge: Appearance.font.size.large
    readonly property int spacingSmall: Appearance.spacing.small
    readonly property int spacing: Appearance.spacing.normal
    readonly property int spacingLarge: Appearance.spacing.large
    readonly property int roundingSmall: Appearance.rounding.small
    readonly property int rounding: Appearance.rounding.normal
    readonly property int roundingLarge: Appearance.rounding.large
    // Accessibility inheritance (shell issue 376): plugins get the host's focus,
    // contrast and motion preferences through Theme instead of
    // inventing their own. The palette above already swaps to the
    // high-contrast palette when the host enables it (Colours owns
    // that), so `highContrast` is exposed only for layout/emphasis
    // decisions. The host has no separate reduced-motion boolean:
    // animation speed 0 in Accessibility settings is the host's
    // reduced-motion signal, and `motionDuration()` applies both it
    // and the host animation-speed scale to a nominal duration.
    readonly property color focusRing: Colours.focusRing
    readonly property bool highContrast: Config.appearance.highContrast
    readonly property real animationScale: Appearance.anim.durations.scale
    readonly property bool reducedMotion: animationScale <= 0

    function motionDuration(ms: int): int {
        return reducedMotion ? 0 : Math.round(ms * animationScale);
    }

    // Native state and motion contract (shell components/controls
    // StateLayer, FocusRing and Interactive). Durations already carry the
    // host's scale; reduced motion zeroes them. Plugins never hard-code
    // these numbers, so an extension moves exactly like a native control.
    readonly property int durationSmall: reducedMotion ? 0 : Appearance.anim.durations.small
    readonly property int durationNormal: reducedMotion ? 0 : Appearance.anim.durations.normal
    readonly property var curveStandard: Appearance.anim.curves.standard
    readonly property var curveStandardDecel: Appearance.anim.curves.standardDecel
    readonly property int durationExpressiveFastSpatial: reducedMotion ? 0 : Appearance.anim.durations.expressiveFastSpatial
    readonly property var curveExpressiveFastSpatial: Appearance.anim.curves.expressiveFastSpatial
    // Keyboard-only focus: rings show iff the control has focus AND the
    // last input was a keyboard (docs/FOCUS.md). Pointer users never see them.
    readonly property bool keyboardFocus: FocusMode.keyboard
    // Opacity of the state layer drawn over a control (native StateLayer).
    readonly property real stateHoverOpacity: 0.08
    readonly property real statePressedOpacity: 0.12
}
