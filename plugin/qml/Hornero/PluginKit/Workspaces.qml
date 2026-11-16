pragma Singleton

import qs.services as Services
import Quickshell
import QtQuick

// Workspace state from the shell's compositor abstraction (Hyprland or
// niri; provider domain "workspaces", event-driven). Read-only except
// `focus()`, which plugins call only from a user interaction.
QtObject {
    id: root

    readonly property bool available: Services.Compositor.connected
    readonly property string backend: Services.Compositor.backendId
    readonly property string activeWindowTitle: Services.Compositor.activeWindowTitle
    readonly property string activeWindowAppId: Services.Compositor.activeWindowAppId

    function _screen(screenName: string): var {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++) {
            if (screens[i].name === screenName)
                return screens[i];
        }
        return screens.length > 0 ? screens[0] : null;
    }

    // [{ id, label, active, occupied, special }] for one output (by
    // name; the host injects hostScreenName into desktop widgets).
    function forScreen(screenName: string): var {
        const screen = root._screen(screenName);
        if (!screen || !root.available)
            return [];
        const activeId = Services.Compositor.activeWorkspaceIdForScreen(screen);
        const list = Services.Compositor.workspacesForScreen(screen) ?? [];
        const result = [];
        for (let i = 0; i < list.length; i++) {
            const ws = list[i];
            const name = String(ws.name ?? "");
            result.push({
                "id": ws.id,
                "label": Services.Compositor.workspaceLabel(ws, ws.id),
                "active": ws.id === activeId,
                "occupied": Services.Compositor.workspaceHasWindows(ws),
                "special": name.startsWith("special:")
            });
        }
        return result.sort((a, b) => a.id - b.id);
    }

    function focus(screenName: string, workspaceId: var): bool {
        const screen = root._screen(screenName);
        if (!screen || !root.available)
            return false;
        const ws = (Services.Compositor.workspacesForScreen(screen) ?? []).find(w => w.id === workspaceId);
        return ws ? Services.Compositor.focusWorkspace(ws) : false;
    }
}
