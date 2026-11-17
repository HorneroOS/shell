"""Themes card and pane wiring for Chromatic (contract §7.3)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "modules" / "controlcenter" / "appearance"


def test_themes_section_lists_the_reserved_chromatic_card_after_the_catalogue():
    text = (APP / "sections" / "ThemesSection.qml").read_text()
    assert text.index("Repeater {") < text.index('id: chromaticCard')
    assert 'Signal.themeId === "hornero-chromatic"' in text
    assert 'navigateTo("appearance", "chromatic")' in text
    assert "Keys.onPressed" in text and "Accessible.role: Accessible.Button" in text


def test_appearance_pane_hosts_and_registers_the_chromatic_section():
    pane = (APP / "AppearancePane.qml").read_text()
    assert "ChromaticSection {" in pane and 'isSectionExpanded("chromatic")' in pane
    assert '"chromatic", "themes"' in pane and "chromatic: chromaticSection" in pane
    registry = (ROOT / "modules" / "controlcenter" / "PaneRegistry.qml").read_text()
    assert 'id: "chromatic"' in registry and 'section: "chromatic"' in registry


def test_section_controls_are_keyboard_reachable_and_named():
    section = (APP / "sections" / "ChromaticSection.qml").read_text()
    gallery = (APP / "sections" / "ChromaticVariantGallery.qml").read_text()
    assert "Keys.onEscapePressed" in section
    assert "activeFocusOnTab" in gallery and "Qt.Key_Space" in gallery and "Accessible.checked" in gallery
    assert section.count("accessibleName:") >= 4
    assert "Component.onDestruction: ChromaticPreview.previewLive(false)" in section
