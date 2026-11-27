"""Regression tests for the #685 security review (B1, default agency, S1-S10, nits).

Each test names the finding it pins. Pure-JS logic runs under node; the
QML contracts are checked on the source with comments stripped, so prose
cannot satisfy or trip them.
"""
import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
COMP = ROOT / "modules" / "companion"
SERVICES = ROOT / "services"
NODE = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def code(path: Path) -> str:
    return re.sub(r"//[^\n]*", "", path.read_text(encoding="utf-8"))


BRIDGE = code(SERVICES / "AssistantBridge.qml")
PANEL = code(COMP / "ChatPanel.qml")
CLARIFY = code(COMP / "ClarifyCard.qml")
CARD = code(COMP / "ApprovalCard.qml")
HOST = code(COMP / "CompanionHost.qml")
STORE = code(COMP / "CompanionStore.qml")
INPUT = code(ROOT / "components" / "controls" / "StyledInputField.qml")
AI_ITEM = code(ROOT / "modules" / "launcher" / "items" / "AiItem.qml")
PROVIDERS = code(ROOT / "modules" / "launcher" / "services" / "Providers.qml")


def fn_body(src: str, name: str) -> str:
    start = src.index(f"function {name}(")
    depth = 0
    i = src.index("{", start)
    for j in range(i, len(src)):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return src[i:j + 1]
    raise AssertionError(name)


def run_js(path: Path, body: str):
    src = path.read_text(encoding="utf-8").replace(".pragma library", "", 1)
    out = subprocess.run(["node", "-e", src + "\n" + body], capture_output=True, text=True, timeout=30)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout)


RUN_JS = ROOT / "services" / "assistantrun.js"


# --- B1: nothing sends on focus loss; IPC drafts never send or take focus ---

def test_b1_input_field_exposes_enter_only_accepted_signal():
    assert "signal accepted" in INPUT and "onAccepted: root.accepted()" in INPUT


def test_b1_panel_and_clarify_send_on_enter_never_on_blur():
    for src in (PANEL, CLARIFY):
        assert "onEditingFinished" not in src
    assert "onAccepted: root.acceptInput()" in PANEL
    assert "onAccepted: root.send()" in CLARIFY


def test_b1_draft_never_overwrites_typed_text_and_never_takes_focus():
    handler = PANEL.split("function onDraftChanged()")[1].split("function focusInput")[0]
    assert 'input.text.trim() !== ""' in handler and "return;" in handler
    assert "forceActiveFocus" not in handler
    assert "root.fromDraft = true" in handler
    # Opening the panel does not grab the keyboard for staged text.
    vis = PANEL.split("onVisibleChanged:")[1]
    assert "!root.fromDraft" in vis.split("forceActiveFocus")[0]


def test_b1_staged_text_needs_the_send_button_which_names_the_mode():
    accept = fn_body(PANEL, "acceptInput")
    assert "if (root.fromDraft)" in accept and "return;" in accept
    assert accept.index("return;") < accept.index("root.sendCurrent()")
    assert 'qsTr("Send") + " · " + root.t("mode." + CompanionStore.chatMode)' in PANEL


# --- Default agency fails closed -----------------------------------------

def test_default_mode_is_ask_and_unknown_values_fall_back_to_ask():
    assert 'property string chatMode: "ask"' in STORE
    assert '"agent";' not in STORE.replace('["ask", "agent", "chat"]', "")
    load = STORE.split('typeof o.chatMode === "string"')[1].split(";")[0]
    assert '? o.chatMode : "ask"' in load


def test_s7_voice_message_is_always_an_ask_run_with_only_its_clip():
    stop = fn_body(BRIDGE, "stopRecording")
    assert '"ask", [root.recordPath]' in stop
    assert "root.ask(" not in stop and "chatMode" not in stop


# --- S1: decisions only clear the request they were made on -------------

