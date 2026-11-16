"""Battery popout gauge: a fill tank with charge and time left, the label
changing colour at the fill edge, semantic palette colours (no fixed hex),
a charging sheen gated by reduced motion, and design credit.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAUGE = (ROOT / "modules/bar/popouts/BatteryGauge.qml").read_text(encoding="utf-8")
POPOUT = (ROOT / "modules/bar/popouts/Battery.qml").read_text(encoding="utf-8")


def test_popout_uses_the_gauge_instead_of_plain_text():
    assert "BatteryGauge {" in POPOUT
    assert 'qsTr("Remaining: %1%")' not in POPOUT


def test_gauge_uses_semantic_palette_colours_only():
    for needle in ("phosphor", "alert", "cue", "cueWell", "Signal.on(root.fillColour)"):
        assert needle in GAUGE, needle
    code = "\n".join(line.split("//", 1)[0] for line in GAUGE.splitlines())
    assert not re.search(r'"#[0-9a-fA-F]{3,8}"', code)


def test_label_is_layered_and_sheen_respects_reduced_motion():
    assert GAUGE.count("Contents {") >= 2 and "clip: true" in GAUGE
    assert "visible: root.charging && !root.reducedMotion" in GAUGE
    assert "caelestia-material-battery (GPL-3.0" in GAUGE
