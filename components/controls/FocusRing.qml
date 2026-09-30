import ".."
import qs.services
import QtQuick

// Shared S4 focus ring (docs/FOCUS.md): 2 px primary outline floating
// 2 px off the parent shape. Callers set radius to match their shape.
// Shown for keyboard focus only; never shifts layout.
StyledRect {
    anchors.fill: parent
    anchors.margins: -2

    color: "transparent"
    border.width: 2
    border.color: Colours.focusRing
    visible: parent.visible && parent.activeFocus && FocusMode.keyboard && parent.enabled
}