@NODE
def test_s1_decision_for_another_request_or_run_is_dropped():
    out = run_js(RUN_JS, """
      let s = initial(); let r = reduce(s,{type:'begin'}); s=r.state; const q=s.seq;
      const L = o => { r = reduce(s,{type:'line',seq:q,line:JSON.stringify(o)}); s=r.state; };
      L({type:'run',text:'r1'}); L({type:'mode',text:'agent'});
      L({type:'approval.control',text:'p2@1'}); L({type:'approval',text:'second'});
      const a = reduce(s,{type:'decision',ok:true,runId:'r1',requestId:'p1@1'}).state;
      const b = reduce(s,{type:'decision',ok:true,runId:'other',requestId:'p2@1'}).state;
      const c = reduce(s,{type:'decision',ok:true}).state;
      const d = reduce(s,{type:'decision',ok:true,runId:'r1',requestId:'p2@1'}).state;
      console.log(JSON.stringify([a.pending && a.pending.requestId, b.pending && b.pending.requestId, c.pending && c.pending.requestId, d.pending]));
    """)
    assert out == ["p2@1", "p2@1", "p2@1", None]


@NODE
def test_s1_clarify_decision_matches_the_question_text():
    out = run_js(RUN_JS, """
      let s = initial(); let r = reduce(s,{type:'begin'}); s=r.state; const q=s.seq;
      const L = o => { r = reduce(s,{type:'line',seq:q,line:JSON.stringify(o)}); s=r.state; };
      L({type:'run',text:'r1'}); L({type:'clarify',text:'Which theme?'});
      const wrong = reduce(s,{type:'decision',ok:true,runId:'r1',detail:'Which folder?'}).state;
      const right = reduce(s,{type:'decision',ok:true,runId:'r1',detail:'Which theme?'}).state;
      console.log(JSON.stringify([wrong.phase, right.pending]));
    """)
    assert out == ["awaiting-clarification", None]


def test_s1_bridge_passes_the_decided_request_to_the_reducer():
    assert BRIDGE.count("root.decisionRun, root.decisionRequest, root.decisionDetail") >= 2
    assert "const runId = root.decisionRun;" in BRIDGE


# --- S2: no IPC follows a run ---------------------------------------------

def test_s2_companion_ipc_cannot_follow_runs():
    ipc = HOST.split('target: "companion"')[1]
    assert "events(" not in ipc and "followEvents" not in ipc


# --- S3: stop vs decision race, approve bound to phase and shown id -------

def test_s3_stop_waits_for_an_in_flight_decision():
    stop = fn_body(BRIDGE, "askStop")
    assert "if (root.decisionBusy)" in stop
    assert stop.index("root.decisionBusy") < stop.index("AssistantRun.cancel()")
    assert "enabled: !root.bridge.decisionBusy" in PANEL


def test_s3_approve_requires_awaiting_phase_and_the_shown_request():
    body = fn_body(BRIDGE, "approve")
    assert 'AssistantRun.phase !== "awaiting-approval"' in body
    assert "pend.requestId !== shown" in body
    assert "function approve(runId: string, decision: string, shownRequest: string)" in BRIDGE
    assert "root.armedRequest = root.pend ? root.pend.requestId" in CARD
    assert CARD.count("root.armedRequest)") == 2


# --- S4: attachments only with the panel's own Send ------------------------

def test_s4_attachments_are_explicit_per_call():
    assert "function askWith(text: string, mode: string, files: var)" in BRIDGE
    ask_with = fn_body(BRIDGE, "askWith")
    assert "root.attachments" not in ask_with
    ask = fn_body(BRIDGE, "ask")
    assert "root.attachments = [];" in ask and "root.askWith(text, CompanionStore.chatMode, files)" in ask
    assert 'askWith((text ?? "").toString(), "ask", [])' in HOST
    assert "root.askWith(root.lastPrompt, CompanionStore.chatMode, [])" in fn_body(BRIDGE, "retryLast")
    assert 'root.askWith(rec.question, "agent", [])' in fn_body(BRIDGE, "continueHandoff")


