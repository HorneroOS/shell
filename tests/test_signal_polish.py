"""Static contracts for shell#514 (theme card text) and #515 ."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_theme_names_stay_inside_their_column():
    src = (ROOT / "modules/controlcenter/appearance/sections/ThemesSection.qml").read_text()
    name = src[src.index("text: modelData.name ?? modelData.id"):]
    name = name[:name.index("}")]
    assert "elide: Text.ElideRight" in src and "maximumLineCount: 2" in name
    assert "Layout.preferredWidth: 0" in src  # the column cannot push into the mode chip
