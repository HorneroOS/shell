"""Thin bars: shipped thicknesses, 3 px radii and the density factor."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PRESETS = sorted((ROOT / "presets").glob("*.json"))
# Per-layout calibration (docs/LAYOUTS.md "Proportions"): edge -> (style,
# thickness, margin). Bars are refined, not infinitesimal: horizontal strips
# sit between 26 and 36 px, Hornero Left/Right are chunky 60 px
# Caelestia-inspired rails (cell 44, content scale 1.25), and floating
# surfaces carry a deliberate margin.
CALIBRATION = {
    "classic-top": {"top": ("attached", 36, 6)},
    "classic-bottom": {"bottom": ("attached", 36, 6)},
    "cockpit": {"top": ("inset", 42, 18), "bottom": ("attached", 34, 0)},
    "cockpit-clear": {"top": ("attached", 46, 0), "bottom": ("attached", 30, 0)},
    "horizon": {"top": ("inset", 34, 6), "bottom": ("inset", 26, 6)},
    "islands": {"top": ("islands", 36, 8)},
    "floating-island": {"top": ("floating", 34, 10)},
    "cozy-minimal": {"top": ("floating", 34, 8)},
    "productivity": {"top": ("inset", 36, 6)},
    "minimal-top": {"top": ("attached", 34, 6)},
    "studio": {"top": ("attached", 36, 6)},
    "gaming": {"bottom": ("floating", 32, 8)},
    "dock-bottom": {"bottom": ("dock", 50, 8)},
    "hornero-left": {"left": ("attached", 60, 6)},
    "hornero-right": {"right": ("attached", 60, 6)},
    "minimal-left": {"left": ("attached", 48, 6)},
}


def test_calibration_table_covers_every_preset():
    assert sorted(CALIBRATION) == sorted(p.stem for p in PRESETS)


@pytest.mark.parametrize("path", PRESETS, ids=lambda p: p.stem)
def test_every_preset_matches_its_calibration(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    expected = CALIBRATION[path.stem]
    got = {b["edge"]: (b["style"], b["thickness"], b["margin"]) for b in data["bar"]["bars"]}
    assert got == expected, path.stem
    for bar in data["bar"]["bars"]:
        if bar["style"] == "dock":
            assert 40 <= bar["thickness"] <= 56
        elif bar["edge"] in ("left", "right"):
            assert 44 <= bar["thickness"] <= 64
        else:
            assert 26 <= bar["thickness"] <= 46, (path.stem, bar["edge"])
        assert bar["margin"] <= 18
        assert bar.get("radius", 0) <= 12
    assert 22 <= data["bar"]["sizes"]["innerWidth"] <= 46
    assert 1.0 <= data["bar"]["sizes"].get("contentScale", 1.0) <= 1.3
    if "border" in data:
        assert data["border"].get("thickness", 6) <= 6
    # Signal Bezel: no glassy slabs, radii stay at or below 4 px.
    appearance = data.get("appearance", {})
    assert "transparency" not in appearance, path.stem
    assert appearance.get("rounding", {}).get("scale", 1.0) <= 1.2


def test_hornero_rails_are_generous_but_other_bars_stay_slim():
    rails = [CALIBRATION[n][e][1] for n, e in (("hornero-left", "left"), ("hornero-right", "right"))]
    assert all(56 <= t <= 64 for t in rails)
    for name in ("hornero-left", "hornero-right"):
        sizes = json.loads((ROOT / "presets" / f"{name}.json").read_text(encoding="utf-8"))["bar"]["sizes"]
        assert sizes["innerWidth"] >= 40 and sizes["contentScale"] >= 1.2
    horizontals = [v[1] for n, bars in CALIBRATION.items() for e, v in bars.items()
                   if e in ("top", "bottom") and v[0] != "dock"]
    cockpit = {"cockpit", "cockpit-clear"}
    others = [v[1] for n, bars in CALIBRATION.items() if n not in cockpit for e, v in bars.items() if e in ("top", "bottom") and v[0] != "dock"]
    assert max(others) <= 36 and min(others) >= 26


def test_bar_body_has_no_extra_padding():
    wrapper = (ROOT / "modules/bar/BarWrapper.qml").read_text(encoding="utf-8")
    bar = (ROOT / "modules/bar/Bar.qml").read_text(encoding="utf-8")
    assert "readonly property int padding: 0" in wrapper
    assert "Density.thickness(spec.thickness)" in wrapper and "Density.thickness(spec.thickness)" in bar
    assert "Config.border.thickness" not in bar.split("barPadding")[1].split("\n")[0]


def test_bar_components_use_density_sizes_not_global_font_tokens():
    offenders = []
    for p in (ROOT / "modules/bar/components").rglob("*.qml"):
        src = p.read_text(encoding="utf-8")
        if "Appearance.font.size." in src or "Config.bar.sizes.innerWidth" in src:
            offenders.append(p.name)
    assert offenders == []


@pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")
@pytest.mark.parametrize("height,expected_text,expected_bar", [
    (720, 12, 32), (768, 12, 32), (960, 12, 33), (1080, 12, 34), (1440, 12, 35), (2160, 13, 37)])
def test_density_factor_bounds(height, expected_text, expected_bar):
    js = (ROOT / "services/density.js").read_text(encoding="utf-8").replace(".pragma library", "")
    script = js + f"""
const f = factor({height}, 1, true);
console.log(JSON.stringify({{f: f, text: text(f), icon: icon(f), bar: thickness(34, f), small: thickness(26, f), inner: inner(24, f), pad: segmentPadding(f, false), micro: micro(f)}}));
"""
    out = json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)
    # Gentle scaling: primary text never below 12 px, icons 15..18 px,
    # 24 px hit area, segment padding never below 8 px.
    assert out["text"] == expected_text
    assert 15 <= out["icon"] <= 18
    assert out["bar"] == expected_bar
    assert out["small"] >= 24 and out["inner"] >= 22 and out["pad"] >= 8
    assert out["f"] >= 0.94


def test_density_respects_user_scale_and_auto_off():
    js = (ROOT / "services/density.js").read_text(encoding="utf-8")
    assert "clamp(userScale > 0 ? userScale : 1, 0.75, 1.5)" in js
    assert "if (!auto || !(height > 0))" in js
