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
    # variants and GTK colour scheme use the shared tile; saved palettes are
    # listed once, under Themes > Your palettes, on the same ThemeSwatch face
    for name in ("ChromaticVariantGallery.qml", "GtkColorSchemeSection.qml"):
        assert "PaletteOption {" in (SECTIONS / name).read_text(), name
    assert 'qsTr("Your palettes")' in (SECTIONS / "ThemesSection.qml").read_text()
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
    assert "Signal.palette.focus" in OPTION and '"heart" : "check"' in OPTION
    assert "Behavior" not in OPTION and "Anim" not in OPTION
    assert not re.search(r"\bMaterial\b|\bm3[A-Z]", OPTION + SWATCH)


def test_gtk_scheme_rows_show_real_signal_tables():
    gtk = (SECTIONS / "GtkColorSchemeSection.qml").read_text()
    assert 'Signal.builtInThemes["hornero-signal-day"]' in gtk and 'Signal.builtInThemes["hornero-signal-night"]' in gtk
    started = gtk.split("onPreviewStarted:", 1)[1].split("onPreviewEnded:", 1)[0]
    assert "previewController.startGtkColorSchemePreview" in started
    assert 'endPreviewFor("gtk-color-scheme")' in gtk


def test_variant_previews_are_engine_results_computed_on_demand():
    svc = (ROOT / "services" / "ChromaticPreview.qml").read_text()
    assert "variantPreviewsWanted" in svc and "variantSchemes" in svc and "variantFailed" in svc
    gallery = (SECTIONS / "ChromaticVariantGallery.qml").read_text()
    assert "ChromaticPreview.variantPreviewsWanted = true" in gallery
    assert "ChromaticPreview.variantPreviewsWanted = false" in gallery and "ChromaticPreview.endHover(\"\")" in gallery


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


EDITOR = (SECTIONS / "ThemeEditorSection.qml").read_text()


def test_editor_is_wired_into_the_pane_and_search():
    pane = (APP / "AppearancePane.qml").read_text()
    assert "ThemeEditorSection {" in pane and "themeEditor: themeEditorSection" in pane
    assert '"themeEditor"' in pane.split("_sectionKeys", 1)[1].split("]", 1)[0]
    assert 'section: "themeEditor"' in (ROOT / "modules" / "controlcenter" / "PaneRegistry.qml").read_text()


def test_editor_never_writes_without_save_and_uses_the_gated_cli():
    assert "chromatic import" in EDITOR and "themeImportTail" in EDITOR
    assert "Component.onDestruction" in EDITOR and "Signal.cancelPreview()" in EDITOR
    assert "Reset all" in EDITOR and 'qsTr("Reset")' in EDITOR
    assert "Accessible.name" in EDITOR and "activeFocusOnTab" in EDITOR
    assert not re.search(r"#[0-9A-Fa-f]{6}\b", EDITOR)


@requires_qs
def test_offscreen_editor_edits_previews_saves_and_resets(tmp_path):
    result = run_gallery(tmp_path, HEDIT=1)
    assert result["sourceEditable"] is True
    edit = result["edit"]
    # an invalid hex is ignored; the accent re-derives readable text and glow
    assert edit["signal"] == "#FF00AA" and edit["term3"] == "#112233" and edit["ink"] != "NOT-A-COLOUR"
    assert edit["onSignal"] != "#FF00AA" and edit["glow"] == "#FF00AA"
    assert result["previewing"] is True and result["previewingAfter"] is False
    assert result["status"].startswith("Saved") and result["statusIsError"] is False
    assert result["afterReset"] is True
    draft = result["_draft"]
    assert draft["schemaVersion"] == 2 and draft["id"] == "my-neon-copy" and draft["name"] == "My Neon Copy"
    assert draft["palette"]["signal"] == "#FF00AA" and len(draft["terminal"]) == 16 and draft["terminal"][3] == "#112233"
    assert "appearance chromatic import" in result["_ctl_log"] and "--id my-neon-copy" in result["_ctl_log"] and "--yes" in result["_ctl_log"]


