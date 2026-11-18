"""Approval user presence (hornero#447, K4) and undescribed requests (K5).

Node runs the pure helpers in services/assistantrun.js; the real nonce
script is extracted from AssistantBridge.qml and run against the fake
horneroctl, which implements horneroctl's presence check (private dir and
file, fresh, constant nonce, single use).
"""
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "assistantrun.js"
BRIDGE_SRC = (ROOT / "modules" / "companion" / "AssistantBridge.qml").read_text()
CARD_SRC = (ROOT / "modules" / "companion" / "ApprovalCard.qml").read_text()
FAKE = ROOT / "tests" / "fixtures" / "fake-horneroctl.py"
NODE = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def js(body: str):
    src = JS.read_text().replace(".pragma library", "", 1)
    out = subprocess.run(["node", "-e", src + "\n" + body], capture_output=True, text=True, timeout=30)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout)


def presence_script() -> str:
    m = re.search(r'readonly property string presenceScript: (".*")\n', BRIDGE_SRC)
    assert m, "presenceScript literal not found"
    return json.loads(m.group(1))


# --- pure helpers -------------------------------------------------------------

@NODE
def test_presence_support_is_feature_detected_from_status():
    out = js("console.log(JSON.stringify([presenceSupport({requirePresence:'true'}), presenceSupport({requirePresence:'false'}), presenceSupport({}), gatewayView({ok:true,data:{enabled:'true',gateway:'reachable',protocol:'compatible',requirePresence:'true'}}).presence, gatewayView(null).presence]))")
    assert out == ["required", "off", "unknown", "required", "unknown"]


@NODE
def test_token_and_file_name_shapes():
    out = js("""console.log(JSON.stringify([
      isValidPresenceToken('a'.repeat(32)), isValidPresenceToken('a'.repeat(31)), isValidPresenceToken('a'.repeat(129)), isValidPresenceToken('a'.repeat(31)+'/'),
      presenceFileName('run_1','p1@2'), presenceFileName('run_1','p1'), presenceFileName('../x','p1@2'), presenceFileName('run_1','p/1@2')]))""")
    assert out == [True, False, False, False, "run_1.p1@2", "", "", ""]


@NODE
def test_approve_command_carries_presence_only_for_approve_when_required():
    tok = "A" * 32
    out = js(f"""console.log(JSON.stringify([
      approveCommand('r','approve','p1@2','required','{tok}'),
      approveCommand('r','approve','p1@2','required',''),
      approveCommand('r','approve','p1','required','{tok}'),
      approveCommand('r','deny','p1@2','required',''),
      approveCommand('r','approve','p1@2','unknown',''),
      approveCommand('r','approve','p1@2','off','')]))""")
    base = ["horneroctl", "assistant", "approve", "r"]
    assert out[0] == base + ["approve", "--json", "--request", "p1@2", "--presence", tok]
    assert out[1] is None and out[2] is None
    assert out[3] == base + ["deny", "--json", "--request", "p1@2"]
    # An older horneroctl never sees --presence (it would reject the flag).
    assert out[4] == out[5] == base + ["approve", "--json", "--request", "p1@2"]


@NODE
def test_presence_refusals_are_recognised():
    out = js("console.log(JSON.stringify([decisionRefusal({ok:false,data:{pending:'presence-required'}}), decisionRefusal({ok:false,data:{pending:'presence-invalid'}}), decisionRefusal({ok:false,data:{}}), decisionRefusal(null)]))")
    assert out == ["presence-required", "presence-invalid", "", ""]


@NODE
def test_k5_undescribed_requests_are_flagged_from_stream_and_payload():
    unbound = "an action the gateway did not describe (deny unless you expected it)"
    out = js(f"""
      var a = replay([JSON.stringify({{type:'run',text:'r'}}), JSON.stringify({{type:'approval.control',text:'p7@3'}}), JSON.stringify({{type:'approval',text:{json.dumps(unbound)}}})], {{exit:false}}).state.pending;
      var b = replay([JSON.stringify({{command:'assistant ask',ok:false,message:'w',data:{{runId:'r',pending:'approval',detail:'x',request:'p1@1',detailBound:'false',mode:'agent'}}}})]).state.pending;
      var c = replay([JSON.stringify({{type:'run',text:'r'}}), JSON.stringify({{type:'approval',text:'ls'}})], {{exit:false}}).state.pending;
      console.log(JSON.stringify([a.detailBound, b.detailBound, c.detailBound]));""")
    assert out == [False, False, True]


# --- shell contract -----------------------------------------------------------

