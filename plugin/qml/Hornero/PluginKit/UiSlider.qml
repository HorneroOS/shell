import QtQuick
import QtQuick.Controls

// Signal fader: a 4 px `sunken` track with a 1 px `ruleStrong` outline,
// `signal` fill up to the value and a rectangular fader cap (6 × 16)
// in `ink`. Hover lifts the cap to `lifted` with an outline; there is
// no swell or ripple. Pair it with a UiText "value" readout — a slider
// never stands alone.
Slider {
    id: root

    property string accessibleName: "Slider"
    property string tooltipText: ""

    from: 0
    to: 1
    value: 0
    // One arrow press is 1/20 of the range unless the extension sets
    // stepSize; Home/End/PageUp/PageDown are added below.
    stepSize: (to - from) / 20

    Accessible.name: root.accessibleName
    Accessible.role: Accessible.Slider
    Accessible.description: root.tooltipText

    activeFocusOnTab: enabled
    hoverEnabled: enabled
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

    implicitHeight: 20

    background: Rectangle {
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 160
        implicitHeight: 4
        width: root.availableWidth
        height: implicitHeight
        radius: 1
        color: Theme.palette.sunken
        border.width: 1
        border.color: root.enabled ? Theme.palette.ruleStrong : Theme.palette.rule

        Rectangle {
            width: root.visualPosition * parent.width
            height: parent.height
            radius: 1
            color: root.enabled ? Theme.palette.signal : Theme.palette.inkFaint
        }
    }

    handle: Rectangle {
        id: cap

        x: root.leftPadding + root.visualPosition * (root.availableWidth - width)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: 6
        implicitHeight: 16
        radius: 1
        color: !root.enabled ? Theme.palette.inkFaint : root.pressed || root.hovered ? Theme.palette.lifted : Theme.palette.ink
        border.width: root.pressed || root.hovered ? 1 : 0
        border.color: Theme.palette.ink

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: 3
            color: "transparent"
            border.width: 2
            border.color: Theme.palette.focus
            visible: root.activeFocus && Theme.keyboardFocus && root.enabled
        }
    }
}
