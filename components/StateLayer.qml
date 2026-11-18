import qs.services
import qs.config
import Quickshell.Widgets
import QtQuick

// Hover/pressed wash (signal-visual-language §8): hover and pressed are
// flat fills only — no ripple, no scale. `color` is the wash ink; the
// layer tints it at 8 % (hover) / 12 % (pressed) over the owner's fill.
MouseArea {
    id: root

    property bool disabled
    property bool showHoverBackground: true
    property color color: Signal.palette.ink
    property real radius: parent?.radius ?? 0
    property alias rect: hoverLayer

    function onClicked(): void {
    }

    anchors.fill: parent

    enabled: !disabled
    cursorShape: disabled ? undefined : Qt.PointingHandCursor
    hoverEnabled: true

    onClicked: event => !disabled && onClicked(event)

    // Plain ClippingRectangle, not StyledClippingRect: that one already
    // animates `color` (a Behavior on its shader's backgroundColor), and a
    // second Behavior here would register a second interceptor on the same
    // property ("Attempting to set another interceptor ... unsupported").
    ClippingRectangle {
        id: hoverLayer

        anchors.fill: parent

        color: Qt.alpha(root.color, root.disabled ? 0 : root.pressed ? 0.12 : (root.showHoverBackground && root.containsMouse) ? 0.08 : 0)
        radius: root.radius

        Behavior on color {
            CAnim {
                duration: Appearance.anim.durations.quick
                easing.bezierCurve: Appearance.anim.curves.standard
            }
        }
    }
}
