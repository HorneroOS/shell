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
    assert "frames/default-idle.png" in PANEL  # Javi avatar
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
