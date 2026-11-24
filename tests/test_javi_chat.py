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
RUNJS = (ROOT / "services" / "assistantrun.js").read_text()
CARD = (COMPANION / "ApprovalCard.qml").read_text()
PANEL = (COMPANION / "ChatPanel.qml").read_text()
STORE = (COMPANION / "CompanionStore.qml").read_text()
PANE = (ROOT / "modules" / "controlcenter" / "companion" / "CompanionPane.qml").read_text()
REGISTRY = (ROOT / "modules" / "controlcenter" / "PaneRegistry.qml").read_text()


def test_bridge_streams_ndjson_deltas():
    assert '"--stream"' in BRIDGE
    assert 'type === "delta"' in RUNJS
    assert "streamText" in BRIDGE


def test_bridge_uses_structured_pending_not_prose():
    assert "d.pending" in RUNJS and "d.runId" in RUNJS
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
    assert "scanline" in PANEL.lower()  # header accent only
    assert "Repeater {\n                    model: 160" not in PANEL  # no constant full-card scanlines
    assert 'Companion.frameSource(CompanionStore.effectiveSkin, "idle")' in PANEL  # avatar follows skin
    assert "Appearance.font.family.mono" in PANEL  # mono micro-labels
    assert "reducedMotion" in PANEL  # scanline/pulse honors reduced motion


def test_panel_scrollable_markdown_bubbles():
    assert "ListView" in PANEL
    assert "Text.MarkdownText" in PANEL
    assert "positionViewAtEnd" in PANEL


def test_panel_input_voice_attach_clarify():
    assert '"microphone"' in PANEL
    assert '"paperclip"' in PANEL
    assert "ClarifyCard" in PANEL and "pendingClarify" in (COMPANION / "ClarifyCard.qml").read_text()
    assert "ApprovalCard" in PANEL
    assert "sugerencias" not in PANEL  # chips are translatable strings, not hardcoded ES
    assert "Retry last" in PANEL


def test_pane_assistant_section_and_javi_name():
    assert "Assistant (Hermes)" in PANE
    assert "Companions" in PANE  # platform collection pane (shell#713)
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
    assert 'type === "thinking"' in RUNJS
    assert 'type === "tool"' in RUNJS
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
    assert 'root.askWith(text, CompanionStore.chatMode, files)' in BRIDGE and '"--mode", runMode' in BRIDGE
    # Fail closed: Ask by default and for any unknown/corrupt value.
    assert 'property string chatMode: "ask"' in STORE and 'chatMode: "agent"' not in STORE
    assert ': "agent";' not in STORE
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
    # picking a chip applies it (no Apply button); the input commits on Enter.
    assert "hermesModel.models" in PANE
    assert "modelInput.text = modelData;" in PANE and "root.applyModel(modelData)" in PANE


def test_pane_workspace_manager_is_real():
    assert '"assistant", "workspace", "list", "--json"' in PANE
    assert '"assistant", "workspace", "use", modelData, "--yes", "--json"' in PANE
    assert '"assistant", "workspace", "create", name, "--yes", "--json"' in PANE
    assert "assistantWorkspaces.active" in PANE


def test_streaming_and_retention_settings_are_honoured_not_decorative():
    assert "CompanionStore.chatStreaming" in BRIDGE  # live text only when enabled
    assert "chatHistoryLimit === 0" in BRIDGE  # retention off: nothing persisted


def test_workbench_is_a_view_over_the_same_engine():
    wb = (COMPANION / "WorkbenchPane.qml").read_text()
    assert "AssistantRun" in wb and "ApprovalCard" in wb
    # No second state machine, no process of its own except explicit user actions.
    assert "Process {" not in wb
    assert "askProcess" not in wb


def test_approval_card_has_no_bulk_or_auto_consent():
    card = "\n".join(l for l in CARD.lower().splitlines() if not l.strip().startswith("//"))
    for banned in ("approve all", "always allow", "remember", "autoapprove", "auto-approve", "session\"", "always\""):
        assert banned not in card
    assert 'bridge.approve(root.pend.runId, "approve", root.armedRequest)' in CARD
    assert "forceActiveFocus" not in CARD and "focus: true" not in CARD


