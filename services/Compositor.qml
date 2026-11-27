pragma Singleton

import "experience.js" as ExperienceModel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland as Wayland
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
    readonly property var activeWindowWayland: isHyprland ? Hypr.activeToplevel?.wayland ?? null : null
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
    readonly property bool hasActiveScreencast: hasScreencastSession
        && Niri.casts.some(cast => cast.is_active === true)
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

    function activeWorkspaceIdForScreen(screen: var, perMonitor: var): var {
        if (isNiri)
            return Niri.activeWorkspaceForOutput(screen.name)?.id ?? null;
        if (!isHyprland)
            return null;
        if (perMonitor === false)
            return Hypr.activeWsId;
        return Hypr.monitorFor(screen)?.activeWorkspace?.id ?? Hypr.activeWsId;
    }

    function workspacesVisibleElsewhere(screen: var): var {
        if (isNiri || !isHyprland)
            return ({});
        const mine = Hypr.monitorFor(screen);
        const out = ({});
        for (const mon of Hypr.monitors.values) {
            if (mine && mon.id === mine.id)
                continue;
            const id = mon.activeWorkspace?.id;
            if (id !== undefined && id !== null)
                out[id] = true;
        }
        return out;
    }

    function windowAppId(window: var): string {
        if (!window)
            return "";
        if (isNiri)
            return window.app_id ?? "";
        if (isHyprland)
            return window.lastIpcObject?.class ?? "";
        return window.appId ?? "";
    }

    function workspaceDisplayName(wsId: var, workspaceData: var, capitalisation: string): string {
        if (isNiri)
            return workspaceLabel(workspaceData, wsId);
        if (!isHyprland)
            return String(wsId ?? "");
        const ws = Hypr.workspaces.values.find(w => w.id === wsId);
        const wsName = !ws || ws.name == wsId ? wsId : ws.name[0];
        const raw = String(wsName);
        const cap = String(capitalisation ?? "").toLowerCase();
        if (cap === "upper")
            return raw.toUpperCase();
        if (cap === "lower")
            return raw.toLowerCase();
        return raw;
    }

    function allWindowSummaries(): var {
        if (isNiri) {
            const wsMap = ({});
            for (const ws of (Niri.workspaces ?? []))
                wsMap[ws.id] = ws.name ? String(ws.name) : String(ws.idx);
            return Niri.windows.map(w => ({
                        "id": w.id,
                        "address": String(w.id),
                        "title": w.title ?? "",
                        "appClass": w.app_id ?? "",
                        "workspaceId": w.workspace_id ?? null,
                        "workspaceName": wsMap[w.workspace_id] ?? "?",
                        "activated": w.is_focused === true || Niri.focusedWindowId === w.id,
                        "floating": w.is_floating === true,
                        "isNiri": true,
                        "wayland": null
                    }));
        }
        if (isHyprland) {
            return Hypr.toplevels.values.map(w => ({
                        "id": w.address,
                        "address": w.address,
                        "title": w.title ?? "",
                        "appClass": w.lastIpcObject?.class ?? "",
                        "workspaceId": w.workspace?.id ?? null,
                        "workspaceName": w.workspace?.name ?? "?",
                        "activated": w.wayland?.activated === true,
                        "floating": w.lastIpcObject?.floating === true,
                        "isNiri": false,
                        "wayland": w.wayland ?? null
                    }));
        }
        const tl = Wayland.ToplevelManager?.toplevels?.values ?? [];
        return tl.map((w, idx) => ({
                    "id": w,
                    "address": String(idx),
                    "title": w.title ?? "",
                    "appClass": w.appId ?? "",
                    "workspaceId": null,
                    "workspaceName": "?",
                    "activated": w.activated === true,
                    "floating": false,
                    "isNiri": false,
                    "wayland": w
                }));
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
        return Hypr.monitorFor(screen)?.activeWorkspace?.toplevels.values.some(window => ExperienceModel.isFullscreenState(window.lastIpcObject.fullscreen)) ?? false;
    }

    function hasFullscreenOnFocusedOutput(): bool {
        if (!isHyprland)
            return false;
        return Hypr.focusedWorkspace?.toplevels.values.some(window => ExperienceModel.isFullscreenState(window.lastIpcObject.fullscreen)) ?? false;
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
        if (isHyprland) {
            const address = hyprlandAddress(windowId);
            if (address === "")
                return false;
            Hypr.dispatch(`focuswindow address:${address}`);
            return true;
        }
        if (windowId && typeof windowId.activate === "function") {
            windowId.activate();
            return true;
        }
        return false;
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

    function scrollWorkspace(screen: var, perMonitor: bool, deltaY: real): bool {
        if (deltaY === 0)
            return false;
        if (isNiri)
            return focusWorkspaceDirection(deltaY > 0 ? -1 : 1);
        if (!isHyprland)
            return false;
        const mon = perMonitor ? Hypr.monitorFor(screen) : Hypr.focusedMonitor;
        const specialWs = mon?.lastIpcObject?.specialWorkspace?.name ?? "";
        if (specialWs.length > 0) {
            Hypr.dispatch(`togglespecialworkspace ${specialWs.slice(8)}`);
            return true;
        }
        if (deltaY < 0 || (perMonitor ? (mon?.activeWorkspace?.id ?? 1) : Hypr.activeWsId) > 1) {
            Hypr.dispatch(`workspace r${deltaY > 0 ? "-" : "+"}1`);
            return true;
        }
        return false;
    }

    function activeSpecialWorkspaceName(screen: var, perMonitor: bool): string {
        if (!isHyprland)
            return "";
        const mon = perMonitor ? Hypr.monitorFor(screen) : Hypr.focusedMonitor;
        return mon?.lastIpcObject?.specialWorkspace?.name ?? "";
    }

    function toggleSpecialWorkspaceByName(name: string): bool {
        if (!supports("specialWorkspaces") || !name)
            return false;
        const shortName = name.startsWith("special:") ? name.slice("special:".length) : name;
        Hypr.dispatch(`togglespecialworkspace ${shortName}`);
        return true;
    }

    function renameWorkspace(wsId: var, name: string): bool {
        const trimmed = String(name ?? "").trim();
        if (!supports("workspaceRename") || trimmed === "")
            return false;
        Hypr.dispatch(`workspace name:${trimmed}:${wsId}`);
        return true;
    }

    function createEmptyWorkspace(): bool {
        if (!supports("workspaceCreate"))
            return false;
        Hypr.dispatch("workspace empty");
        return true;
    }

    function pinWindowFor(window: var): bool {
        if (!isHyprland)
            return false;
        const address = hyprlandAddress(windowIdFor(window));
        if (address === "")
            return false;
        Hypr.dispatch(`pin address:${address}`);
        return true;
    }

    function moveWindowToWorkspace(window: var, wsId: var, follow: bool): bool {
        const id = windowIdFor(window);
        if (id === null)
            return false;
        if (isNiri)
            return Niri.moveWindowToWorkspace(id, wsId, follow === true);
        if (!isHyprland)
            return false;
        const address = hyprlandAddress(id);
        if (address === "")
            return false;
        Hypr.dispatch(`movetoworkspace ${wsId},address:${address}`);
        return true;
    }

    function isScreenFocused(screen: var): bool {
        if (!screen)
            return false;
        if (isNiri)
            return screen.name === focusedOutputName;
        if (isHyprland)
            return Hypr.monitorFor(screen)?.focused === true;
        return false;
    }

    function screenMatchesId(screen: var, id: int): bool {
        if (!screen || !isHyprland)
            return false;
        return Hypr.monitorFor(screen)?.id === id;
    }

    function outputMetadataFor(screen: var): var {
        if (!screen)
            return { hz: NaN, scale: NaN };
        if (isNiri)
            return Niri.outputMetadata(screen.name);
        if (isHyprland) {
            const ipc = Hypr.monitorFor(screen)?.lastIpcObject ?? null;
            const hz = ipc && ipc.refreshRate !== undefined ? Number(ipc.refreshRate) : NaN;
            const scale = ipc && ipc.scale !== undefined ? Number(ipc.scale) : NaN;
            return { hz: hz, scale: scale };
        }
        return { hz: NaN, scale: NaN };
    }

    function pickerClientsForScreen(screen: var): var {
        if (!isHyprland || !screen)
            return [];
        const mon = Hypr.monitorFor(screen);
        if (!mon)
            return [];
        const special = mon.lastIpcObject.specialWorkspace;
        const wsId = special.name ? special.id : mon.activeWorkspace.id;
        return Hypr.toplevels.values.filter(c => c.workspace?.id === wsId).sort((a, b) => {
            const ac = a.lastIpcObject;
            const bc = b.lastIpcObject;
            return (bc.pinned - ac.pinned) || ((bc.fullscreen !== 0) - (ac.fullscreen !== 0)) || (bc.floating - ac.floating);
        });
    }

    function borderWidth(onClient: bool): real {
        if (!onClient)
            return 2;
        return isHyprland ? (Hypr.options?.["general:border_size"] ?? 1) : 1;
    }

    function borderRounding(onClient: bool): real {
        if (!onClient)
            return 0;
        return isHyprland ? (Hypr.options?.["decoration:rounding"] ?? 0) : 0;
    }

    function refreshOptions(): void {
        if (isHyprland && Hypr.extras)
            Hypr.extras.refreshOptions();
    }

    function activeWorkspaceBaseId(): int {
        return isHyprland ? Hypr.activeWsId : 1;
    }

    function windowDetails(window: var): var {
        if (!window)
            return null;
        if (isNiri) {
            const ws = Niri.workspaces?.find(w => w.id === window.workspace_id) ?? null;
            return {
                "title": window.title ?? "",
                "appClass": window.app_id ?? "",
                "address": String(window.id ?? ""),
                "x": -1,
                "y": -1,
                "width": -1,
                "height": -1,
                "workspaceName": ws ? workspaceLabel(ws, ws.id) : "?",
                "workspaceId": window.workspace_id ?? -1,
                "monitorName": ws?.output ?? "unknown",
                "monitorId": -1,
                "monitorX": 0,
                "monitorY": 0,
                "initialTitle": window.title ?? "unknown",
                "initialClass": window.app_id ?? "unknown",
                "pid": window.pid ?? -1,
                "floating": window.is_floating === true,
                "xwayland": false,
                "pinned": false,
                "fullscreen": -1,
                "wayland": null
            };
        }
        const ipc = window.lastIpcObject ?? ({});
        const mon = window.monitor ?? null;
        return {
            "title": window.title ?? "",
            "appClass": ipc.class ?? "",
            "address": window.address ? `0x${window.address}` : "unknown",
            "x": ipc.at?.[0] ?? -1,
            "y": ipc.at?.[1] ?? -1,
            "width": ipc.size?.[0] ?? -1,
            "height": ipc.size?.[1] ?? -1,
            "workspaceName": window.workspace?.name ?? -1,
            "workspaceId": window.workspace?.id ?? -1,
            "monitorName": mon?.name ?? "",
            "monitorId": mon?.id ?? -1,
            "monitorX": mon?.x ?? 0,
            "monitorY": mon?.y ?? 0,
            "initialTitle": ipc.initialTitle ?? "unknown",
            "initialClass": ipc.initialClass ?? "unknown",
            "pid": ipc.pid ?? -1,
            "floating": ipc.floating === true,
            "xwayland": ipc.xwayland === true,
            "pinned": ipc.pinned === true,
            "fullscreen": ipc.fullscreen ?? -1,
            "wayland": window.wayland ?? null
        };
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

    // Raw `hyprctl binds -j` output for the Welcome Shortcuts fallback
    // (packaged manifest missing on a clean profile). Empty string until
    // loaded or when the compositor is not Hyprland.
    property string hyprlandBindsJson: ""
    property bool hyprlandBindsLoaded: false

    function refreshHyprlandBinds(): void {
        if (!isHyprland) {
            hyprlandBindsJson = "";
            hyprlandBindsLoaded = true;
            return;
        }
        hyprlandBindsProcess.running = true;
    }

    Process {
        id: hyprlandBindsProcess
        running: false
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hyprlandBindsJson = text;
                root.hyprlandBindsLoaded = true;
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.hyprlandBindsLoaded = true;
        }
    }
}