def test_nonce_comes_from_the_kernel_csprng_and_never_from_argv():
    script = presence_script()
    assert "head -c 24 /dev/urandom" in script and "base64" in script and "tr '+/' '-_'" in script
    assert "umask 077" in script and "mkdir -p -m 700" in script and "set -C" in script
    approve = BRIDGE_SRC.split("function approve(")[1].split("function presenceDir")[0]
    assert "Math.random" not in approve and "Math.random" not in BRIDGE_SRC.split("id: presenceWriter")[1].split("function removePresenceFile")[0]
    # The writer only gets the directory and file name as arguments.
    assert 'presenceWriter.command = ["sh", "-c", root.presenceScript, "sh", dir, name];' in BRIDGE_SRC


def test_approve_is_gated_on_the_same_request_and_cleans_up():
    w = BRIDGE_SRC.split("id: presenceWriter")[1].split("function removePresenceFile")[0]
    assert "pend.runId === root.decisionRun && pend.requestId === root.decisionRequest" in w
    assert 'AssistantRun.approveCommand(root.decisionRun, "approve", root.decisionRequest, "required", token)' in w
    dec = BRIDGE_SRC.split("id: decisionProcess")[1]
    assert "root.removePresenceFile();" in dec and "AssistantRun.decisionRefusal(payload)" in dec
    assert 'AssistantCopy.t("presence." + refusal, root.lang)' in dec


def test_card_warns_on_undescribed_requests_and_needs_a_bindable_request():
    assert "readonly property bool unbound: root.pend !== null && root.pend.detailBound === false" in CARD_SRC
    assert 'AssistantCopy.t("approval.unbound", root.lang)' in CARD_SRC
    assert "&& root.presenceBindable" in CARD_SRC


# --- real nonce script against the fake horneroctl's presence check ------------

def _env(tmp_path, presence="true"):
    state = tmp_path / "fake"
    state.mkdir(exist_ok=True)
    (state / "presence").write_text(presence)
    run = tmp_path / "run"
    run.mkdir(exist_ok=True, mode=0o700)
    return {**os.environ, "FAKE_HORNEROCTL_DIR": str(state), "XDG_RUNTIME_DIR": str(run)}


def _nonce(env, run_id, ref):
    d = Path(env["XDG_RUNTIME_DIR"]) / "hornero" / "approval-presence"
    out = subprocess.run(["sh", "-c", presence_script(), "sh", str(d), f"{run_id}.{ref}"], capture_output=True, text=True, env=env, timeout=10)
    assert out.returncode == 0, out.stderr
    return out.stdout.strip(), d


def _approve(env, *extra):
    out = subprocess.run([sys.executable, str(FAKE), "assistant", "approve", "run_1", "approve", "--json", "--request", "p1@2", *extra], capture_output=True, text=True, env=env, timeout=10)
    return json.loads(out.stdout)


def test_script_writes_a_private_single_use_nonce_that_the_backend_accepts_once(tmp_path):
    env = _env(tmp_path)
    token, d = _nonce(env, "run_1", "p1@2")
    assert re.fullmatch(r"[A-Za-z0-9_-]{32}", token)
    f = d / "run_1.p1@2"
    assert oct(d.stat().st_mode & 0o777) == "0o700" and oct(f.stat().st_mode & 0o777) == "0o600"
    assert f.read_text() == token + "\n"
    assert _approve(env, "--presence", token)["ok"] is True
    assert not f.exists()
    again = _approve(env, "--presence", token)
    assert again["ok"] is False and again["data"]["pending"] == "presence-invalid"


def test_backend_refusals_without_or_with_a_wrong_nonce(tmp_path):
    env = _env(tmp_path)
    assert _approve(env)["data"]["pending"] == "presence-required"
    _nonce(env, "run_1", "p1@2")
    assert _approve(env, "--presence", "B" * 32)["data"]["pending"] == "presence-invalid"


def test_two_clicks_never_share_a_nonce(tmp_path):
    env = _env(tmp_path)
    a, _ = _nonce(env, "run_1", "p1@2")
    b, d = _nonce(env, "run_1", "p1@2")
    assert a != b and (d / "run_1.p1@2").read_text() == b + "\n"
    assert _approve(env, "--presence", a)["data"]["pending"] == "presence-invalid"


def test_older_horneroctl_rejects_the_flag_so_the_shell_never_sends_it(tmp_path):
    env = _env(tmp_path, presence="")
    out = subprocess.run([sys.executable, str(FAKE), "assistant", "approve", "run_1", "approve", "--json", "--request", "p1@2", "--presence", "A" * 32], capture_output=True, text=True, env=env, timeout=10)
    assert json.loads(out.stdout)["ok"] is False
