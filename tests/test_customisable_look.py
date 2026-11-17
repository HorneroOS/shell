"""Looks and glow intensity are user settings with a safe factory default."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOOK = (ROOT / "modules/controlcenter/appearance/sections/LookSection.qml").read_text()
FACTORY = json.loads((ROOT / "config/shell.default.json").read_text())


def _looks():
    out = {}
    for m in re.finditer(r'id: "(\w+)".*?rounding: ([\d.]+), spacing: ([\d.]+), padding: ([\d.]+), font: ([\d.]+), motion: ([\d.]+), glow: ([\d.]+)', LOOK, re.S):
        out[m.group(1)] = [float(x) for x in m.groups()[1:]]
    return out


def test_factory_look_equals_factory_config():
    a = FACTORY["appearance"]
    factory = [a["rounding"]["scale"], a["spacing"]["scale"], a["padding"]["scale"],
               a["font"]["size"]["scale"], a["anim"]["durations"]["scale"], a["glow"]["intensity"]]
    assert _looks()["hornero"] == factory, "Reset look must restore the factory config"


def test_cozy_look_is_softer_and_within_control_ranges():
    looks = _looks()
    assert "cozy" in looks
    rounding, spacing, padding, font, motion, glow = looks["cozy"]
    assert rounding > 1 and glow <= 1.5
    # Slider ranges in ScalesSection / Fonts / Animations / Glow
    assert 0.1 <= rounding <= 5 and 0.1 <= spacing <= 2 and 0.5 <= padding <= 2
    assert 0.5 <= font <= 2 and 0.01 <= motion <= 5


def test_glow_intensity_is_clamped_and_consumed():
    app = (ROOT / "services/Signal.qml").read_text()
    assert "Math.max(0, Math.min(1.5, Config.appearance.glow.intensity))" in app
    for f in ("components/OnAirBar.qml", "modules/instruments/ScopeTrace.qml"):
        assert "Signal.glowIntensity" in (ROOT / f).read_text()


def test_look_section_is_registered_and_searchable():
    pane = (ROOT / "modules/controlcenter/appearance/AppearancePane.qml").read_text()
    assert "LookSection {" in pane and 'isSectionExpanded("look")' in pane
    assert '"look"' in pane.split("_sectionKeys", 1)[1].split("]", 1)[0]
    assert 'id: "look"' in (ROOT / "modules/controlcenter/PaneRegistry.qml").read_text()


def test_factory_look_has_factory_weight_and_curve():
    a = FACTORY["appearance"]
    assert a["font"]["weight"]["shift"] == 0 and a["anim"]["curveStyle"] == "smooth"
    m = re.search(r'id: "hornero".*?weight: (-?\d+), curve: "(\w+)"', LOOK, re.S)
    assert (int(m.group(1)), m.group(2)) == (0, "smooth")


def test_weight_tokens_replace_literals():
    bad = [str(p) for p in (ROOT / "modules").rglob("*.qml") if re.search(r"font\.weight: (500|600)$", p.read_text(), re.M)]
    assert not bad, f"use Appearance.font.weight tokens: {bad}"


def test_wallpaper_fit_is_a_setting_with_factory_crop():
    assert FACTORY["background"]["wallpaperFit"] == "crop"
    wp = (ROOT / "modules/background/Wallpaper.qml").read_text()
    assert "Config.background.wallpaperFit" in wp
    for needle in ("fillMode: root.videoFill", "fillMode: root.imageFill"):
        assert needle in wp
    assert "fillMode: Image.PreserveAspectCrop" not in wp
    sec = (ROOT / "modules/controlcenter/appearance/sections/BackgroundSection.qml").read_text()
    for opt in ("crop", "fit", "stretch", "center"):
        assert f'id: "{opt}"' in sec
