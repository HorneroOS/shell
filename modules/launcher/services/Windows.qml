pragma Singleton

import qs.services
import "windowfilter.js" as WindowFilter
import Quickshell
import QtQuick

// Windows provider logic (shell#250 slice 1, multi-compositor #736):
// lists open windows from Compositor.allWindowSummaries() (works across
// Hyprland, Niri, and Wayland ToplevelManager) and focuses a chosen
// window through Compositor.focusWindow(). No new IPC is invented here.
Singleton {
    id: root

    // Ranked results in compositor order, shaped
    // { id, title, appClass, workspaceName, address }.
    function query(text: string): list<var> {
        return WindowFilter.filterWindows(Compositor.allWindowSummaries(), text);
    }

    function activate(result: var): void {
        if (!result)
            return;
        const target = result.id ?? result.address;
        if (target !== undefined && target !== null)
            Compositor.focusWindow(target);
    }
}
