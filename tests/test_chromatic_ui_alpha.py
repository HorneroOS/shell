"""Translucent surfaces honour the scheme's minSurfaceAlpha (RFC 0002 §4.9)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pytest  # noqa: E402
from chromatic_ui_harness import requires_qs, run_scene  # noqa: E402


@requires_qs
def test_backdrop_alpha_never_drops_below_the_scheme_floor(tmp_path):
    r, before, after = run_scene(tmp_path, "alpha", HTRANSITION="instant")
    # Curated theme, base 0.5 (Signal Night: no light offset): user value.
    assert r["plain"]["panel"] == 0.5 and r["plain"]["bar"] == 0.5
    assert r["plain"]["layer0"] == pytest.approx(0.5, abs=0.01)
    # Chromatic scheme with floors base 0.9 / panel 0.92.
    assert r["floored"]["panel"] >= 0.92
    assert r["floored"]["bar"] >= 0.9
    assert r["floored"]["layer0"] >= 0.89
    assert r["floored"]["layer1"] >= 0.91
    assert r["floored"]["surface"] >= 0.91
    # An explicit per-element alpha above the floor is respected.
    assert r["explicit"]["launcher"] == pytest.approx(0.99)
    assert before == after


@requires_qs
def test_high_contrast_stays_opaque_whatever_the_floor(tmp_path):
    r, _, _ = run_scene(tmp_path, "alpha", HTRANSITION="instant", HHC=1)
    assert r["plain"]["panel"] == 1 and r["floored"]["panel"] == 1
