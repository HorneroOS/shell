"""High Contrast always overrides Chromatic (RFC 0002 §11)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chromatic_ui_harness import ROOT, requires_qs, run_scene  # noqa: E402
from signal_tokens import built_in_themes  # noqa: E402

SIGNAL = (ROOT / "services" / "Signal.qml").read_text()


def test_palette_binding_still_prefers_the_contrast_table():
    assert "Config.appearance.highContrast ? contrastPalette : current" in SIGNAL
    assert "!Config.appearance.highContrast" in SIGNAL  # transparency + transitions


@requires_qs
def test_high_contrast_wins_over_a_previewed_chromatic_palette(tmp_path):
    r, before, after = run_scene(tmp_path, "hc", HHC=1, HTRANSITION="instant")
    hc = built_in_themes()["hornero-signal-contrast"]["palette"]["ground"].lower()
    assert r["palette"].lower() == hc, "Signal.palette is not the contrast table"
    assert r["current"].lower() != hc, "the candidate is still staged underneath"
    assert r["style"] == "contrast"
    # Clear ink falls back to the fixed Night/Day sets, never the scheme's.
    assert r["inkSets"]["light"]["ink"].lower() == "#ece6da"
    assert before == after
