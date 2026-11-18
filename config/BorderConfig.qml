import Quickshell.Io

JsonObject {
    property bool frameEnabled: true
    property int thickness: Appearance.padding.normal
    property int rounding: Appearance.rounding.small
    // Width of the edge line drawn where the frame meets the desktop; 0 hides it.
    // High Contrast never draws it thinner than 2 px (Border.qml).
    property int edgeWidth: 1
}
