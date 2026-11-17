"""Thin bars: shipped thicknesses, 3 px radii and the density factor."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PRESETS = sorted((ROOT / "presets").glob("*.json"))
LIMITS = {"top": 28, "bottom": 28, "left": 34, "right": 34}


@pytest.mark.parametrize("path", PRESETS, ids=lambda p: p.stem)
def test_every_preset_is_thin(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    for bar in data["bar"]["bars"]:
        if bar["style"] == "dock":
            assert bar["thickness"] <= 36
            continue
        assert 24 <= bar["thickness"] <= LIMITS[bar["edge"]], (path.stem, bar["edge"])
        assert bar["margin"] <= 6
    assert data["bar"]["sizes"]["innerWidth"] <= 26
    if "border" in data:
        assert data["border"].get("thickness", 6) <= 6


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
    (720, 11, 24), (768, 11, 25), (960, 11, 27), (1080, 12, 28), (1440, 12, 29)])
def test_density_factor_bounds(height, expected_text, expected_bar):
    js = (ROOT / "services/density.js").read_text(encoding="utf-8").replace(".pragma library", "")
    script = js + f"""
const f = factor({height}, 1, true);
console.log(JSON.stringify({{f: f, text: text(f), icon: icon(f), bar: thickness(28, f), inner: inner(22, f)}}));
"""
    out = json.loads(subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True).stdout)
    assert out["text"] == expected_text
    assert 14 <= out["icon"] <= 16
    assert out["bar"] == expected_bar
    assert out["bar"] >= 24 and out["inner"] >= 20


def test_density_respects_user_scale_and_auto_off():
    js = (ROOT / "services/density.js").read_text(encoding="utf-8")
    assert "clamp(userScale > 0 ? userScale : 1, 0.75, 1.5)" in js
    assert "if (!auto || !(height > 0))" in js
