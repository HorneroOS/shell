"""Motion adoption (Signal visual language §11, Caelestia recovery item 3).

Settle curves on size and position, staggered reveals on the dashboard
home and launcher rows, the leading/trailing timing token, and the
optional Lively spring style capped at 6 % overshoot. Smooth stays the
factory style and reduced motion still wins. The offscreen checks open the
real dashboard and sample the staggered frames and the on-air tab bar;
they are skipped, never faked, without quickshell.
"""
import json
import re

import pytest

from chromatic_ui_harness import QS, ROOT
from test_rack_rhythm import render

APPEARANCE = (ROOT / "config" / "Appearance.qml").read_text()
CHOREO = (ROOT / "components" / "motion" / "Choreography.qml").read_text()


def curve(name: str) -> list[float]:
    m = re.search(rf"property list<real> {name}: \[([^\]]+)\]", APPEARANCE)
    return [float(v) for v in m.group(1).split(",")[:4]]


def overshoot(c: list[float]) -> float:
    """Peak of the cubic bezier's progress above 1, as a fraction."""
    _, y1, _, y2 = c
    peak = max(3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t * t * y2 + t ** 3
               for t in (i / 20000 for i in range(20001)))
    return peak - 1


def declared(name: str) -> dict[str, float]:
    m = re.search(rf'property real {name}: style === "snappy" \? 0 : style === "lively" \? ([\d.]+) : ([\d.]+)', APPEARANCE)
    return {"lively": float(m.group(1)), "smooth": float(m.group(2))}


def test_smooth_stays_within_four_percent_and_lively_within_six():
    assert overshoot(curve("settleSmooth")) <= 0.04
    assert overshoot(curve("settleFastSmooth")) <= 0.04
    assert 0.04 < overshoot(curve("settleLively")) <= 0.06
    assert 0.04 < overshoot(curve("settleFastLively")) <= 0.06


def test_declared_overshoot_matches_the_curves():
    for token, (smooth, lively) in {"settleOvershoot": ("settleSmooth", "settleLively"),
                                    "settleFastOvershoot": ("settleFastSmooth", "settleFastLively")}.items():
        d = declared(token)
        assert d["smooth"] == pytest.approx(overshoot(curve(smooth)), abs=0.002)
        assert d["lively"] == pytest.approx(overshoot(curve(lively)), abs=0.002)
    surf = (ROOT / "components" / "placement" / "AnchoredSurface.qml").read_text()
    assert "c.settleOvershoot > 8" in surf and "c.settleFastOvershoot > 8" in surf


def test_smooth_is_the_default_and_bouncy_reads_as_lively():
    cfg = json.loads((ROOT / "config" / "shell.default.json").read_text())["appearance"]["anim"]
    assert cfg["curveStyle"] == "smooth" and cfg["trailRatio"] == 1.6
    assert 'property string curveStyle: "smooth"' in (ROOT / "config" / "AppearanceConfig.qml").read_text()
    assert 's === "bouncy" ? "lively"' in APPEARANCE
    look = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "LookSection.qml").read_text()
    assert 'id: "lively"' in look and 'id: "bouncy"' not in look and 'curve: "bouncy"' not in look


def test_settle_never_on_opacity_or_colour():
    bad = []
    pat = re.compile(r"Behavior on (opacity|color|[a-z.]*[cC]olor)\s*\{[^{}]*\{[^{}]*(kind: \"settle|curves\.settle)", re.S)
    for p in [*(ROOT / "modules").rglob("*.qml"), *(ROOT / "components").rglob("*.qml")]:
        for m in pat.finditer(p.read_text()):
            bad.append(f"{p.relative_to(ROOT)}: {m.group(1)}")
    assert not bad, bad


def test_trail_token_is_morph_only_and_clamped():
    assert "return morph ? Math.round(ms * trailRatio) : ms;" in CHOREO
    assert "Math.max(1, Math.min(2.5, Appearance.anim.trailRatio))" in CHOREO
    anim = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "AnimationsSection.qml").read_text()
    assert 'qsTr("Trailing edge stretch")' in anim and "from: 1.0" in anim and "to: 2.5" in anim
    assert 'qsTr("Reset motion feel")' in anim and 'curveStyle = "smooth"' in anim and "trailRatio = 1.6" in anim
    tabs = (ROOT / "modules" / "dashboard" / "Tabs.qml").read_text()
    assert "Choreography.trail(Choreography.settleFast)" in tabs


def test_converted_behaviours_use_settle():
    content = (ROOT / "modules" / "dashboard" / "Content.qml").read_text()
    for prop in ("contentX", "implicitWidth", "implicitHeight"):
        assert re.search(rf"Behavior on {prop} \{{\s*MotionAnim \{{\s*kind: \"settle\"", content), prop
    launcher = (ROOT / "modules" / "launcher" / "ContentList.qml").read_text()
    for prop in ("implicitWidth", "implicitHeight"):
        assert re.search(rf"Behavior on {prop} \{{\s*enabled: root.visibilities.launcher\s*MotionAnim \{{\s*kind: \"settle\"", launcher), prop


def test_staggered_reveals_use_the_spec_steps():
    assert "readonly property int staggerStepFine: stagger ? _ms(16) : 0" in CHOREO
    assert "readonly property int staggerMaxFine: 6" in CHOREO
    assert "readonly property int staggerStep: stagger ? _ms(24) : 0" in CHOREO
    dash = (ROOT / "modules" / "dashboard" / "Dash.qml").read_text()
    # The frames of the loaded composition scan in (all three layouts).
    assert "stagger.play(layout.item)" in dash and "onLoaded: Qt.callLater(root.reveal)" in dash
    apps = (ROOT / "modules" / "launcher" / "AppList.qml").read_text()
    assert "step: Choreography.staggerStepFine" in apps and "maxRows: Choreography.staggerMaxFine" in apps
    assert "rowStagger.playRows(rows)" in apps


@pytest.mark.skipif(not QS, reason="NOT RUN: quickshell (qs) is not installed")
def test_dashboard_open_staggers_and_tab_bar_stretches(tmp_path):
    r = render(tmp_path, 1.0, 1920, 1080, mode="motion")
    assert r["level"] == "standard" and r["style"] == "smooth"
    samples = {s["t"]: s for s in r["samples"]}
    # Mid-reveal the first frame is ahead of the last (reading order) ...
    mid = next(s for s in r["samples"] if 0 < s["opacity"][0] < 1 or (s["opacity"][0] == 1 and s["opacity"][-1] < 1))
    assert mid["opacity"][0] > mid["opacity"][-1], r["samples"]
    # ... and every frame has landed, unshifted, by 600 ms.
    assert samples[600]["opacity"] == [1] * len(samples[600]["opacity"])
    assert samples[600]["shift"] == [0] * len(samples[600]["shift"])
    widths = [s["width"] for s in r["indicator"]]
    rest = r["indicator"][-1]["width"]
    assert max(widths[:-1]) > rest * 1.15, r["indicator"]  # stretched in flight
    assert r["indicator"][-1]["x"] > r["indicator"][0]["x"], r["indicator"]  # landed on tab 3


@pytest.mark.skipif(not QS, reason="NOT RUN: quickshell (qs) is not installed")
def test_reduced_motion_skips_stagger_and_stretch(tmp_path):
    r = render(tmp_path, 1.0, 1920, 1080, mode="motion", reduced=True)
    assert r["level"] == "off"
    assert all(o == 1 for s in r["samples"] for o in s["opacity"]), r["samples"]
    rest = r["indicator"][-1]["width"]
    assert all(abs(s["width"] - rest) <= 1 for s in r["indicator"]), r["indicator"]