def test_mic_is_explicit_cancellable_and_capped():
    assert "readonly property int recordMaxSeconds: 120" in BRIDGE and "// fixed:" in BRIDGE
    assert "discardRecording" in BRIDGE and "stopRecording(false, false)" in PANEL


def test_every_scrollbar_in_companion_binds_its_flickable():
    # A StyledScrollBar without `flickable` fails to create the whole
    # companion window silently (found in the QA VM, not by qmllint).
    import re
    for qml in COMPANION.glob("*.qml"):
        text = qml.read_text()
        for m in re.finditer(r"StyledScrollBar\.vertical:\s*StyledScrollBar\s*\{([^}]*)\}", text):
            assert "flickable:" in m.group(1), f"{qml.name}: scrollbar without flickable"


def test_workbench_ipc_entry_points_are_argument_complete_and_documented():
    host = (COMPANION / "CompanionHost.qml").read_text()
    doc = (ROOT / "docs" / "IPC.md").read_text()
    for fn in ("workbench()", "workbenchDraft(text: string)"):
        assert f"function {fn}" in host
    for name in ("workbench()", "workbenchDraft(text)"):
        assert name in doc
    # Javi Radio (javiradio IPC) is the quick entry point; the old
    # launcher-prefill `companion quick` is gone, not duplicated.
    assert "function quick(" not in host and "function quickWith(" not in host
    assert "quickWith" not in doc
    # The shell writes no keybinding for them.
    assert "GlobalShortcut" not in host and "CustomShortcut" not in host


def test_companion_ipc_cannot_decide_anything():
    host = (COMPANION / "CompanionHost.qml").read_text()
    ipc = host.split('target: "companion"')[1]
    for fn in ("function approve(", "function clarify(", "function continueHandoff(", "function deny("):
        assert fn not in ipc
    doc = (ROOT / "docs" / "IPC.md").read_text()
    row = [l for l in doc.splitlines() if l.startswith("| `companion` |")][0]
    assert "approve(" not in row and "clarify(" not in row
    # External asks are always read-only.
    assert 'assistantBridge.askWith((text ?? "").toString(), "ask", [])' in ipc
    # No IPC can follow an arbitrary run either (S2).
    assert "function events(" not in ipc and "followEvents" not in ipc
    assert "events(runId)" not in row


def test_decision_follows_events_only_when_stream_is_gone_and_run_unsettled():
    assert "needFollow" in BRIDGE
    assert "!streamLive && AssistantRun.pendingDecision" in BRIDGE


def test_review_hardening_contracts():
    inline = (ROOT / "services" / "InlineAsk.qml").read_text()
    # M5: hand-off records and stages, never sends
    assert "handoffRequested(info)" in inline and "workbenchAsk" not in inline
    assert "assistantBridge.draft = text" in (COMPANION / "CompanionHost.qml").read_text()
    # M7: prompts/answers follow `--` (a leading dash is data)
    assert '"--", q]' in inline
    assert '"--", prompt' in BRIDGE and '"--", text]' in BRIDGE
    # H1: decisions carry the displayed request id
    assert 'approveCommand(id, choice, pend.requestId' in BRIDGE and '"--request", requestRef' in (ROOT / "services" / "assistantrun.js").read_text()
    assert 'pend.requestId === "" || pend.truncated' in BRIDGE
    # H3: every cancel path stops the gateway run
    assert "stopRun(" in inline and "Component.onDestruction" in inline and 'root.cancel("");' in inline
    assert "Component.onDestruction" in BRIDGE
    # M6/M8
    assert "umask 077" in BRIDGE and "mkdir -p -m 700" in BRIDGE
    assert "sweepVoiceFiles" in BRIDGE and "stopRecording(false, true)" in BRIDGE
    assert "isValidRunId" in BRIDGE
    # L6/L7
    assert "pendingLink" in PANEL and "armTimer" in CARD and "root.armed" in CARD
    # M3
    assert "wellFlick" in CARD and "truncated" in CARD


