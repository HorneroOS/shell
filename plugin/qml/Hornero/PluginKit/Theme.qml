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
}
