pragma Singleton

import Quickshell
import QtQuick

// Input-modality tracker for the S4 focus contract (docs/FOCUS.md).
// Exactly one bool: focus rings show iff activeFocus && keyboard, so
// pointer users never see stale rings and keyboard focus stays visible.
Singleton {
    id: root

    property bool keyboard: false

    // Called by focusables at onActiveFocusChanged: focus arriving
    // while pressed is pointer-driven, otherwise keyboard-driven.
    function reportFocus(pressed: bool): void {
        root.keyboard = !pressed;
    }

    // Called on any pointer press in shell chrome.
    function reportPointer(): void {
        root.keyboard = false;
    }
}
