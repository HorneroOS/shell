"""Launcher inline AI ask (shell#250 slice 3, registry migration).

Executable tests: the streaming state machine is a pure JS module
(services/inlineask.js), so it runs under node against real NDJSON
lines (chunk append, trace exclusion, cap, cancel-by-busy-guard
inputs, error->fallback classification) instead of only being
pattern-matched. Static QML contracts cover registry routing,
cancel hooks, the Javi fallback and the no-logging guarantee.
"""
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INLINE_QML = (ROOT / "services/InlineAsk.qml").read_text()
INLINE_JS = ROOT / "services/inlineask.js"
AI_ITEM = (ROOT / "modules/launcher/items/AiItem.qml").read_text()
PROVIDERS = (ROOT / "modules/launcher/services/Providers.qml").read_text()
APPLIST = (ROOT / "modules/launcher/AppList.qml").read_text()
CONTENT = (ROOT / "modules/launcher/Content.qml").read_text()


def _run_js(driver: str):
    node = shutil.which("node")
    assert node, "node is required to execute the pure-JS inline-ask module"
    src = INLINE_JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run(
        [node, "-e", src + "\n" + driver],
        capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def _apply(lines, cap=None):
    driver = (
        "let s={text:'',finalPayload:null};"
        f"const lines={json.dumps(lines)};"
        f"for (const l of lines) s=applyLine(s,l,{cap if cap else 'undefined'});"
        "console.log(JSON.stringify(s));"
    )
    return _run_js(driver)


def _finish(text, payload):
    driver = (
        f"console.log(JSON.stringify(finishOutcome({json.dumps(text)},"
        f"{json.dumps(payload)}, undefined)));"
    )
    return _run_js(driver)


# --- Streaming state machine (executed) --------------------------------

def test_delta_chunks_append_in_order():
    out = _apply([
        '{"type":"delta","text":"Hello "}',
        '{"type":"delta","text":"world"}',
        '{"ok":true,"message":"done","data":{}}',
    ])
    assert out["text"] == "Hello world"
    assert out["finalPayload"]["ok"] is True


def test_trace_lines_never_become_answer_text():
    out = _apply([
        '{"type":"thinking","text":"secret reasoning"}',
        '{"type":"tool","text":"ran a command"}',
        '{"type":"commentary","text":"working"}',
        '{"type":"delta","text":"answer"}',
    ])
    assert out["text"] == "answer"


def test_malformed_and_empty_lines_ignored():
    out = _apply(["", "not json", '{"type":"delta"}', '{"type":"delta","text":"x"}'])
    assert out["text"] == "x"
    assert out["finalPayload"] is None


def test_text_cap_keeps_tail():
    out = _apply(['{"type":"delta","text":"abcdefghij"}'], cap=4)
    assert out["text"] == "ghij"


def test_finish_ok_false_is_failed_with_payload_message():
    out = _finish("", {"ok": False, "message": "Assistant is disabled."})
    assert out["failed"] is True
    assert out["errorText"] == "Assistant is disabled."
    assert out["text"] == ""


def test_finish_without_payload_is_failed_not_fake_answer():
    out = _finish("", None)
    assert out["failed"] is True
    assert out["text"] == ""


def test_finish_uses_final_payload_text_when_no_deltas():
    out = _finish("", {"ok": True, "data": {"text": "final answer"}})
    assert out == {"text": "final answer", "errorText": "", "failed": False}


def test_finish_keeps_streamed_text_on_success():
    out = _finish("streamed", {"ok": True, "data": {}})
    assert out["failed"] is False
    assert out["text"] == "streamed"


# --- InlineAsk.qml contract ---------------------------------------------

def test_inline_ask_uses_only_existing_horneroctl_stream_contract():
    assert '"horneroctl", "assistant", "ask"' in INLINE_QML
    assert '"--json", "--stream"' in INLINE_QML
    # No invented IPC, no direct gateway access, no approvals inline.
    assert "8642" not in INLINE_QML
    assert '"assistant", "approve"' not in INLINE_QML
    assert '"assistant", "clarify"' not in INLINE_QML
    assert '"--attach"' not in INLINE_QML
    # Read-only by contract: the quick ask always runs in Ask mode
    # (fails closed on a horneroctl too old to know the flag).
    assert '"--mode", "ask"' in INLINE_QML
    # Quick never escalates: a pending request ends the run and
    # hands off explicitly to the Workbench.
    assert "needsWorkbench" in INLINE_QML and "openInWorkbench" in INLINE_QML


def test_inline_ask_cancel_and_new_query_semantics():
    assert "function cancel(who: string)" in INLINE_QML
    assert "function stop()" in INLINE_QML
    # Cancel kills the process and the exit handler ignores stale runs.
    assert "proc.running = false" in INLINE_QML
    assert "if (!root.busy)" in INLINE_QML
    # A new ask supersedes an in-flight one instead of being dropped.
    ask_body = INLINE_QML.split("function ask(")[1].split("function stop()")[0]
    assert 'root.cancel("")' in ask_body  # cancel("") stops any owner's process and the gateway run
    assert "root.busy = true" in ask_body


def test_inline_ask_never_logs_question_or_answer():
    for src in (INLINE_QML, INLINE_JS.read_text(), AI_ITEM):
        assert "console.log" not in src
        assert "console.warn" not in src
        assert "console.info" not in src


def test_fallback_summons_javi_via_companion_ipc():
    assert "function openInJavi(list" in INLINE_QML
    assert '"quickshell", "ipc", "call", "companion", "ask", q' in INLINE_QML
    assert "list.visibilities.launcher = false" in INLINE_QML
    # The row activates the fallback instead of re-asking or dying.
    assert "InlineAsk.openInJavi(root.list)" in AI_ITEM
    assert "InlineAsk.failed" in AI_ITEM


# --- Registry routing ----------------------------------------------------

def test_ai_registered_as_builtin_provider():
    assert '"id": "ai"' in PROVIDERS
    assert '"prefix": "ai"' in PROVIDERS
    assert '"icon": "feather"' in PROVIDERS
    assert "InlineAsk.ask" in PROVIDERS
    # Stop only the launcher's own run (S9).
    assert 'InlineAsk.cancel("launcher")' in PROVIDERS and "InlineAsk.stop()" not in PROVIDERS
    # Built-ins register before builtinsRegistered flips (plugins after).
    ai_at = PROVIDERS.index('"id": "ai"')
    flip_at = PROVIDERS.index("root.builtinsRegistered = true")
    assert ai_at < flip_at


def test_applist_routes_ai_via_registry_and_cancels_on_exit():
    assert 'providerState === "ai"' in APPLIST
    assert 'name: "ai"' in APPLIST
    assert "aiItem" in APPLIST
    assert 'if (state !== "ai")' in APPLIST
    assert 'InlineAsk.cancel("launcher")' in APPLIST
    # Registry migration must not disturb the other routes.
    for pid in ("calc", "win", "file"):
        assert f'providerState === "{pid}"' in APPLIST


def test_launcher_close_cancels_inflight_ask():
    close_body = CONTENT.split("function onLauncherChanged()")[1].split("}")[0]
    assert 'InlineAsk.cancel("launcher")' in close_body


def test_ai_row_shows_thinking_and_streamed_text():
    assert "Javi is thinking" in AI_ITEM
    assert "InlineAsk.text" in AI_ITEM
    assert "InlineAsk.errorText" in AI_ITEM
    assert 'InlineAsk.ask(root.question, "launcher")' in AI_ITEM
    assert 'InlineAsk.cancel("launcher")' in AI_ITEM and "InlineAsk.stop()" not in AI_ITEM


# --- Quick surface never escalates (typed frames) ---------------------

def test_run_frame_is_tracked_and_never_mistaken_for_the_final_result():
    out = _apply(['{"type":"run","text":"run_q"}', '{"type":"delta","text":"x"}'])
    assert out["runId"] == "run_q" and out["finalPayload"] is None


def test_unknown_typed_frames_are_not_a_final_payload():
    out = _apply(['{"type":"future.thing","text":"x"}'])
    assert out["finalPayload"] is None


def test_pending_frames_mark_the_run_and_need_the_workbench():
    out = _apply(['{"type":"run","text":"r"}', '{"type":"approval","text":"rm x"}'])
    assert out["pending"] == "approval"
    assert _run_js("console.log(JSON.stringify([needsWorkbench('approval',null),needsWorkbench('clarify',null),needsWorkbench('',{data:{pending:'denied-by-mode'}}),needsWorkbench('',{ok:true,data:{}})]))") == [True, True, True, False]


# --- Hand-off to the Workbench (Radio and launcher) --------------------

def _handoff(question, pending, detail, run_id, payload, source):
    args = ",".join(json.dumps(v) for v in (question, pending, detail, run_id, payload, source))
    return _run_js(f"console.log(JSON.stringify(handoffInfo({args})))")


def test_pending_frame_keeps_the_exact_request_text_for_the_handoff():
    out = _apply(['{"type":"run","text":"r"}', '{"type":"clarify","text":"Which folder?"}', '{"type":"approval","text":"later"}'])
    assert out["pending"] == "clarify" and out["pendingDetail"] == "Which folder?"


def test_mode_denied_approval_hands_off_as_a_read_only_approval_record():
    # The exact payload preview46 returns for an Ask-mode approval.
    payload = {"ok": False, "message": "Approval denied by ask mode on run r1: rm -rf ~/x. Ask/Chat modes never escalate; switch to an Agent session to act.",
               "data": {"runId": "r1", "mode": "ask", "pending": "denied-by-mode", "detail": "rm -rf ~/x"}}
    rec = _handoff("borra x", "", "", "r1", payload, "radio")
    assert rec == {"source": "radio", "question": "borra x", "kind": "approval", "detail": "rm -rf ~/x",
                   "runId": "r1", "mode": "ask", "denied": True}


def test_mode_blocked_tool_is_not_called_an_approval():
    payload = {"ok": False, "message": "Tool execution denied by ask mode on run r2: terminal. ask mode never executes tools; switch to an Agent session to act.",
               "data": {"runId": "r2", "mode": "ask", "pending": "denied-by-mode", "detail": "terminal"}}
    rec = _handoff("q", "", "", "r2", payload, "launcher")
    assert rec["kind"] == "blocked" and rec["detail"] == "terminal" and rec["mode"] == "ask"


def test_handoff_mode_is_ask_whatever_the_payload_claims_and_ids_are_checked():
    payload = {"ok": False, "data": {"runId": "../etc", "mode": "agent", "pending": "approval", "detail": "x"}}
    rec = _handoff("q", "", "", "", payload, "radio")
    assert rec["mode"] == "ask" and rec["runId"] == ""


def test_deny_failed_is_a_failure_not_a_handoff():
    payload = {"ok": False, "message": "Could not deny", "data": {"runId": "r", "pending": "deny-failed"}}
    assert _run_js(f"console.log(JSON.stringify(needsWorkbench('', {json.dumps(payload)})))") is False
    out = _run_js(f"console.log(JSON.stringify(finishOutcome('', {json.dumps(payload)})))")
    assert out["failed"] is True


def test_handoff_is_emitted_only_by_the_user_and_only_for_the_launchers_own_run():
    assert "signal handoffRequested(var payload)" in INLINE_QML
    body = INLINE_QML.split("function openInWorkbench(")[1].split("function consume(")[0]
    assert 'root.owner === "launcher"' in body and "root.handoffRequested(info)" in body
    # No IPC round-trip any more: the record goes straight to the bridge.
    assert "workbenchDraft" not in INLINE_QML
    ai = (ROOT / "modules/launcher/items/AiItem.qml").read_text()
    assert 'readonly property bool mine: InlineAsk.owner === "launcher"' in ai
    assert "InlineAsk.needsWorkbench && root.mine" in ai
