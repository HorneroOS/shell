pragma ComponentBehavior: Bound

import qs.services
import QtQuick

// Internal base of the PluginKit Theme singleton: every on* content colour.
// Kept apart from the base-name colours (surface, primary, ...) on purpose:
// declared in the same file, `onSurface: ...` is taken as the handler of
// surfaceChanged and the colour reads as #000000 (shell#427).
QtObject {
    readonly property color onPrimary: Signal.palette.onSignal
    readonly property color onSurface: Signal.palette.ink
    readonly property color onSurfaceVariant: Signal.palette.inkMuted
    readonly property color onBackground: Signal.palette.ink
    readonly property color onPrimaryContainer: Signal.palette.onSignalWell
    readonly property color onSecondary: Signal.palette.onCue
    readonly property color onSecondaryContainer: Signal.palette.onCueWell
    readonly property color onTertiary: Signal.palette.onPhosphor
    readonly property color onTertiaryContainer: Signal.palette.onPhosphorWell
    readonly property color onErrorContainer: Signal.palette.onAlertWell
    readonly property color onError: Signal.palette.onAlert
}
