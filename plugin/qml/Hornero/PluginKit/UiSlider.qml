import QtQuick
import QtQuick.Controls

Slider {
    id: root

    property string accessibleName: "Slider"
    property string tooltipText: ""

    from: 0
    to: 1
    value: 0
    // Keyboard contract (shell issue 376): arrows are native to Slider but step
    // by a fixed 0.1 when stepSize is unset, whatever the range. The
    // default below makes one arrow press 1/20 of the range; a
    // plugin-assigned stepSize replaces it, as with any default.
    // stepSize only affects increase()/decrease() (and snapping when
    // a snapMode is set), never pointer dragging.
    stepSize: (to - from) / 20

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.Slider
    Accessible.description: root.tooltipText

    // One deterministic tab stop while enabled (declaration order is
    // tab order). Home/End/Page keys are not handled natively, so
    // they are added here: Home/End jump to the range ends and
    // PageUp/PageDown move by 1/10 of the range.
    activeFocusOnTab: enabled
    Keys.onPressed: event => {
        if (!enabled)
            return;
        if (event.key === Qt.Key_Home) {
            root.value = root.from;
            root.moved();
            event.accepted = true;
        } else if (event.key === Qt.Key_End) {
            root.value = root.to;
            root.moved();
            event.accepted = true;
        } else if (event.key === Qt.Key_PageUp) {
            root.value = Math.min(root.to, root.value + (root.to - root.from) / 10);
            root.moved();
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown) {
            root.value = Math.max(root.from, root.value - (root.to - root.from) / 10);
            root.moved();
            event.accepted = true;
        }
    }

    UiTooltip {
        target: root
        text: root.tooltipText
    }

    opacity: root.enabled ? 1 : 0.5

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 200
        implicitHeight: 4
        width: root.availableWidth
        height: implicitHeight
        radius: height / 2
        color: Theme.surfaceContainerHighest

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: height / 2
            color: Theme.primary
        }
    }

    handle: Rectangle {
        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 18
        implicitHeight: 18
        radius: width / 2
        color: Theme.primary
        border.width: root.activeFocus ? 2 : 0
        border.color: Theme.onPrimary
    }
}
