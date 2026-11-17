"""Every colour chooser in Appearance shows the option's real colours.

Static contract checks always run; the offscreen run needs `qs` and is
reported NOT RUN (never faked) without it."""
import re
from pathlib import Path

import pytest

from palettes_harness import requires_qs, run_gallery

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "modules" / "controlcenter" / "appearance"
SECTIONS = APP / "sections"
OPTION = (APP / "PaletteOption.qml").read_text()
SWATCH = (APP / "ThemeSwatch.qml").read_text()


def test_one_swatch_component_serves_every_chooser():
    # variants, GTK colour scheme and saved palettes use the shared tile
    for name in ("ChromaticVariantGallery.qml", "GtkColorSchemeSection.qml", "ChromaticSection.qml"):
        assert "PaletteOption {" in (SECTIONS / name).read_text(), name
    # the tile itself draws the colours through ThemeSwatch
    assert "ThemeSwatch {" in OPTION
    # Themes cards share the same face, now with the terminal strip
    themes = (SECTIONS / "ThemesSection.qml").read_text()
    assert themes.count("showTerminal") >= 2 and "terminalForTheme" in themes


def test_swatch_only_draws_colours_the_data_carries():
    for role in ("ground", "panel", "ink", "signal", "cue", "phosphor", "alert"):
        assert f'"{role}"' in SWATCH, role
    for i in range(1, 7):
        assert str(i) in re.search(r"terminalStrip: \[(.*?)\]", SWATCH).group(1)
    # terminal colours come from the palette (termN) or the scheme's array,
    # never from the live shell palette
    assert 'root.palette["term" + i]' in SWATCH and "Signal.palette[\"term" not in SWATCH
    assert "hasTerminal" in SWATCH and 'root.term(1) !== ""' in SWATCH


def test_no_hardcoded_hex_in_palette_choosers():
    for path in (APP / "PaletteOption.qml", APP / "ThemeSwatch.qml", SECTIONS / "ChromaticVariantGallery.qml", SECTIONS / "GtkColorSchemeSection.qml"):
        assert not re.search(r"#[0-9A-Fa-f]{6}\b", path.read_text()), path.name


def test_palette_tile_is_keyboard_and_assistive_tech_ready():
    assert "activeFocusOnTab" in OPTION and "Qt.Key_Space" in OPTION and "Qt.Key_Return" in OPTION
    assert "Accessible.checked: selected" in OPTION and "Accessible.name: title" in OPTION
    assert "Accessible.description" in OPTION and "Accessible.onPressAction" in OPTION
    # focus is a visible ring, selection is spelled out (glyph), no animation
    assert "Signal.palette.focus" in OPTION and 'name: "check"' in OPTION
    assert "Behavior" not in OPTION and "Anim" not in OPTION
    assert not re.search(r"\bMaterial\b|\bm3[A-Z]", OPTION + SWATCH)


def test_gtk_scheme_rows_show_real_signal_tables():
    gtk = (SECTIONS / "GtkColorSchemeSection.qml").read_text()
    assert 'Signal.builtInThemes["hornero-signal-day"]' in gtk and 'Signal.builtInThemes["hornero-signal-night"]' in gtk
    assert "onPreviewStarted: previewController.startGtkColorSchemePreview" in gtk


def test_variant_previews_are_engine_results_computed_on_demand():
    svc = (ROOT / "services" / "ChromaticPreview.qml").read_text()
    assert "variantPreviewsWanted" in svc and "variantSchemes" in svc and "variantFailed" in svc
    gallery = (SECTIONS / "ChromaticVariantGallery.qml").read_text()
    assert "ChromaticPreview.variantPreviewsWanted = true" in gallery
    assert "Component.onDestruction: ChromaticPreview.variantPreviewsWanted = false" in gallery


@requires_qs
def test_offscreen_gallery_renders_all_variant_palettes(tmp_path):
    png = tmp_path / "gallery.png"
    result = run_gallery(tmp_path, png=png)
    assert sorted(result["variantSchemes"]) == sorted(["balanced", "vibrant", "expressive", "faithful", "muted", "monochrome", "high-contrast", "neon"])
    assert result["variantFailed"] == []
    assert result["saved"] is True and png.stat().st_size > 10_000
    log = result["_helper_log"]
    for variant in ("balanced", "vibrant", "expressive", "faithful", "muted", "monochrome", "high-contrast", "neon"):
        assert f"--variant {variant}" in log, variant
