import Quickshell.Io

JsonObject {
    property bool frameEnabled: true
    property int thickness: 6
    property int rounding: Appearance.rounding.small
    // Width of the edge line drawn where the frame meets the desktop; 0 hides it.
    // High Contrast never draws it thinner than 2 px (Border.qml).
    property int edgeWidth: 1
    // Machined fillet (Signal visual language §7.1): radius of the small
    // concave arc where an attached drawer or popout meets the bar or the
    // frame, so the sheet reads as milled from the same plate. 0 keeps the
    // flush junction. Clamped to 0-16 where it is drawn.
    property int fillet: 6
}
