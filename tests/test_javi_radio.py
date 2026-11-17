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
def test_extension_requests_never_open_radio_in_quiet_modes():
    def may(entry, mode):
        return run_js(M, f"console.log(JSON.stringify(mayOpen(defaults(), {json.dumps(entry)}, {{mode: {json.dumps(mode)}}})));")
    assert may("plugin", "everyday") is True and may("plugin", "signal") is True
    assert may("plugin", "focus") is False and may("plugin", "gaming") is False
    # the user's own gestures work in every mode
    for mode in ("focus", "gaming", "studio"):
        assert may("shortcut", mode) is True and may("javi", mode) is True


@NODE
def test_escalation_never_answers_for_the_user():
    def c(p, streamed="null"):
        return run_js(M, f"console.log(JSON.stringify(classify({json.dumps(p)}, {streamed})));")
    assert c({"ok": True, "data": {"text": "42"}})["kind"] == "answer"
    assert c({"ok": True, "data": {}}, '"streamed 42"') == {"kind": "answer", "text": "streamed 42"}
    for pending in ("approval", "clarify", "anything"):
        got = c({"ok": True, "data": {"pending": pending, "runId": "r1", "text": "hi"}}, '"partial"')
        assert got == {"kind": "handoff", "text": ""}, pending
    assert c({"status": "blocked", "data": {"text": "x"}})["kind"] == "handoff"
    assert c({"ok": False, "message": "x"})["kind"] == "failed"
    assert c({}) ["kind"] == "failed" and c(None)["kind"] == "failed"
    assert len(c({"data": {"text": "x" * 9000}})["text"]) == 4000


@NODE
def test_nothing_opens_under_a_fullscreen_window():
    for entry in ("shortcut", "javi", "bar", "launcher", "menu", "plugin"):
        r = run_js(M, f"console.log(JSON.stringify(mayOpen(defaults(), {json.dumps(entry)}, {{mode: 'everyday', fullscreen: true}})));")
        assert r is False, entry
