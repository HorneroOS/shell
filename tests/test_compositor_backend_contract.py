from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
NIRI = (ROOT / "services/Niri.qml").read_text(encoding="utf-8")
COMPOSITOR_DOC = (ROOT / "docs/COMPOSITORS.md").read_text(encoding="utf-8")
COMPOSITOR_FACADE = (ROOT / "services/Compositor.qml").read_text(encoding="utf-8")
WORKSPACES = (ROOT / "modules/bar/components/workspaces/Workspaces.qml").read_text(encoding="utf-8")
WORKSPACE = (ROOT / "modules/bar/components/workspaces/Workspace.qml").read_text(encoding="utf-8")
VISIBILITIES = (ROOT / "services/Visibilities.qml").read_text(encoding="utf-8")
KEYBOARD_MODEL = (ROOT / "modules/bar/popouts/kblayout/KbLayoutModel.qml").read_text(encoding="utf-8")


def test_niri_backend_subscribes_to_native_event_stream_without_polling():
    assert '["niri", "msg", "--json", "event-stream"]' in NIRI
    assert 'readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""' in NIRI
    assert "readonly property bool available: socketPath !== \"\"" in NIRI
    event_stream = NIRI.split("id: eventStream", 1)[1].split("Process {\n        id: actionProcess", 1)[0]
    assert "running: false" in event_stream, "Niri IPC must remain stopped when a different compositor owns the session"
    assert '"niri", "msg", "--json", "workspaces"' not in NIRI
    assert '"niri", "msg", "--json", "windows"' not in NIRI


def test_niri_disconnect_invalidates_snapshot_before_reconnecting():
    assert "readonly property bool connected: available && eventStream.running && workspacesLoaded" in NIRI
    disconnect = NIRI.split("id: eventStream", 1)[1].split("Process {\n        id: actionProcess", 1)[0]
    for reset in (
        "root.workspaces = null",
        "root.windows = []",
        "root.focusedWindowId = null",
        "root.keyboardLayouts = null",
        "root.actionQueue = []",
        "workspaceActionSocket.connected = false",
        "workspaceReplyTimer.stop()",
    ):
        assert reset in disconnect
    assert disconnect.index("root.workspaces = null") < disconnect.index("reconnectTimer.start()")


def test_niri_backend_keeps_native_workspace_and_window_actions_explicit():
    for action in (
        '"focus-window"',
        '"close-window"',
        '"fullscreen-window"',
        '"move-window-to-workspace"',
    ):
        assert action in NIRI
    assert "actionProcess.exec(command)" in NIRI


def test_niri_workspace_bar_targets_native_workspace_id_across_outputs():
    assert "Socket {" in NIRI
    assert "path: root.socketPath" in NIRI
    assert "pendingWorkspaceFocus = workspace.id" in NIRI
    assert "FocusWorkspace" in NIRI
    assert "Id: Number(root.pendingWorkspaceFocus)" in NIRI
    assert "parser: SplitParser" in NIRI
    assert "root.handleWorkspaceFocusReply(data)" in NIRI
    assert "workspaceReplyTimer.start()" in NIRI
    focus_workspace = NIRI.split("function focusWorkspace(workspaceId: var)", 1)[1].split(
        "function focusWindow(", 1
    )[0]
    assert "workspace.idx" not in focus_workspace
    assert "String(workspaceId)" not in focus_workspace


def test_niri_backend_does_not_claim_hyprland_only_capabilities():
    for capability in (
        "specialWorkspaces: false",
        "compositorLayoutControls: false",
        "liveOutputMetadata: false",
        "nativeWindowThumbnails: false",
        "globalShortcuts: false",
        "workspaceCreate: false",
        "workspaceRename: false",
        "nativeScreenshotSelection: true",
        "customScreenshotRegion: false",
        "hyprlandTuning: false",
        "fullscreenState: false",
    ):
        assert capability in NIRI
    assert "experimental integration" in COMPOSITOR_DOC


