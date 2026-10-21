"""Appearance pane option rows must be named buttons.

The appearance sections render option rows as StyledRect +
Interactive (a focusable StateLayer) with no native button, so
without an Accessible declaration they are invisible to AT-SPI.
Each delegate names itself after its visible label and marks the
current selection, following the launcher rows pattern.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SECTIONS = ROOT / "modules" / "controlcenter" / "appearance" / "sections"

FILES = [
    SECTIONS / "ColorSchemeSection.qml",
    SECTIONS / "ColorVariantSection.qml",
    SECTIONS / "GtkColorSchemeSection.qml",
    SECTIONS / "GtkThemeSection.qml",
    SECTIONS / "IconThemeSection.qml",
    SECTIONS / "FontsSection.qml",
    ROOT / "modules" / "controlcenter" / "components" / "WallpaperGrid.qml",
]


def test_option_rows_are_named_buttons():
    for path in FILES:
        src = path.read_text()
        assert "Accessible.role: Accessible.Button" in src, path.name
        assert "Accessible.name:" in src, path.name
        assert 'qsTr("%1, current")' in src, path.name


def test_fonts_section_names_both_lists():
    src = (SECTIONS / "FontsSection.qml").read_text()
    assert src.count("Accessible.role: Accessible.Button") == 2
