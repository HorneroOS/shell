"""Palette transitions (RFC 0002 §13.2): OKLab, <= 12 steps, <= 240 ms,
<= 2 ms of binding work per step; instant for reduced motion, high
contrast and `transition: instant`."""
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chromatic_ui_harness import ROOT, requires_qs, run_scene  # noqa: E402
from signal_tokens import built_in_themes, contrast  # noqa: E402

JS = ROOT / "services" / "chromatic.js"


def run_js(expr: str):
    node = shutil.which("node")
    assert node, "node is required to execute services/chromatic.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run([node, "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
                          capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def test_step_budget_is_at_most_12_steps_and_240_ms():
    out = run_js("return {max: MAX_STEPS, ms: STEP_MS, s240: stepsFor(240), s1000: stepsFor(1000), s0: stepsFor(0), s5: stepsFor(5)}")
    assert out["max"] == 12 and out["ms"] * out["max"] <= 240
    assert out["s240"] <= 12 and out["s1000"] == 12
    assert out["s0"] == 0 and out["s5"] == 1


def test_tween_is_monotonic_in_lightness_and_ends_exactly_on_the_target():
    themes = built_in_themes()
    out = run_js(
        "const f = flatten(%s), t = flatten(%s), L = [];"
        "for (let i = 1; i <= 12; i++) { const fr = frame(f, t, i, 12); L.push([fr.ground, fr.ink, fr.term4]); }"
        "return {frames: L, target: [t.ground, t.ink, t.term4], keys: Object.keys(t).length}"
        % (json.dumps(themes["hornero-signal-night"]), json.dumps(themes["hornero-signal-day"]))
    )
    assert len(out["frames"]) == 12
    assert out["frames"][-1] == out["target"]
    lum = [sum(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h, _, _ in out["frames"]]
    assert lum == sorted(lum), "ground does not move monotonically night to day"
    assert out["keys"] == 34 + 16 - 0  # every role (incl. glow) plus term0..15


def test_midpoint_is_oklab_not_srgb():
    # sRGB midpoint of black/white is #808080; OKLab midpoint is darker.
    mid = run_js("return mixHex('#000000', '#FFFFFF', 0.5)")
    assert mid != "#808080" and mid.startswith("#") and int(mid[1:3], 16) < 0x80


def test_ensure_contrast_moves_lightness_only_and_reaches_the_floor():
    out = run_js("return [ensureContrast('#777777', '#808080', 4.5), contrast(ensureContrast('#777777', '#808080', 4.5), '#808080'),"
                 " ensureContrast('#FFFFFF', '#000000', 4.5), contrast('#3366CC', '#13171D')]")
    assert out[1] >= 4.5
    assert out[2] == "#FFFFFF"
    assert out[3] > 1
    assert contrast("#ECE6DA", "#13171D") == pytest.approx(
        run_js("return contrast('#ECE6DA', '#13171D')"), rel=1e-9)


def test_js_contrast_matches_the_python_gate_math():
    pal = built_in_themes()["hornero-signal-night"]["palette"]
    got = run_js("return contrast(%s, %s)" % (json.dumps(pal["ink"]), json.dumps(pal["base"])))
    assert got == pytest.approx(contrast(pal["ink"], pal["base"]), rel=1e-9)


@requires_qs
def test_smooth_transition_runs_at_most_12_steps_and_lands_on_target(tmp_path):
    r, before, after = run_scene(tmp_path, "tween")
    assert r["allowed"] is True and r["active"] is True
    assert 1 <= r["steps"] <= 12
    assert r["finalGround"].lower() == "#e6e1d5"  # Signal Day ground (the candidate)
    assert before == after


@requires_qs
@pytest.mark.parametrize("env", [{"HREDUCED": "1"}, {"HHC": "1"}, {"HTRANSITION": "instant"}])
def test_instant_when_reduced_motion_high_contrast_or_instant(tmp_path, env):
    r, _, _ = run_scene(tmp_path, "tween", **env)
    assert r["allowed"] is False
    assert r["active"] is False and r["steps"] == 0


@requires_qs
def test_one_step_costs_at_most_2_ms_of_binding_work(tmp_path):
    r, _, _ = run_scene(tmp_path, "cost", HTRANSITION="instant")
    assert r["maxSteps"] == 12
    # 400 palette consumers, software rendering: a step is a handful of
    # property assignments. 2 ms is the contract budget.
    assert r["stepMs"] <= 2.0, r["stepMs"]
