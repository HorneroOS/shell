pragma ComponentBehavior: Bound

import qs.services
import QtQuick

// Internal base of the PluginKit Theme singleton: every on* content colour.
// Kept apart from the base-name colours (surface, primary, ...) on purpose:
// declared in the same file, `onSurface: ...` is taken as the handler of
// surfaceChanged and the colour reads as #000000 (shell#427).
QtObject {
    readonly property color onPrimary: Colours.palette.m3onPrimary
    readonly property color onSurface: Colours.palette.m3onSurface
    readonly property color onSurfaceVariant: Colours.palette.m3onSurfaceVariant
    readonly property color onBackground: Colours.palette.m3onBackground
    readonly property color onPrimaryContainer: Colours.palette.m3onPrimaryContainer
    readonly property color onSecondary: Colours.palette.m3onSecondary
    readonly property color onSecondaryContainer: Colours.palette.m3onSecondaryContainer
    readonly property color onTertiary: Colours.palette.m3onTertiary
    readonly property color onTertiaryContainer: Colours.palette.m3onTertiaryContainer
    readonly property color onErrorContainer: Colours.palette.m3onErrorContainer
    readonly property color onError: Colours.palette.m3onError
}
