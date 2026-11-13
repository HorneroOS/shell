pragma Singleton

import qs.services
import "windowfilter.js" as WindowFilter
import Quickshell
import QtQuick

// Windows provider logic (shell#250 slice 1): lists open windows
// from the compositor toplevels the shell already tracks
// (Hypr.toplevels, the same source the bar uses) and focuses a
// chosen window through the shell's existing activation path
// (Hypr.dispatch). No new IPC is invented here. Hyprland-only
// today; Niri rows arrive with its window read model.
Singleton {
    id: root

    // Ranked results in compositor order, shaped
    // { title, appClass, workspaceName, address }.
    function query(text: string): list<var> {
        const rows = Hypr.toplevels.values.map(w => ({
                    "title": w.title ?? "",
                    "appClass": w.lastIpcObject.class ?? "",
                    "workspaceName": w.workspace?.name ?? "?",
                    "address": w.address
                }));
        return WindowFilter.filterWindows(rows, text);
    }

    function activate(result: var): void {
        if (result && result.address !== undefined && result.address !== null)
            Hypr.dispatch(`focuswindow address:0x${result.address}`);
    }
}
