"""Javi chat contract (shell#234, #238, #239, #240, #241).

Static QML contract tests: streaming NDJSON consumption, scrollable
markdown bubbles, persistent history, server-side stop, clarify card,
voice recording, attachments, Javi naming, and the Control Center
assistant section. Regressions should fail here, not in a live shell.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPANION = ROOT / "modules" / "companion"
BRIDGE = (COMPANION / "AssistantBridge.qml").read_text()
PANEL = (COMPANION / "ChatPanel.qml").read_text()
STORE = (COMPANION / "CompanionStore.qml").read_text()
PANE = (ROOT / "modules" / "controlcenter" / "companion" / "CompanionPane.qml").read_text()
REGISTRY = (ROOT / "modules" / "controlcenter" / "PaneRegistry.qml").read_text()


def test_bridge_streams_ndjson_deltas():
    assert '"--stream"' in BRIDGE
    assert 'obj.type === "delta"' in BRIDGE
    assert "streamText" in BRIDGE


def test_bridge_uses_structured_pending_not_prose():
    assert 'data.pending' in BRIDGE or '(payload.data.pending' in BRIDGE or 'payload.data && (payload.data.pending' in BRIDGE
    assert "pendingClarify" in BRIDGE


def test_bridge_server_side_stop():
    assert '"assistant", "stop"' in BRIDGE


def test_bridge_history_persists_and_caps():
    assert "chat-history.json" in BRIDGE
    assert "chatHistoryLimit" in STORE
    assert "clearHistory" in BRIDGE


def test_bridge_voice_and_attachments():
    assert "pw-record" in BRIDGE
    assert "startRecording" in BRIDGE and "stopRecording" in BRIDGE
    assert '"--attach"' in BRIDGE
    assert "addAttachment" in BRIDGE and "removeAttachment" in BRIDGE


def test_bridge_never_talks_to_gateway_directly():
    assert "8642" not in BRIDGE
    assert "assistant.key" not in BRIDGE
    assert '"horneroctl", "assistant"' in BRIDGE


def test_panel_is_javi_retrofuturist():
    assert "JAVI · EL HORNERO" in PANEL
    assert "199X" in PANEL
    assert "scanline" in PANEL.lower()
    assert 'Companion.frameSource(CompanionStore.skin, "idle")' in PANEL  # avatar follows skin
    assert "Appearance.font.family.mono" in PANEL  # mono micro-labels
    assert "reducedMotion" in PANEL  # scanline/pulse honors reduced motion


def test_panel_scrollable_markdown_bubbles():
    assert "ListView" in PANEL
    assert "Text.MarkdownText" in PANEL
    assert "positionViewAtEnd" in PANEL


def test_panel_input_voice_attach_clarify():
    assert '"mic"' in PANEL
    assert '"attach_file"' in PANEL
    assert "pendingClarify" in PANEL
    assert "pendingApproval" in PANEL
    assert "sugerencias" not in PANEL  # chips are translatable strings, not hardcoded ES
    assert "Retry last" in PANEL


def test_pane_assistant_section_and_javi_name():
    assert "Assistant (Hermes)" in PANE
    assert "Javi · el Hornero" in PANE
    assert "chatStreaming" in PANE and "chatHistoryLimit" in PANE
    assert '"Javi"' in REGISTRY


def test_bridge_sessions_and_panel_bar():
    bridge = (ROOT / "modules/companion/AssistantBridge.qml").read_text()
    assert '"sessions"' in bridge and '"model", "list"' in bridge
    assert '"--session", root.currentSession' in bridge
    assert "X-Hermes" not in bridge  # keys stay inside horneroctl
    panel = (ROOT / "modules/companion/ChatPanel.qml").read_text()
    assert "currentSessionTitle" in panel and "newChatSession" in panel


def test_chat_activity_trace_ui_and_bridge():
    bridge = (ROOT / "modules/companion/AssistantBridge.qml").read_text()
    assert "traceText" in bridge
    assert 'obj.type === "thinking"' in bridge
    assert 'obj.type === "tool"' in bridge
    assert "pushHistoryTraced" in bridge
    panel = (ROOT / "modules/companion/ChatPanel.qml").read_text()
    assert "ACTIVITY TRACE · LIVE" in panel
    assert "SHOW ACTIVITY TRACE" in panel
    assert "modelData.trace" in panel
    # The trace is the gateway's emitted activity, never raw CoT claims.
    assert "chain-of-thought" not in panel.lower().replace("never the model's raw chain-of-thought", "")


def test_pane_shows_isolation_and_workspace():
    assert 'assistantStatus.data.isolation' in PANE
    assert 'Sandboxed (bubblewrap)' in PANE
    assert 'not sandboxed' in PANE  # honest fallback label, never fake
    assert 'assistantStatus.data.workspace' in PANE


def test_pane_policy_controls_are_real_horneroctl_calls():
    for preset in ("read-only", "workspace-agent", "desktop-assistant"):
        assert f'"policy", "preset", "{preset}", "--yes"' in PANE
    assert '"policy", "revoke-all", "--yes"' in PANE
    assert '"profile", "fix", "--yes"' in PANE
    assert '"assistant", "policy", "--json"' in PANE
    assert '"assistant", "profile", "--json"' in PANE


def test_chat_modes_are_real_and_cannot_escalate():
    assert '"--mode", CompanionStore.chatMode' in BRIDGE
    assert 'property string chatMode: "agent"' in STORE
    assert "setChatMode" in STORE
    for mode in ('"ask"', '"agent"', '"chat"'):
        assert mode in PANEL
    assert "CompanionStore.chatMode ===" in PANEL


def test_pane_workspace_reveal_and_activity():
    assert '"xdg-open", assistantStatus.data.workspace' in PANE
    assert '"assistant", "log", "--json"' in PANE


def test_pane_prompt_editor_is_real():
    assert '"assistant", "prompt", "--json"' in PANE
    assert '"assistant", "prompt", "set-text"' in PANE
    assert '"assistant", "prompt", "history", "--json"' in PANE
    assert "promptEditor" in PANE


def test_pane_model_picker_is_real():
    assert '"assistant", "model", "show", "--json"' in PANE
    assert '"assistant", "model", "set", id, "--yes", "--json"' in PANE
    assert "modelInput" in PANE
    # Gateway-reported models render as chips that only fill the input;
    # applying still goes through the explicit Apply model action.
    assert "hermesModel.models" in PANE
    assert "onClicked: modelInput.text = modelData" in PANE


def test_pane_workspace_manager_is_real():
    assert '"assistant", "workspace", "list", "--json"' in PANE
    assert '"assistant", "workspace", "use", modelData, "--yes", "--json"' in PANE
    assert '"assistant", "workspace", "create", name, "--yes", "--json"' in PANE
    assert "assistantWorkspaces.active" in PANE
