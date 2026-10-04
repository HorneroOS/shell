pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool available: Quickshell.env("NIRI_SOCKET") !== ""
    readonly property bool connected: available && workspacesLoaded
    readonly property bool workspacesLoaded: workspaces !== null
    readonly property var capabilities: ({
            workspaceEvents: true,
            windowEvents: true,
            workspaceFocus: true,
            windowFocus: true,
            windowClose: true,
            windowFloatingToggle: true,
            fullscreen: true,
            fullscreenState: false,
            keyboardLayoutState: true,
            keyboardLayoutSwitch: true,
            lockStatus: false,
            specialWorkspaces: false,
            compositorLayoutControls: false,
            liveOutputMetadata: false,
            nativeWindowThumbnails: false,
            globalShortcuts: false,
            monitorPower: true,
            workspaceCreate: false,
            workspaceRename: false,
            nativeScreenshotSelection: true,
            customScreenshotRegion: false,
            hyprlandTuning: false
        })

    property var workspaces: null
    property var windows: []
    property var focusedWindowId: null
    property var keyboardLayouts: null
    property string lastError: ""
    property int connectionGeneration: 0
    property var actionQueue: []
    property var pendingWorkspaceFocus: null

    readonly property var focusedWindow: focusedWindowId !== null
        ? windows.find(window => window.id === focusedWindowId) ?? null
        : windows.find(window => window.is_focused) ?? null
    readonly property var focusedWorkspace: workspaces?.find(workspace => workspace.is_focused) ?? null
    readonly property string focusedOutputName: focusedWorkspace?.output ?? ""

    signal stateChanged

    function consumeEventLine(line: string): void {
        let event;
        try {
            event = JSON.parse(line);
        } catch (error) {
            console.warn("[Compositor:Niri] Ignoring invalid event JSON:", error);
            return;
        }

        if (!event || typeof event !== "object")
            return;

        if (event.WorkspacesChanged?.workspaces instanceof Array)
            workspaces = event.WorkspacesChanged.workspaces;

        if (event.WindowsChanged?.windows instanceof Array)
            windows = event.WindowsChanged.windows;

        if (event.WindowOpenedOrChanged?.window) {
            const updated = event.WindowOpenedOrChanged.window;
            const index = windows.findIndex(window => window.id === updated.id);
            const next = windows.map(window => updated.is_focused
                ? Object.assign({}, window, { is_focused: false })
                : window);
            if (index === -1)
                next.push(updated);
            else {
                next[index] = updated;
            }
            windows = next;
        }

        if (event.WindowClosed && "id" in event.WindowClosed) {
            windows = windows.filter(window => window.id !== event.WindowClosed.id);
            if (focusedWindowId === event.WindowClosed.id)
                focusedWindowId = null;
        }

        if (event.WindowFocusChanged && "id" in event.WindowFocusChanged) {
            focusedWindowId = event.WindowFocusChanged.id;
            windows = windows.map(window => Object.assign({}, window, {
                is_focused: window.id === focusedWindowId
            }));
        }

        if (event.KeyboardLayoutsChanged?.keyboard_layouts)
            keyboardLayouts = event.KeyboardLayoutsChanged.keyboard_layouts;
        if (event.KeyboardLayoutSwitched && Number.isInteger(event.KeyboardLayoutSwitched.idx) && keyboardLayouts) {
            keyboardLayouts = Object.assign({}, keyboardLayouts, {
                current_idx: event.KeyboardLayoutSwitched.idx
            });
        }

        if (event.WorkspaceActivated && "id" in event.WorkspaceActivated) {
            const activated = workspaces?.find(workspace => workspace.id === event.WorkspaceActivated.id) ?? null;
            if (activated) {
                workspaces = workspaces.map(workspace => {
                    const sameOutput = workspace.output === activated.output;
                    return Object.assign({}, workspace, {
                        is_active: sameOutput ? workspace.id === activated.id : workspace.is_active,
                        is_focused: event.WorkspaceActivated.focused
                            ? workspace.id === activated.id
                            : workspace.is_focused
                    });
                });
            }
        }

        if (Object.keys(event).length > 0) {
            lastError = "";
            stateChanged();
        }
    }

    function focusWorkspace(workspaceId: var): bool {
        const workspace = workspaces?.find(item => item.id === workspaceId) ?? null;
        if (!workspace || workspaceActionSocket.connected)
            return false;

        // Index references are relative to the focused output. Send the
        // native workspace ID over Niri's JSON IPC so a click on another
        // monitor's bar targets that exact workspace without switching the
        // focused output first.
        pendingWorkspaceFocus = workspace.id;
        workspaceActionSocket.connected = true;
        return true;
    }

    function handleWorkspaceFocusReply(line: string): void {
        try {
            const reply = JSON.parse(line);
            if (reply?.Err)
                lastError = String(reply.Err);
        } catch (error) {
            lastError = qsTr("The compositor returned an invalid workspace response.");
        }
        pendingWorkspaceFocus = null;
        workspaceActionSocket.connected = false;
        workspaceReplyTimer.stop();
    }

    function focusWindow(windowId: var): bool {
        if (!windows.some(window => window.id === windowId))
            return false;
        return runAction(["niri", "msg", "action", "focus-window", "--id", String(windowId)]);
    }

    function closeWindow(windowId: var): bool {
        if (!windows.some(window => window.id === windowId))
            return false;
        return runAction(["niri", "msg", "action", "close-window", "--id", String(windowId)]);
    }

    function toggleWindowFloating(windowId: var): bool {
        if (!windows.some(window => window.id === windowId))
            return false;
        return runAction(["niri", "msg", "action", "toggle-window-floating", "--id", String(windowId)]);
    }

    function toggleFullscreen(): bool {
        return runAction(["niri", "msg", "action", "fullscreen-window"]);
    }

    function setMonitorsPowered(powered: bool): bool {
        return runAction(["niri", "msg", "action", powered ? "power-on-monitors" : "power-off-monitors"]);
    }

    function focusWorkspaceDirection(direction: int): bool {
        if (direction === 0)
            return false;
        return runAction(["niri", "msg", "action", direction > 0 ? "focus-workspace-down" : "focus-workspace-up"]);
    }

    function switchKeyboardLayout(index: int): bool {
        if (!keyboardLayouts?.names || index < 0 || index >= keyboardLayouts.names.length)
            return false;
        return runAction(["niri", "msg", "action", "switch-layout", String(index)]);
    }

    function openScreenshotPicker(): bool {
        // Niri owns the region UI and writes to screenshot-path + clipboard.
        // The Shell's geometry picker depends on Hyprland window metadata.
        return runAction(["niri", "msg", "action", "screenshot"]);
    }

    function moveWindowToWorkspace(windowId: var, workspaceId: var, follow: bool): bool {
        if (!windows.some(window => window.id === windowId))
            return false;
        const workspace = workspaces?.find(item => item.id === workspaceId) ?? null;
        if (!workspace)
            return false;

        const reference = workspace.name ? workspace.name : String(workspace.idx);
        return runAction([
            "niri", "msg", "action", "move-window-to-workspace", "--window-id", String(windowId),
            "--focus", follow ? "true" : "false", reference
        ]);
    }

    function workspacesForOutput(outputName: string): var {
        if (!workspaces || !outputName)
            return [];
        return workspaces.filter(workspace => workspace.output === outputName)
            .sort((a, b) => a.idx - b.idx);
    }

    function activeWorkspaceForOutput(outputName: string): var {
        return workspaces?.find(workspace => workspace.output === outputName && workspace.is_active) ?? null;
    }

    function windowsForWorkspace(workspaceId: var): var {
        return windows.filter(window => window.workspace_id === workspaceId);
    }

    function runAction(command: list<string>): bool {
        if (!available || actionQueue.length >= 64)
            return false;
        actionQueue = actionQueue.concat([command]);
        if (!actionProcess.running)
            runNextAction();
        return true;
    }

    function runNextAction(): void {
        if (!available || actionProcess.running || actionQueue.length === 0)
            return;
        const command = actionQueue[0];
        actionQueue = actionQueue.slice(1);
        lastError = "";
        actionProcess.exec(command);
    }

    Component.onCompleted: {
        if (available)
            eventStream.running = true;
    }

    Process {
        id: eventStream

        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: data => root.consumeEventLine(data)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message)
                    root.lastError = message;
            }
        }
        onStarted: root.connectionGeneration++
        onExited: {
            if (root.available)
                reconnectTimer.start();
        }
    }

    Process {
        id: actionProcess

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message)
                    root.lastError = message;
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0 && !root.lastError)
                root.lastError = qsTr("The compositor rejected the requested action.");
            Qt.callLater(() => root.runNextAction());
        }
    }

    Socket {
        id: workspaceActionSocket

        path: Quickshell.env("NIRI_SOCKET")
        onConnectedChanged: {
            if (!connected || root.pendingWorkspaceFocus === null)
                return;
            const request = {
                Action: {
                    FocusWorkspace: {
                        reference: {
                            Id: Number(root.pendingWorkspaceFocus)
                        }
                    }
                }
            };
            write(JSON.stringify(request) + "\n");
            flush();
            workspaceReplyTimer.start();
        }
        onError: error => {
            root.lastError = String(error);
            root.pendingWorkspaceFocus = null;
            workspaceReplyTimer.stop();
            connected = false;
        }
        parser: SplitParser {
            onRead: data => root.handleWorkspaceFocusReply(data)
        }
    }

    Timer {
        id: workspaceReplyTimer

        interval: 2000
        repeat: false
        onTriggered: {
            if (root.pendingWorkspaceFocus === null)
                return;
            root.lastError = qsTr("The compositor did not confirm the workspace change.");
            root.pendingWorkspaceFocus = null;
            workspaceActionSocket.connected = false;
        }
    }

    Timer {
        id: reconnectTimer

        interval: 5000
        repeat: false
        onTriggered: {
            if (root.available)
                eventStream.running = true;
        }
    }
}
