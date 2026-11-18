"""Nest habitat: pure policy (node) plus the QML wiring contract."""
from _jsrun import NODE, run_js

M = "habitat.js"


def lights(extra: str, **kw):
    base = dict(mode="everyday", level="normal", connected=False, running=False,
                awaitingApproval=False, failed=False, radioBusy=False,
                reducedMotion=False, sleeping=False)
    base.update(kw)
    import json
    return run_js(M, f"const S = defaults(); {extra}; console.log(JSON.stringify(lights(Object.assign({{settings: S}}, {json.dumps(base)}))));")


@NODE
def test_defaults_validate_and_are_stable():
    r = run_js(M, "console.log(JSON.stringify([defaults(), sanitize(defaults()), sanitize(null), sanitize('x'), sanitize([1])]));")
    assert all(x == r[0] for x in r[1:])
    d = r[0]
    # no click target on placeholder art until the user asks for one
    assert d["placement"] == "anchored" and d["clickAction"] == "none"
    assert d["modeLevel"] == {"focus": "dim", "everyday": "normal", "signal": "rich", "gaming": "hidden", "studio": "dim"}


@NODE
def test_sanitize_rejects_bad_values_per_key():
    r = run_js(M, """
console.log(JSON.stringify(sanitize({placement: 'floating', anchor: 'middle', marginX: -5, marginY: 9999,
  scale: 7, monitor: '../etc', lighting: 'rainbow', intensity: 'max', phosphor: 'yes', clickAction: 'rm -rf',
  modeLevel: {focus: 'rich', gaming: 'loud', bogus: 'hidden'}})));""")
    assert r["placement"] == "anchored" and r["anchor"] == "bottom-right"
    assert r["marginX"] == 0 and r["marginY"] == 400
    assert r["scale"] == 2.0 and r["monitor"] == ""
    assert r["lighting"] == "auto" and r["intensity"] == 0.8
    assert r["phosphor"] is True and r["clickAction"] == "none"
    assert r["modeLevel"]["focus"] == "rich" and r["modeLevel"]["gaming"] == "hidden"
    assert "bogus" not in r["modeLevel"]


@NODE
def test_quiet_hours_only_lower_the_level_and_never_hide():
    r = run_js(M, """
const S = defaults(); S.modeLevel.everyday = 'rich';
console.log(JSON.stringify([effectiveLevel(S,'everyday',false), effectiveLevel(S,'everyday',true),
  effectiveLevel(S,'focus',true), effectiveLevel(S,'gaming',true), effectiveLevel(S,'signal',true)]));""")
    assert r == ["rich", "normal", "dim", "hidden", "normal"]
    off = run_js(M, "const S = defaults(); S.dimInQuietHours = false; console.log(JSON.stringify(effectiveLevel(S,'signal',true)));")
    assert off == "rich"


@NODE
def test_mode_changes_never_rewrite_user_choices():
    r = run_js(M, """
const S = sanitize({modeLevel: {gaming: 'dim'}}); const before = JSON.stringify(S);
effectiveLevel(S,'gaming',true); effectiveLevel(S,'focus',false);
console.log(JSON.stringify([JSON.stringify(S) === before, effectiveLevel(S,'gaming',false)]));""")
    assert r == [True, "dim"]


@NODE
def test_state_is_derived_from_observed_state_only():
    def st(**kw):
        import json
        return run_js(M, f"console.log(JSON.stringify(stateFor({json.dumps(kw)})));")
    assert st(visible=False, storeState="idle") == "hidden"
    assert st(visible=True, storeState="hidden") == "hidden"
    assert st(visible=True, storeState="sleeping", running=True) == "sleeping"
    assert st(visible=True, storeState="peeking") == "summoned"
    assert st(visible=True, storeState="idle", running=True) == "working"
    assert st(visible=True, storeState="idle", awaitingApproval=True) == "working"
    assert st(visible=True, storeState="thinking") == "working"
    assert st(visible=True, storeState="idle", overrideAnim="work") == "building"
    assert st(visible=True, storeState="idle", overrideAnim="blink") == "resting"
    assert st(visible=True, storeState="idle") == "resting"