def test_history_is_written_via_stdin_and_marked_saved_only_on_success():
    assert "stdinEnabled: true" in BRIDGE and "historyWriter.write(" in BRIDGE
    assert "'${quoted}'" not in BRIDGE  # no shell-quoted payload
    assert "if (exitCode === 0)\n                root.lastSavedHistory" in BRIDGE
    assert 'id.replace(/[.*+?^${}()|[\\]\\\\]/g' in BRIDGE  # session id is regex-escaped


def test_cancel_before_the_run_id_is_known_waits_for_it_and_reports_failed_stops():
    inline = (ROOT / "services" / "InlineAsk.qml").read_text()
    assert "stopPending" in inline and "deferTimer" in inline
    assert 'stopProc.command = ["horneroctl", "assistant", "stop", id, "--json"]' in inline  # id captured at call time
    assert "root.runId" not in inline.split("id: stopProc")[1].split("Process {")[0]  # no binding to a cleared runId
    assert "onExited: (exitCode, exitStatus) =>" in inline.split("id: stopProc")[1]
    assert "stopWhenKnown" in BRIDGE and "stopDeadline" in BRIDGE and "onRunIdChanged" in BRIDGE
    assert 'stopProcess.command = ["horneroctl", "assistant", "stop", id, "--json"]' in BRIDGE
    assert "was not accepted" in BRIDGE


def test_private_dirs_are_chmodded_even_when_they_already_exist():
    assert BRIDGE.count("chmod 700") >= 3


def test_radio_handoff_lands_in_the_workbench_with_the_request_visible():
    host = (COMPANION / "CompanionHost.qml").read_text()
    radio = (COMPANION / "JaviRadio.qml").read_text()
    wb = (COMPANION / "WorkbenchPane.qml").read_text()
    card = (COMPANION / "HandoffCard.qml").read_text()
    # Radio classifies InlineAsk's stop-at-pending as a hand-off (before
    # the failure flag: a mode denial is ok:false too) and carries the
    # hand-off record, not a raw payload.
    finish = radio.split("function finish()")[1]
    assert finish.index("InlineAsk.needsWorkbench") < finish.index("InlineAsk.failed")
    assert "InlineAsk.handoffInfo()" in finish
    # Both quick surfaces' hand-offs reach the bridge and open the Workbench.
    assert host.count("assistantBridge.notePayload(payload);\n            root.openWorkbench(\"\");") == 2
    assert "target: JaviRadio" in host and "target: InlineAsk" in host
    # notePayload records for display only; never a pending decision and
    # never over a live run.
    note = BRIDGE.split("function notePayload(payload)")[1].split("function continueHandoff")[0]
    assert "AssistantRun.handoff(payload)" in note and "root.busy || AssistantRun.pendingDecision" in note
    assert "approve" not in note.split("{", 1)[1].split("}")[0]
    # The Workbench shows it on the Approvals tab.
    assert "HandoffCard {" in wb and "onHandoffRecordChanged" in wb and 'root.tab = "approvals"' in wb
    # The card has no Allow: only a NEW agent run, edit, or dismiss; the
    # request is plain text.
    assert "approve(" not in card and "approval.allow" not in card
    assert "continueHandoff()" in card and "textFormat: Text.PlainText" in card
    cont = BRIDGE.split("function continueHandoff()")[1].split("function editHandoff")[0]
    assert 'root.askWith(rec.question, "agent", [])' in cont


def test_allow_is_only_for_agent_runs_in_the_shell_too():
    assert 'choice === "approve" && pend.mode !== "agent"' in BRIDGE
    assert 'root.pend.mode === "agent"' in CARD


def test_nest_workbench_action_opens_the_workbench():
    host = (COMPANION / "CompanionHost.qml").read_text()
    assert 'if (action === "workbench") {\n                root.openWorkbench("");' in host
