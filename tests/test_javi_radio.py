"""Javi Radio policy (node): settings, entry points, escalation rule."""
import json

from _jsrun import NODE, run_js

M = "radio.js"


@NODE
def test_defaults_roundtrip_and_validation():
    r = run_js(M, "console.log(JSON.stringify([defaults(), sanitize(defaults()), sanitize(null), sanitize(7)]));")
    assert all(x == r[0] for x in r[1:])
    assert r[0]["shortcut"] == "Super+Shift+J" and r[0]["clickOnJavi"] == "radio"
    bad = run_js(M, "console.log(JSON.stringify(sanitize({shortcut:'rm -rf', clickOnJavi:'agent', enabled:'no', entryPoints:{bar:false, evil:true}})));")
    assert bad["shortcut"] == "Super+Shift+J" and bad["clickOnJavi"] == "radio" and bad["enabled"] is True
    assert bad["entryPoints"]["bar"] is False and "evil" not in bad["entryPoints"]


@NODE
def test_shortcut_grammar():
    r = run_js(M, "console.log(JSON.stringify(['Super+Shift+J','Ctrl+Alt+F5','Super+Space','J','Super+','Super+Shift+Alt+Ctrl+J','Super+<script>'].map(validShortcut)));")
    assert r == [True, True, True, False, False, False, False]


@NODE
def test_entry_points_follow_master_and_per_entry_switches():
    def may(patch, entry):
        return run_js(M, f"const S = defaults(); Object.assign(S, {patch}); console.log(JSON.stringify(mayOpen(S, {json.dumps(entry)})));")
    for e in ("shortcut", "launcher", "javi", "bar", "plugin", "menu"):
        assert may("{}", e) is True
    assert may("{enabled:false}", "shortcut") is False
    assert may("{entryPoints:{shortcut:false}}", "shortcut") is False
    assert may("{}", "agent") is False and may("{}", "") is False


@NODE
def test_question_is_one_bounded_line():
    r = run_js(M, "console.log(JSON.stringify([cleanQuestion('a\\n\\tb\\u0000c  '), cleanQuestion('x'.repeat(5000)).length, cleanQuestion(null)]));")
    assert r == ["a b c", 600, ""]


@NODE
def test_escalation_never_answers_for_the_user():
    def c(p):
        return run_js(M, f"console.log(JSON.stringify(classify({json.dumps(p)})));")["kind"]
    assert c({"text": "42"}) == "answer"
    assert c({"answer": "42"}) == "answer"
    assert c({"pendingApproval": {"id": "r1"}, "text": "hi"}) == "handoff"
    assert c({"status": "awaiting_approval"}) == "handoff"
    assert c({"pendingClarify": {}}) == "handoff"
    assert c({"status": "blocked", "text": "x"}) == "handoff"
    assert c({"ok": False}) == "failed" and c({}) == "failed" and c(None) == "failed"