def test_s4_auto_stopped_clip_waits_for_the_user():
    stop = fn_body(BRIDGE, "stopRecording")
    keep = stop.split("keep === true")[1].split("} else {")[0]
    assert "root.heldClip = root.recordPath" in keep and "addAttachment" not in keep
    assert "root.bridge.attachHeldClip()" in PANEL and "root.bridge.dropHeldClip()" in PANEL


# --- S5: hidden characters ------------------------------------------------

def test_s5_untrusted_text_is_made_visible_where_shown():
    assert "function visibleText(text: string)" in (ROOT / "services" / "AssistantRun.qml").read_text()
    assert "input.replaceText(AssistantRun.visibleText(staged))" in PANEL
    assert "AssistantRun.visibleText(root.pendingLink)" in PANEL
    assert "AssistantRun.visibleText(root.lastTool())" in CARD


@NODE
def test_s5_handoff_question_hidden_characters_are_visible():
    out = run_js(RUN_JS, "console.log(JSON.stringify(handoffRecord({question:'borra\\u200b x\\u202e'})))")
    assert "U+200B" in out["question"] and "U+202E" in out["question"] and out["flagged"] is True


@NODE
def test_s5_radio_question_drops_invisible_format_characters():
    out = run_js(COMP / "radio.js", r"""console.log(JSON.stringify(cleanQuestion(
        "a​b‏c⁠d⁤e﻿f️g\u{E0041}\u{E007F}h\u{E0100}i \u{1F600}")))""")
    assert out == "abcdefghi \U0001F600"


# --- S6: snapshot writer ---------------------------------------------------

def test_s6_snapshot_goes_through_stdin_with_one_writer_at_a_time():
    flush = fn_body(BRIDGE, "flushSnapshot")
    assert "printf" not in flush and '"$2"' not in flush and "cat >" in flush
    assert "pendingWriter.running)" in flush and "pendingWriter.running = false" not in flush
    writer = BRIDGE.split("id: pendingWriter")[1].split("Process {")[0]
    assert "pendingWriter.write(root.writingSnapshot)" in writer
    assert "onExited: (exitCode, exitStatus) => root.flushSnapshot()" in writer


# --- S8: honest Ask-mode wording -------------------------------------------

def test_s8_docs_do_not_call_ask_mode_a_sandbox():
    wb = (ROOT / "docs" / "ASSISTANT_WORKBENCH.md").read_text()
    launcher = (ROOT / "docs" / "LAUNCHER.md").read_text()
    assert "It is not a sandbox" in wb and "not a sandbox" in launcher
    assert "needs no approval before horneroctl" in wb


# --- S9: the launcher only shows and stops its own run ----------------------

def test_s9_launcher_row_is_owner_scoped():
    assert 'InlineAsk.cancel("launcher")' in AI_ITEM and "InlineAsk.stop()" not in AI_ITEM
    assert "visible: root.mine && InlineAsk.text" in AI_ITEM
    assert 'InlineAsk.cancel("launcher")' in PROVIDERS and "InlineAsk.stop()" not in PROVIDERS


# --- S10: clarify answers the question it was typed for ---------------------

def test_s10_clarify_binds_the_answer_to_the_question_shown():
    body = fn_body(BRIDGE, "clarify")
    assert 'pend.detail !== (shownDetail ?? "").toString()' in body
    assert 'AssistantRun.phase !== "awaiting-clarification"' in body
    assert "root.answeringDetail = root.shownDetail" in CLARIFY
    assert "onShownDetailChanged" in CLARIFY


# --- Nits --------------------------------------------------------------------

def test_nit_copy_goes_through_stdin():
    assert '["wl-copy"]' in BRIDGE and "copyProcess.write(root.copyText)" in BRIDGE
    assert '"wl-copy", root.history' not in BRIDGE


