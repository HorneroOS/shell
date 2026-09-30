pragma Singleton

import Quickshell
import QtQuick

// Input-modality tracker and Tab scope for the S4 focus contract
// (docs/FOCUS.md). Focus rings show iff activeFocus && keyboard, so
// pointer users never see stale rings and keyboard focus stays visible.
Singleton {
    id: root

    property bool keyboard: false

    // Content root of the drawer that currently holds the keyboard
    // (set by Drawers while its focus grab is active). The bar and
    // every drawer share one window and Qt's tab chain spans the
    // whole window — a FocusScope does not confine it (#84) — so Tab
    // is trapped here instead.
    property Item currentRoot: null

    // Called by focusables at onActiveFocusChanged: focus arriving
    // while pressed is pointer-driven, otherwise keyboard-driven.
    function reportFocus(pressed: bool): void {
        root.keyboard = !pressed;
    }

    // Called on any pointer press in shell chrome.
    function reportPointer(): void {
        root.keyboard = false;
    }

    function contains(scope: Item, item: Item): bool {
        for (let it = item; it; it = it.parent)
            if (it === scope)
                return true;
        return false;
    }

    // Moves focus to the next/previous tab stop inside currentRoot.
    // Returns false when no trap applies (no root, or the item lives
    // outside it) so Qt's default traversal runs.
    function step(from: Item, forward: bool): bool {
        const scope = root.currentRoot;
        if (!scope || !from || !contains(scope, from))
            return false;
        let it = from;
        for (let guard = 0; guard < 256; guard++) {
            it = it.nextItemInFocusChain(forward);
            if (!it || it === from)
                break;
            if (it.visible && it.enabled && contains(scope, it)) {
                it.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
                root.keyboard = true;
                return true;
            }
        }
        // Single stop: stay put rather than leak out of the drawer.
        return true;
    }

    // Enters currentRoot at its first (forward) or last stop. Used by
    // the drawers root key handler when Qt focus sits outside the
    // drawer; false when there is no root, so Tab falls through.
    function enter(forward: bool): bool {
        const scope = root.currentRoot;
        if (!scope)
            return false;
        let it = scope;
        for (let guard = 0; guard < 512; guard++) {
            it = it.nextItemInFocusChain(forward);
            if (!it || it === scope)
                break;
            if (it.visible && it.enabled && it.activeFocusOnTab && contains(scope, it)) {
                it.forceActiveFocus(forward ? Qt.TabFocusReason : Qt.BacktabFocusReason);
                root.keyboard = true;
                return true;
            }
        }
        return true;
    }

    // Shared Keys.onTabPressed/onBacktabPressed body. Items handle Tab
    // before it propagates to parents, so every focusable delegates
    // here (a parent-level trap is bypassed, #84 prototype T2).
    // Shift+Tab can arrive as Key_Tab + Shift, so both mean backwards.
    function handleTab(item: Item, event: KeyEvent, backtab: bool): void {
        const forward = !backtab && !(event.modifiers & Qt.ShiftModifier);
        event.accepted = root.step(item, forward);
    }
}
