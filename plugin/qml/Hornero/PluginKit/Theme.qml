pragma Singleton

import qs.config
import QtQuick

QtObject {
    // Expose the effective palette mode, including accessibility overrides.
    readonly property bool light: Colours.light
    readonly property color primary: Colours.palette.m3primary
    readonly property color onPrimary: Colours.palette.m3onPrimary
    readonly property color surface: Colours.palette.m3surface
    readonly property color surfaceContainer: Colours.palette.m3surfaceContainer
    readonly property color onSurface: Colours.palette.m3onSurface
    readonly property color onSurfaceVariant: Colours.palette.m3onSurfaceVariant
    readonly property color error: Colours.palette.m3error
    readonly property color background: Colours.palette.m3background
    readonly property color onBackground: Colours.palette.m3onBackground
    readonly property color surfaceDim: Colours.palette.m3surfaceDim
    readonly property color surfaceBright: Colours.palette.m3surfaceBright
    readonly property color surfaceContainerLowest: Colours.palette.m3surfaceContainerLowest
    readonly property color surfaceContainerLow: Colours.palette.m3surfaceContainerLow
    readonly property color surfaceContainerHigh: Colours.palette.m3surfaceContainerHigh
    readonly property color surfaceContainerHighest: Colours.palette.m3surfaceContainerHighest
    readonly property color surfaceVariant: Colours.palette.m3surfaceVariant
    readonly property color primaryContainer: Colours.palette.m3primaryContainer
    readonly property color onPrimaryContainer: Colours.palette.m3onPrimaryContainer
    readonly property color secondary: Colours.palette.m3secondary
    readonly property color onSecondary: Colours.palette.m3onSecondary
    readonly property color secondaryContainer: Colours.palette.m3secondaryContainer
    readonly property color onSecondaryContainer: Colours.palette.m3onSecondaryContainer
    readonly property color tertiary: Colours.palette.m3tertiary
    readonly property color onTertiary: Colours.palette.m3onTertiary
    readonly property color tertiaryContainer: Colours.palette.m3tertiaryContainer
    readonly property color onTertiaryContainer: Colours.palette.m3onTertiaryContainer
    readonly property color errorContainer: Colours.palette.m3errorContainer
    readonly property color onErrorContainer: Colours.palette.m3onErrorContainer
    readonly property color onError: Colours.palette.m3onError
    readonly property color outline: Colours.palette.m3outline
    readonly property color outlineVariant: Colours.palette.m3outlineVariant
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
}
