"""Cockpit Clear stays at ZERO background under Chromatic: dynamic colour
changes the foreground ink only (RFC 0001 §5.1 + RFC 0002 §4.9)."""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chromatic_ui_harness import ROOT, requires_qs, run_scene  # noqa: E402

JS = ROOT / "services" / "clearink.js"
BAR = (ROOT / "modules" / "bar" / "Bar.qml").read_text()


def run_js(expr: str):
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run([shutil.which("node"), "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
                          capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


CLEAR_INK = {
    "light": {"ink": "#FAF5E6", "inkMuted": "#CFC7B4", "signal": "#FFAA33", "alert": "#FF7A66", "halo": "#0B0A08"},
    "dark": {"ink": "#14110C", "inkMuted": "#4A4338", "signal": "#8A4A00", "alert": "#A5301A", "halo": "#FFFDF7"},
}


def test_sets_come_from_the_scheme_when_present_and_fixed_otherwise():
    out = run_js("return [setsFrom(null).light.ink, setsFrom(%s).light.ink, setsFrom(%s).dark.halo]"
                 % (json.dumps(CLEAR_INK), json.dumps(CLEAR_INK)))
    assert out == ["#ECE6DA", "#FAF5E6", "#FFFDF7"]


def test_a_partial_clearink_block_falls_back_per_key():
    out = run_js("return setsFrom({light: {ink: '#FFFFFF'}, dark: {}}).light")
    assert out["ink"] == "#FFFFFF" and out["halo"] == "#0C0F13"


def test_tone_with_scheme_sets_is_foreground_only():
    tone = run_js("return toneFor({mean: 0.05, dev: 0.02}, 'auto', false, setsFrom(%s))" % json.dumps(CLEAR_INK))
    assert tone["ink"] == "#FAF5E6" and tone["polarity"] == "light"
    # Nothing in a tone can paint a bar: no fill/background/scrim/tint key.
    for key in tone:
        assert not re.search(r"fill|background|scrim|tint|slab|backdrop", key, re.I), key


def test_polarity_still_picks_the_larger_contrast_with_scheme_sets():
    bright = run_js("return toneFor({mean: 0.95, dev: 0.02}, 'auto', false, setsFrom(%s)).polarity" % json.dumps(CLEAR_INK))
    dark = run_js("return toneFor({mean: 0.01, dev: 0.02}, 'auto', false, setsFrom(%s)).polarity" % json.dumps(CLEAR_INK))
    assert (bright, dark) == ("dark", "light")


def test_clear_bar_still_draws_no_background():
    # The bar's only fill is gated on !clear; Chromatic adds none.
    assert "visible: !root.clear && (root.floating || !Config.border.frameEnabled)" in BAR
    tone_qml = (ROOT / "components" / "clearink" / "ClearInkTone.qml").read_text()
    assert "Rectangle" not in tone_qml and "StyledRect" not in tone_qml
    ink_qml = (ROOT / "services" / "ClearInk.qml").read_text()
    assert "Rectangle" not in ink_qml and "color:" not in ink_qml.replace("readonly property color", "")


@requires_qs
def test_runtime_clear_sets_follow_the_chromatic_scheme(tmp_path):
    r, before, after = run_scene(tmp_path, "clear", HTRANSITION="instant")
    assert r["sets"]["light"]["ink"].lower() == "#faf5e6"
    assert r["sets"]["dark"]["halo"].lower() == "#fffdf7"
    assert before == after
