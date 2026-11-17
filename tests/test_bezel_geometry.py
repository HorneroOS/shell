"""Signal Bezel geometry: bar chrome and the frame cutout use small radii
(RFC 0001 s5.1, signal-visual-language), never pills."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_bar_modules_have_no_pill_radius():
    offenders = [str(p.relative_to(ROOT)) for p in (ROOT / "modules/bar").rglob("*.qml")
                 if "Appearance.rounding.full" in p.read_text(encoding="utf-8")]
    assert offenders == []


def test_floating_bar_surface_uses_normal_radius():
    src = (ROOT / "modules/bar/Bar.qml").read_text(encoding="utf-8")
    assert "radius: root.floating ? Appearance.rounding.small : 0" in src


def test_frame_cutout_radius_is_a_bezel_token():
    src = (ROOT / "config/BorderConfig.qml").read_text(encoding="utf-8")
    m = re.search(r"property int rounding: Appearance\.rounding\.(\w+)", src)
    assert m and m.group(1) == "small"