def test_workspace_bar_uses_native_niri_workspaces_and_capability_gates():
    assert 'readonly property string backendId: Niri.available ? "niri" : isHyprland ? "hyprland" : "unknown"' in COMPOSITOR_FACADE
    assert 'readonly property string hyprlandInstanceSignature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""' in COMPOSITOR_FACADE
    assert "!Niri.available && hyprlandInstanceSignature !== \"\"" in COMPOSITOR_FACADE
    assert "Niri.workspacesForOutput(screen.name)" in COMPOSITOR_FACADE
    assert "Niri.activeWorkspaceForOutput(screen.name)" in COMPOSITOR_FACADE
    assert "model: root.niriMode ? root.workspaceItems : Config.bar.workspaces.shown" in WORKSPACES
    assert "!root.niriMode" in WORKSPACES
    assert "Niri.windowsForWorkspace(workspaceId)" in COMPOSITOR_FACADE
    assert "Compositor.focusWorkspace(root.niriMode ? root.workspaceData" in WORKSPACE
    assert "Niri.focusWorkspaceDirection(direction)" in COMPOSITOR_FACADE


def test_dashboard_does_not_reserve_blank_area_for_unsupported_window_previews():
    dashboard_workspaces = (ROOT / "modules/dashboard/Workspaces.qml").read_text(
        encoding="utf-8"
    )
    assert (
        'active: Config.dashboard.workspaces.showLivePreview && root.selectedWorkspace !== null '
        '&& Compositor.supports("nativeWindowThumbnails")'
        in dashboard_workspaces
    )
    assert "Layout.preferredHeight: active ? Config.dashboard.workspaces.previewHeight : 0" in dashboard_workspaces


def test_shared_surfaces_use_output_identity_and_native_keyboard_events():
    assert "updated.set(screen.name, visibilities)" in VISIBILITIES
    assert "Compositor.focusedOutputName" in VISIBILITIES
    assert "keyboardLayoutState: true" in NIRI
    assert "keyboardLayoutSwitch: true" in NIRI
    assert "event.KeyboardLayoutsChanged?.keyboard_layouts" in NIRI
    assert "Compositor.switchKeyboardLayout(idx)" in KEYBOARD_MODEL


def test_shared_shell_services_do_not_send_hyprland_commands_to_niri():
    hypr_service = (ROOT / "services/Hypr.qml").read_text(encoding="utf-8")
    idle_monitors = (ROOT / "modules/IdleMonitors.qml").read_text(encoding="utf-8")
    assert '(Quickshell.env("NIRI_SOCKET") ?? "") === ""' in hypr_service
    assert 'action === "dpms off"' in idle_monitors
    assert 'action === "dpms on"' in idle_monitors
    assert "Compositor.setMonitorsPowered(false)" in idle_monitors
    assert "Compositor.setMonitorsPowered(true)" in idle_monitors
    assert "if (Compositor.isHyprland)" in idle_monitors
    assert '"power-off-monitors"' in NIRI


def test_niri_screenshot_uses_native_picker_and_does_not_claim_custom_overlay():
    shell_actions = (ROOT / "services/ShellActions.qml").read_text(encoding="utf-8")
    area_picker = (ROOT / "modules/areapicker/AreaPicker.qml").read_text(encoding="utf-8")
    assert '"niri", "msg", "action", "screenshot"' in NIRI
    assert 'Compositor.supports("nativeScreenshotSelection")' in shell_actions
    assert 'Compositor.openScreenshotPicker();' in area_picker


def test_game_mode_is_not_offered_as_hyprland_tuning_under_niri():
    game_mode = (ROOT / "services/GameMode.qml").read_text(encoding="utf-8")
    assert 'if (!Compositor.supports("hyprlandTuning"))' in game_mode
    for rel in ("modules/utilities/cards/Toggles.qml", "modules/dashboard/dash/QuickToggles.qml"):
        assert 'visible: Compositor.supports("hyprlandTuning")' in (ROOT / rel).read_text(encoding="utf-8")


def test_quickshell_hyprland_global_shortcuts_only_register_in_hyprland():
    shortcut = (ROOT / "components/misc/CustomShortcut.qml").read_text(encoding="utf-8")
    assert 'active: (Quickshell.env("NIRI_SOCKET") ?? "") === ""' in shortcut
    assert "signal pressed()" in shortcut
    assert "signal released()" in shortcut


def test_theme_application_only_reloads_hyprland_owned_files_in_hyprland():
    pipeline = (ROOT / "services/ThemePipeline.qml").read_text(encoding="utf-8")
    assert pipeline.count("if (Compositor.isHyprland) {") >= 2
    assert 'command: ["hyprctl", "reload"]' in pipeline
