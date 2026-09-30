import ".."
import qs.services
import QtQuick

// Activatable StateLayer: the single S4 keyboard-contract
// implementation (docs/FOCUS.md). Tab stop + Enter/Space activation
// + outer focus ring + focus-reason report. Controls swap their
// StateLayer for this one line; presentational StateLayers stay as
// they are and remain unfocusable.
StateLayer {
    id: root

    // Click-to-focus: without this, Space/Enter after a mouse click
    // would fire on a stale focused control. The modality report
    // below keeps the ring keyboard-only.
    focus: !root.disabled
    activeFocusOnTab: !root.disabled
    onActiveFocusChanged: {
        if (activeFocus)
            FocusMode.reportFocus(root.pressed);
    }
    onPressedChanged: {
        if (pressed)
            FocusMode.reportPointer();
    }

    Keys.onReturnPressed: {
        if (!root.disabled)
            root.clicked();
    }
    Keys.onEnterPressed: {
        if (!root.disabled)
            root.clicked();
    }
    Keys.onSpacePressed: {
        if (!root.disabled)
            root.clicked();
    }

    FocusRing {
        radius: root.radius + 2
    }
}
