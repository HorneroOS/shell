"""Appearance themes are Signal swatch cards: a role-palette face per theme,
square Bezel chips, and no Material scheme-variant vocabulary."""
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent
APPEARANCE = ROOT / "modules/controlcenter/appearance"
SECTION = (APPEARANCE / "sections/ThemesSection.qml").read_text()
SWATCH = (APPEARANCE / "ThemeSwatch.qml").read_text()


def test_theme_cards_render_the_signal_swatch_from_the_theme_palette():
    assert "ThemeSwatch {" in SECTION
    assert "previewController.paletteForTheme(themeItem.modelData)" in SECTION
    for role in ("ground", "panel", "ink", "signal", "cue", "phosphor", "alert"):
        assert f'"{role}"' in SWATCH or f'role("{role}")' in SWATCH, role
    # A partial registry swatch falls back to the live roles, never undefined.
    assert "?? Signal.palette[name]" in SWATCH


def test_theme_cards_use_bezel_chips_not_pills():
    assert "Appearance.rounding.full" not in SECTION
    assert 'qsTr("Night")' in SECTION and 'qsTr("Day")' in SECTION and 'qsTr("Contrast")' in SECTION


def test_no_material_scheme_variants_in_appearance_pane():
    pattern = re.compile(r"tonal-spot|fidelity|expressive|vibrant|schemeType|variant", re.I)
    for path in APPEARANCE.rglob("*.qml"):
        text = path.read_text()
        assert not pattern.search(text), f"{path.name} mentions a Material scheme variant"
