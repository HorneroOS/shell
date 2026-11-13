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
    # Documented gap: horneroctl has no --mode flag to invent here.
    assert '"--mode"' not in INLINE_QML


def test_inline_ask_cancel_and_new_query_semantics():
    assert "function cancel()" in INLINE_QML
    assert "function stop()" in INLINE_QML
    # Cancel kills the process and the exit handler ignores stale runs.
    assert "proc.running = false" in INLINE_QML
    assert "if (!root.busy)" in INLINE_QML
    # A new ask supersedes an in-flight one instead of being dropped.
    ask_body = INLINE_QML.split("function ask(")[1].split("function stop()")[0]
    assert "proc.running = false" in ask_body
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
    assert '"icon": "raven"' in PROVIDERS
    assert "InlineAsk.ask" in PROVIDERS
    assert "InlineAsk.stop()" in PROVIDERS
    # Built-ins register before builtinsRegistered flips (plugins after).
    ai_at = PROVIDERS.index('"id": "ai"')
    flip_at = PROVIDERS.index("root.builtinsRegistered = true")
    assert ai_at < flip_at


def test_applist_routes_ai_via_registry_and_cancels_on_exit():
    assert 'providerState === "ai"' in APPLIST
    assert 'name: "ai"' in APPLIST
    assert "aiItem" in APPLIST
    assert 'if (state !== "ai")' in APPLIST
    assert "InlineAsk.cancel()" in APPLIST
    # Registry migration must not disturb the other routes.
    for pid in ("calc", "win", "file"):
        assert f'providerState === "{pid}"' in APPLIST


def test_launcher_close_cancels_inflight_ask():
    close_body = CONTENT.split("function onLauncherChanged()")[1].split("}")[0]
    assert "InlineAsk.cancel()" in close_body


def test_ai_row_shows_thinking_and_streamed_text():
    assert "Javi is thinking" in AI_ITEM
    assert "InlineAsk.text" in AI_ITEM
    assert "InlineAsk.errorText" in AI_ITEM
    assert "InlineAsk.ask(root.question)" in AI_ITEM
    assert "InlineAsk.stop()" in AI_ITEM
