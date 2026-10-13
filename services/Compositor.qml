pragma Singleton

import Quickshell
import Quickshell.Io
import qs.services

/**
 * Small, capability-aware facade for compositor state used by shared Shell
 * surfaces. Backend-specific IPC remains in its own service.
 */
Singleton {
    id: root

    property string pendingHyprlandFocusAppId: ""
    property string pendingHyprlandFocusTitlePrefix: ""

    // Prefer the child session even when a compositor is launched nested and
    // inherits its parent's signature from the environment.
    readonly property string hyprlandInstanceSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""
    readonly property bool isHyprland: !Niri.available && hyprlandInstanceSignature !== ""
    readonly property string backendId: Niri.available ? "niri" : isHyprland ? "hyprland" : "unknown"
    readonly property bool isNiri: backendId === "niri"
    readonly property bool connected: isNiri ? Niri.connected : isHyprland
    readonly property string focusedOutputName: isNiri
        ? Niri.focusedOutputName
        : isHyprland ? Hypr.focusedMonitor?.name ?? "" : ""
    readonly property var activeWindow: isNiri
        ? Niri.focusedWindow
        : isHyprland ? Hypr.activeToplevel : null
    readonly property string activeWindowTitle: activeWindow?.title ?? ""
    readonly property string activeWindowAppId: isNiri
        ? activeWindow?.app_id ?? ""
        : isHyprland ? activeWindow?.lastIpcObject?.class ?? "" : ""
    readonly property string keyboardLayoutName: isNiri
        ? Niri.keyboardLayouts?.names?.[Niri.keyboardLayouts?.current_idx ?? -1] ?? ""
        : isHyprland ? Hypr.kbLayoutFull : ""
    readonly property string keyboardLayoutShort: isNiri
        ? keyboardLayoutName.slice(0, 2).toUpperCase()
        : isHyprland ? Hypr.kbLayout : ""
    readonly property bool keyboardLayoutIsDefault: isNiri
        ? (Niri.keyboardLayouts?.current_idx ?? 0) === 0
        : isHyprland ? Hypr.kbLayout === Hypr.defaultKbLayout : true
    readonly property bool capsLock: isHyprland && Hypr.capsLock
    readonly property bool numLock: isHyprland && Hypr.numLock
    readonly property bool hasScreencastSession: isNiri
        && supports("screencastState")
        && Niri.casts.length > 0
    readonly property var capabilities: isNiri ? Niri.capabilities : isHyprland ? ({
        workspaceEvents: true,
        windowEvents: true,
        workspaceFocus: true,
        windowFocus: true,
        windowClose: true,
        windowFloatingToggle: true,
        fullscreen: true,
        fullscreenState: true,
        keyboardLayoutState: true,
        keyboardLayoutSwitch: true,
        lockStatus: true,
        specialWorkspaces: true,
        compositorLayoutControls: true,
        liveOutputMetadata: true,
        nativeWindowThumbnails: true,
        globalShortcuts: true,
        monitorPower: true,
        workspaceCreate: true,
        workspaceRename: true,
        nativeScreenshotSelection: false,
        customScreenshotRegion: true,
        screencastState: false,
        hyprlandTuning: true
    }) : ({})

    function supports(capability: string): bool {
        return capabilities[capability] === true;
    }

    function workspacesForScreen(screen: var): var {
        if (isNiri)
            return Niri.workspacesForOutput(screen.name);
        return isHyprland ? Hypr.workspaces.values : [];
    }

    function activeWorkspaceIdForScreen(screen: var): var {
        if (isNiri)
            return Niri.activeWorkspaceForOutput(screen.name)?.id ?? null;
        return isHyprland ? Hypr.monitorFor(screen)?.activeWorkspace?.id ?? Hypr.activeWsId : null;
    }

    function windowsForWorkspace(workspaceId: var): var {
        if (isNiri)
            return Niri.windowsForWorkspace(workspaceId);
        return isHyprland ? Hypr.toplevels.values.filter(window => window.workspace?.id === workspaceId) : [];
    }

    function workspaceHasWindows(workspace: var): bool {
        if (isNiri)
            return windowsForWorkspace(workspace.id).length > 0;
        return isHyprland && (workspace.lastIpcObject?.windows ?? 0) > 0;
    }

    function workspaceLabel(workspace: var, fallback: var): string {
        if (isNiri) {
            if (workspace.name)
                return String(workspace.name);
            return String(workspace.idx);
        }
        return isHyprland && workspace && workspace.name !== fallback ? String(workspace.name[0]) : String(fallback);
    }

    function isSpecialWorkspaceActive(screen: var, perMonitor: bool): bool {
        if (!isHyprland)
            return false;
        const monitor = perMonitor ? Hypr.monitorFor(screen) : Hypr.focusedMonitor;
        return (monitor?.lastIpcObject?.specialWorkspace?.name ?? "") !== "";
    }

    function toggleSpecialWorkspace(): bool {
        if (!supports("specialWorkspaces"))
            return false;
        Hypr.dispatch("togglespecialworkspace special");
        return true;
    }

    function hasFullscreenOnScreen(screen: var): bool {
        if (!isHyprland)
            return false;
        return Hypr.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(window => window.lastIpcObject.fullscreen === 2) ?? false;
    }

    function hasFullscreenOnFocusedOutput(): bool {
        if (!isHyprland)
            return false;
        return Hypr.focusedWorkspace?.toplevels.values.some(window => window.lastIpcObject.fullscreen === 2) ?? false;
    }

    function activeWorkspaceHasWindows(screen: var): bool {
        const workspaceId = activeWorkspaceIdForScreen(screen);
        return workspaceId !== null && windowsForWorkspace(workspaceId).length > 0;
    }

    function focusWorkspace(workspace: var): bool {
        if (isNiri)
            return Niri.focusWorkspace(workspace.id);
        if (!isHyprland)
            return false;
        Hypr.dispatch(`workspace ${workspace.id}`);
        return true;
    }

    function focusWindow(windowId: var): bool {
        if (isNiri)
            return Niri.focusWindow(windowId);
        if (!isHyprland)
            return false;
        const address = hyprlandAddress(windowId);
        if (address === "")
            return false;
        Hypr.dispatch(`focuswindow address:${address}`);
        return true;
    }

    function closeWindow(windowId: var): bool {
        if (isNiri)
            return Niri.closeWindow(windowId);
        if (!isHyprland)
            return false;
        const address = hyprlandAddress(windowId);
        if (address === "")
            return false;
        Hypr.dispatch(`closewindow address:${address}`);
        return true;
    }

    // Quickshell exposes Hyprland window addresses without the hexadecimal
    // prefix, while Hyprland's address selector requires `address:0x...`.
    // Normalize once at the backend boundary so focus and close requests use
    // the native selector format and callers can keep passing native IDs.
    function hyprlandAddress(windowId: var): string {
        const address = String(windowId ?? "").trim();
        if (address === "")
            return "";
        return address.startsWith("0x") ? address : `0x${address}`;
    }

    function windowIdFor(window: var): var {
        return isNiri ? window?.id ?? null : isHyprland ? window?.address ?? null : null;
    }

    function focusWindowFor(window: var): bool {
        const id = windowIdFor(window);
        return id === null ? false : focusWindow(id);
    }

    function focusWindowByAppIdAndTitlePrefix(appId: string, titlePrefix: string): bool {
        if (isHyprland) {
            // Hyprland's focuswindow dispatcher accepts one selector at a
            // time. Query its live client list so app ID and title are both
            // checked before we dispatch the exact address; Quickshell's
            // toplevel model can lag immediately after a window is created.
            if (hyprlandClientsProcess.running)
                return false;
            pendingHyprlandFocusAppId = appId;
            pendingHyprlandFocusTitlePrefix = titlePrefix;
            hyprlandClientsProcess.running = true;
            return true;
        }

        let window = null;
        if (isNiri) {
            window = Niri.windows.find(item => item.app_id === appId && String(item.title ?? "").startsWith(titlePrefix)) ?? null;
        }
        return window === null ? false : focusWindowFor(window);
    }

    function focusMatchingHyprlandClient(exitCode: int): void {
        const appId = pendingHyprlandFocusAppId;
        const titlePrefix = pendingHyprlandFocusTitlePrefix;
        pendingHyprlandFocusAppId = "";
        pendingHyprlandFocusTitlePrefix = "";
        if (exitCode !== 0)
            return;
        try {
            const clients = JSON.parse(hyprlandClientsOutput.text);
            const client = clients.find(item => item.class === appId && String(item.title ?? "").startsWith(titlePrefix)) ?? null;
            if (client?.address)
                Hypr.dispatch(`focuswindow address:${hyprlandAddress(client.address)}`);
        } catch (error) {
            console.warn(`[Compositor] Could not inspect Hyprland clients before focusing Settings: ${error}`);
        }
    }

    function closeWindowFor(window: var): bool {
        const id = windowIdFor(window);
        return id === null ? false : closeWindow(id);
    }

    function toggleWindowFloating(window: var): bool {
        if (!supports("windowFloatingToggle"))
            return false;
        if (isNiri)
            return Niri.toggleWindowFloating(windowIdFor(window));
        if (!isHyprland)
            return false;
        const address = hyprlandAddress(windowIdFor(window));
        if (address === "")
            return false;
        Hypr.dispatch(`togglefloating address:${address}`);
        return true;
    }

    function toggleFullscreen(): bool {
        if (isNiri)
            return Niri.toggleFullscreen();
        if (!isHyprland)
            return false;
        Hypr.dispatch("fullscreen 0");
        return true;
    }

    function focusWorkspaceDirection(direction: int): bool {
        if (isNiri)
            return Niri.focusWorkspaceDirection(direction);
        if (!isHyprland)
            return false;
        Hypr.dispatch(`workspace r${direction > 0 ? "+" : "-"}1`);
        return true;
    }

    function switchKeyboardLayout(index: int): bool {
        if (isNiri)
            return Niri.switchKeyboardLayout(index);
        return false;
    }

    function setMonitorsPowered(powered: bool): bool {
        if (!supports("monitorPower"))
            return false;
        if (isNiri)
            return Niri.setMonitorsPowered(powered);
        if (isHyprland) {
            Hypr.dispatch(powered ? "dpms on" : "dpms off");
            return true;
        }
        return false;
    }

    function openScreenshotPicker(): bool {
        return isNiri && Niri.openScreenshotPicker();
    }

    function hasOnlyFloatingWindowsOnScreen(screen: var): bool {
        const workspaceId = activeWorkspaceIdForScreen(screen);
        if (workspaceId === null)
            return true;
        const windows = windowsForWorkspace(workspaceId);
        return windows.every(window => isNiri ? window.is_floating : window.lastIpcObject?.floating);
    }

    Process {
        id: hyprlandClientsProcess
        running: false
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            id: hyprlandClientsOutput
        }
        onExited: (exitCode, exitStatus) => root.focusMatchingHyprlandClient(exitCode)
    }
}