@NODE
def test_lights_mean_something():
    off = lights("")
    assert [off[k]["on"] for k in ("link", "run", "approval", "radio")] == [False] * 4
    assert off["mode"]["on"] is True
    on = lights("", connected=True)
    assert on["link"]["on"] and on["link"]["role"] == "phosphor" and not on["run"]["on"]
    run = lights("", connected=True, running=True)
    assert run["run"]["on"] and run["run"]["role"] == "signal" and not run["run"]["blink"]
    appr = lights("", connected=True, running=True, awaitingApproval=True)
    assert appr["approval"]["on"] and appr["approval"]["blink"] and appr["approval"]["role"] == "cue"
    fail = lights("", failed=True)
    assert fail["link"]["on"] and fail["link"]["role"] == "alert"
    radio = lights("", radioBusy=True)
    assert radio["radio"]["on"]


@NODE
def test_blink_only_with_motion_and_awake_and_level():
    assert lights("", awaitingApproval=True, reducedMotion=True)["approval"]["blink"] is False
    assert lights("", awaitingApproval=True, sleeping=True)["approval"]["blink"] is False
    assert lights("", awaitingApproval=True, level="dim")["approval"]["blink"] is False
    assert lights("", awaitingApproval=True, level="rich")["approval"]["blink"] is True


@NODE
def test_lighting_switches_and_levels():
    assert lights("S.lighting='off'", connected=True, running=True)["run"]["on"] is False
    assert lights("S.indicators=false", connected=True)["link"]["on"] is False
    assert lights("", connected=True, level="hidden")["link"]["on"] is False
    warm = lights("S.lighting='warm'", connected=True, running=True)
    assert warm["link"]["role"] == "cue" and warm["run"]["role"] == "cue"
    cool = lights("S.lighting='cool'", connected=True, running=True)
    assert cool["link"]["role"] == "phosphor" and cool["run"]["role"] == "signal"
    # alerts keep their own role under any lighting choice
    assert lights("S.lighting='warm'", failed=True)["link"]["role"] == "alert"
    dim = lights("", connected=True, level="dim")["link"]["alpha"]
    rich = lights("", connected=True, level="rich")["link"]["alpha"]
    assert 0 < dim < rich <= 1
    sleeping = lights("", connected=True, sleeping=True)["link"]["alpha"]
    assert sleeping < lights("", connected=True)["link"]["alpha"]


@NODE
def test_layout_stays_on_screen_for_every_anchor_and_scale():
    r = run_js(M, """
const out = [];
for (const a of ANCHORS) for (const sc of [0.5, 1, 2]) for (const [w,h] of [[1920,1080],[800,600],[200,150]]) {
  const S = sanitize({anchor: a, scale: sc, marginX: 400, marginY: 400});
  const l = layout(S, w, h); out.push([a, w, h, l]);
}
console.log(JSON.stringify(out));""")
    for a, w, h, l in r:
        assert 0 <= l["x"] and l["x"] + l["size"] <= max(w, l["size"]), (a, w, h, l)
        assert 0 <= l["y"] and l["y"] + l["size"] <= max(h, l["size"]), (a, w, h, l)
    br = run_js(M, "console.log(JSON.stringify(layout(defaults(), 1920, 1080)));")
    assert (br["x"], br["y"], br["size"]) == (1920 - 160 - 24, 1080 - 160 - 48, 160)
    tl = run_js(M, "console.log(JSON.stringify(layout(sanitize({anchor:'top-left'}), 1920, 1080)));")
    assert (tl["x"], tl["y"]) == (24, 48)


@NODE
def test_home_fraction_points_into_the_nest():
    r = run_js(M, "console.log(JSON.stringify(homeFraction(defaults(), 1920, 1080)));")
    l = {"x": 1736, "y": 872, "size": 160}
    assert abs(r["fx"] - (l["x"] + 80) / 1920) < 1e-9
    assert abs(r["fy"] - (l["y"] + 160 * 472 / 512) / 1080) < 1e-9


@NODE
def test_surface_wanted_gates():
    ok = "{enabled:true, nestEnabled:true, placement:'anchored', level:'normal', visible:true, stage:2}"
    def w(patch):
        return run_js(M, f"const i = {ok}; Object.assign(i, {patch}); console.log(JSON.stringify(surfaceWanted(i)));")
    assert w("{}") is True
    assert w("{enabled:false}") is False and w("{nestEnabled:false}") is False
    assert w("{placement:'withJavi'}") is False and w("{level:'hidden'}") is False
    assert w("{visible:false}") is False and w("{stage:0}") is False