@NODE
def test_nit_progress_tool_lines_keep_the_first_letter():
    out = run_js(RUN_JS, "console.log(JSON.stringify([classifyTool('terminal: 50%').name, classifyTool('\\u25b8 terminal: ls').name, classifyTool('\\u2713 terminal').status]))")
    assert out == ["terminal", "terminal", "ok"]


def test_nit_positional_arguments_follow_double_dash():
    for cmd in ('"sessions", "new", "--json", "--", title]', '"sessions", "use", "--json", "--", id]', '"model", "set", "--yes", "--json", "--", m]'):
        assert cmd in BRIDGE


# --- Re-review follow-ups (R1, R2, N1-N6) ------------------------------------

def test_r1_run_cleanup_keeps_the_held_clip_and_removal_clears_it():
    sweep = fn_body(BRIDGE, "removeAllVoiceFiles")
    assert "if (p !== root.heldClip)" in sweep
    remove = fn_body(BRIDGE, "removeVoiceFile")
    assert 'if (root.heldClip === path)\n            root.heldClip = "";' in remove


def test_r2_staged_text_is_written_into_the_focused_field_and_send_is_armed():
    assert "function replaceText(value: string)" in INPUT and "inputField.text = value;" in fn_body(INPUT, "replaceText")
    handler = PANEL.split("function onDraftChanged()")[1].split("function focusInput")[0]
    assert "input.replaceText(AssistantRun.visibleText(staged))" in handler
    assert "input.text =" not in PANEL
    assert "root.sendArmed = false;" in handler and "sendArmTimer.restart()" in handler
    assert re.search(r"id: sendArmTimer\s+interval: 700", PANEL)
    assert "if (!root.sendArmed)" in fn_body(PANEL, "sendCurrent")
    assert "enabled: root.sendArmed && (" in PANEL
    # A cleared field is cleared on screen too.
    assert 'input.replaceText("")' in fn_body(PANEL, "sendCurrent")


def test_n6_truncated_staged_text_is_flagged():
    handler = PANEL.split("function onDraftChanged()")[1].split("function focusInput")[0]
    assert "staged.length > AssistantRun.detailCap" in handler


def test_n1_inline_ask_does_not_claim_read_only_by_construction():
    src = (ROOT / "services" / "InlineAsk.qml").read_text()
    assert "read-only by construction" not in src and "not a sandbox" in src


def test_n3_old_default_agent_is_migrated_once_with_a_notice():
    assert "readonly property int chatModeVersion: 2" in STORE
    assert "chatModeVersion: root.chatModeVersion," in STORE  # persisted, so it runs once
    restore = fn_body(STORE, "restore")
    mig = restore.split("o.chatModeVersion !== root.chatModeVersion")[1].split("}")[0]
    assert 'persist.chatMode === "agent"' in mig and 'persist.chatMode = "ask";' in mig
    assert "root.agentOptInNotice = true;" in mig and "migrated = true;" in mig
    assert "if (migrated)\n            root.markDirty();" in restore
    assert "CompanionStore.agentOptInNotice" in PANEL and "dismissAgentOptInNotice()" in PANEL


def test_n5_clipboard_uses_one_queued_writer():
    copy = fn_body(BRIDGE, "copyLastAnswer")
    assert "copyProcess.running" not in copy and "root.flushCopy()" in copy
    flush = fn_body(BRIDGE, "flushCopy")
    assert "copyProcess.running)" in flush and "copyProcess.running = false" not in flush
    proc = BRIDGE.split("id: copyProcess")[1].split("Process {")[0]
    assert "copyProcess.write(root.copyText)" in proc and "root.flushCopy();" in proc


@NODE
def test_n2_joiners_survive_inside_words_and_emoji_only():
    out = run_js(COMP / "radio.js", r"""console.log(JSON.stringify([
        cleanQuestion("\u{1F468}‍\u{1F469}"), cleanQuestion("م‌م"),
        cleanQuestion("x ‍y"), cleanQuestion("z‌ "), cleanQuestion("‍lead")]))""")
    assert out == ["\U0001F468‍\U0001F469", "م‌م", "x y", "z", "lead"]