@requires_qs
def test_offscreen_saved_palette_rename_delete_undo(tmp_path):
    result = run_gallery(tmp_path, HMANAGE=1)
    assert result["isUser"] is True
    assert result["renamed"] == "Renamed."
    assert result["deleted"].startswith("Deleted") and result["trashed"] == "my-dusk" and result["sourceAfterDelete"] == ""
    assert result["restored"] == "Restored." and result["trashAfter"] is True
    log = result["_ctl_log"]
    assert "appearance chromatic rename my-dusk --name My Dusk" in log or "rename my-dusk --name" in log
    assert "chromatic delete my-dusk --json --yes" in log
    # undo re-imports the exact deleted theme under its own id
    assert "--id my-dusk --json --yes" in log
    assert result["_draft"]["id"] == "my-dusk" and result["_draft"]["name"] == "My Dusk"


def test_editor_manages_saved_palettes_with_confirm_and_undo():
    assert "renameArgs" in EDITOR and "deleteArgs" in EDITOR
    # Delete is immediate and offers the shared Undo (no confirm step).
    assert "Really delete?" not in EDITOR and 'Undo.offerCommand("theme-delete"' in EDITOR
@requires_qs
def test_offscreen_accent_override_resolution_and_reset(tmp_path):
    r = run_gallery(tmp_path, HACCENT=1)
    # global accent: accent, glow follow, readable text on it
    assert r["global"][0].lower() == "#ffb5d2" and r["global"][1].lower() == "#ffb5d2"
    assert r["global"][2].lower() in (r["ground"].lower(), r["ink"].lower())
    # per-colour-mode beats global; per-experience-mode beats per-colour-mode
    assert r["perModeBeatsGlobal"].lower() == "#a6d6ff"
    assert r["perExperienceBeatsMode"].lower() == "#b9e5a0" and r["ctxMode"] == "everyday"
    # invalid values are ignored and clearing returns the theme's own accent
    assert r["invalidIgnored"] is True and r["resetToTheme"] is True


def test_accent_is_in_config_schema_defaults_and_ui():
    import json

    defaults = json.loads((ROOT / "config" / "shell.default.json").read_text())["appearance"]["accent"]
    assert defaults == {"color": "", "perMode": {"dark": "", "light": ""}, "perExperience": {}}
    config = (ROOT / "config" / "Config.qml").read_text()
    assert "perExperience: appearance.accent.perExperience" in config
    section = (SECTIONS / "AccentSection.qml").read_text()
    assert "Reset" in section and "Low contrast on this theme" in section and "Accessible.name" in section
    # presets are an opt-in data file, with a dark and a light twin each
    presets = (ROOT / "services" / "accents.js").read_text()
    assert presets.count("group: \"kawaii\"") >= 6 and presets.count("light:") >= 6
def test_variant_tiles_preview_on_hover_and_focus_transiently():
    gallery = (SECTIONS / "ChromaticVariantGallery.qml").read_text()
    started = gallery.split("onPreviewStarted:", 1)[1].split("onPreviewEnded:", 1)[0]
    assert "ChromaticPreview.hoverVariant(" in started and "Config.controlCenter.appearanceHoverPreview" in started
    assert "onPreviewEnded: ChromaticPreview.endHover(" in gallery
    svc = (ROOT / "services" / "ChromaticPreview.qml").read_text()
    assert "function hoverVariant" in svc and "function endHover(id: string)" in svc and "_resumeLive" in svc
    # the shared 30 s idle timer also ends a forgotten hover
    assert 'root.hoveredVariant = "";' in svc


@requires_qs
def test_offscreen_hover_preview_is_transient_and_restores(tmp_path):
    r = run_gallery(tmp_path, HHOVER=1)
    assert r["before"] != r["during"] and r["duringPreviewing"] is True
    assert r["staleExitKept"] is True
    assert r["after"] == r["before"] and r["afterPreviewing"] is False
    # an existing candidate preview is resumed, not dropped
    assert r["resumed"] == r["candidate"] and r["resumedPreviewing"] is True
    assert r["afterResume"] == r["before"] and r["hoverClearedOnEnd"] is True
def test_cozy_chips_is_a_persisted_default_on_setting_with_a_switch():
    import json

    assert json.loads((ROOT / "config" / "shell.default.json").read_text())["appearance"]["cozyChips"] is True
    assert "cozyChips: appearance.cozyChips" in (ROOT / "config" / "Config.qml").read_text()
    themes = (SECTIONS / "ThemesSection.qml").read_text()
    assert "Config.appearance.cozyChips = checked" in themes
    # soft shapes only change radius and the selected glyph; the sharp Bezel stays one switch away
    assert "Config.appearance.cozyChips ? Appearance.rounding.large" in OPTION
    assert "Config.appearance.cozyChips ? Appearance.rounding.normal" in SWATCH