@NODE
def test_art_is_marked_placeholder():
    assert run_js(M, "console.log(JSON.stringify(ART));")["status"] == "placeholder"


@NODE
def test_layout_respects_bar_insets_on_every_edge():
    # a 40 px bar on the right and a 32 px bar at the bottom push the
    # bottom-right nest inward instead of covering it
    ins = "{left: 0, right: 40, top: 0, bottom: 32}"
    br = run_js(M, f"console.log(JSON.stringify(layout(defaults(), 1920, 1080, {ins})));")
    assert (br["x"], br["y"]) == (1920 - 40 - 160 - 24, 1080 - 32 - 160 - 48)
    assert (br["marginX"], br["marginY"], br["left"], br["top"]) == (24, 48, False, False)
    tl = run_js(M, "console.log(JSON.stringify(layout(sanitize({anchor:'top-left'}), 1920, 1080, {left: 56, top: 30})));")
    assert (tl["x"], tl["y"]) == (56 + 24, 30 + 48) and tl["left"] and tl["top"]
    # margins shrink so the nest stays inside the usable area
    tight = run_js(M, "console.log(JSON.stringify(layout(sanitize({marginX: 400}), 600, 600, {right: 300})));")
    assert tight["marginX"] == 600 - 300 - 160 and tight["x"] == 0
    # junk insets count as zero
    junk = run_js(M, "console.log(JSON.stringify(layout(defaults(), 1920, 1080, {right: 'x', bottom: -9})));")
    assert (junk["x"], junk["y"]) == (1736, 872)


@NODE
def test_home_fraction_includes_the_insets():
    r = run_js(M, "console.log(JSON.stringify(homeFraction(defaults(), 1920, 1080, {right: 40, bottom: 32})));")
    x, y = 1920 - 40 - 160 - 24, 1080 - 32 - 160 - 48
    assert abs(r["fx"] - (x + 80) / 1920) < 1e-9
    assert abs(r["fy"] - (y + 160 * 472 / 512) / 1080) < 1e-9


@NODE
def test_nest_screen_never_follows_focus():
    def rs(monitor, javi, names):
        import json
        return run_js(M, f"console.log(JSON.stringify(resolveScreen({json.dumps(monitor)}, {json.dumps(javi)}, {json.dumps(names)})));")
    assert rs("HDMI-A-1", "DP-1", ["DP-1", "HDMI-A-1"]) == "HDMI-A-1"
    assert rs("gone", "DP-1", ["eDP-1", "DP-1"]) == "DP-1"
    # nothing chosen and Javi unplaced: the primary output, not the focused one
    assert rs("", "", ["eDP-1", "DP-1"]) == "eDP-1"
    assert rs("", "", []) == ""


@NODE
def test_link_light_is_off_until_probed_and_while_disabled():
    def ls(ok, message):
        import json
        return run_js(M, f"console.log(JSON.stringify(linkState({{ok: {json.dumps(ok)}, message: {json.dumps(message)}}})));")
    # never probed yet
    assert ls(False, "") == "unknown"
    # horneroctl's real messages (hornero cli assistant_status_report)
    assert ls(True, "Assistant is disabled (default). Enable it explicitly: horneroctl assistant enable --yes") == "off"
    assert ls(True, "Assistant enabled; Hermes gateway reachable and protocol-compatible (v1).") == "ok"
    assert ls(False, "Assistant is enabled but the Hermes gateway is not answering at http://127.0.0.1:8642 (x).") == "failed"
    assert ls(False, "Assistant is enabled but Hermes Agent is not installed.") == "failed"
    # horneroctl itself missing is not a failure the user set up
    assert ls(False, "horneroctl assistant unavailable") == "off"
    # off and unknown never light the link LED
    assert lights("", connected=False, failed=False)["link"]["on"] is False


@NODE
def test_leds_shown_gates_blink_and_status_probe():
    def shown(extra, level, stage):
        import json
        return run_js(M, f"const S = defaults(); {extra}; console.log(JSON.stringify(ledsShown(S, {json.dumps(level)}, {stage})));")
    assert shown("", "normal", 4) is True
    assert shown("", "normal", 3) is False
    assert shown("S.indicators=false", "rich", 4) is False
    assert shown("S.lighting='off'", "rich", 4) is False
    assert shown("", "hidden", 4) is False
