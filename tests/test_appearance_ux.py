"""Appearance pane UX contract (docs/APPEARANCE-PANE.md).

Static checks always run. The offscreen checks render the REAL pane with
tests/qml/appearance/harness.qml in an isolated XDG tree and are reported
NOT RUN (never faked) without `qs`.
"""
import re
from pathlib import Path

from appearance_ux_harness import requires_qs, run_pane

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "modules" / "controlcenter" / "appearance"
PANE = (APP / "AppearancePane.qml").read_text()
STRIP = (APP / "NowUsingStrip.qml").read_text()
PREVIEW = (APP / "AppearancePreviewPane.qml").read_text()
THEMES = (APP / "sections" / "ThemesSection.qml").read_text()

ORDER = ["themes", "chromatic", "accent", "themeEditor", "background", "look", "atmosphere", "transparency", "border", "fonts", "scales", "animations", "gtkTheme", "gtkColorScheme", "iconTheme", "health"]


def _keys():
    block = PANE.split("readonly property var _sectionKeys: [", 1)[1].split("]", 1)[0]
    return re.findall(r'"(\w+)"', block)


def test_themes_come_first_then_chromatic_and_health_last():
    assert _keys() == ORDER
    # the sections are laid out in that same order
    assert re.findall(r'property string sectionKey: "(\w+)"', PANE) == ORDER


def test_sections_are_grouped_under_headings():
    labels = re.findall(r'AppearanceGroupLabel \{\s*label: qsTr\("([^"]+)"\)', PANE)
    assert labels == ["Colour", "Wallpaper & desktop", "Look & feel", "Type & motion", "Apps: GTK, Qt and icons", "Health"]
    group = (APP / "AppearanceGroupLabel.qml").read_text()
    assert "Accessible.role: Accessible.Heading" in group


def test_now_using_strip_is_pinned_above_the_scrolling_sections():
    left = PANE.split("leftContent: Component {", 1)[1].split("rightContent:", 1)[0]
    assert left.index("NowUsingStrip {") < left.index("StyledFlickable {")


def test_now_using_strip_names_what_is_applied_never_a_preview():
    # while the live shell shows a pointed Chromatic style, the strip reads
    # Signal's pre-preview snapshot
    assert "Signal.previewing ? Signal._snapshot : null" in STRIP
    for kind in ('"contrast"', '"chromatic"', '"theme"', '"custom"'):
        assert kind in STRIP
    # Chromatic: style, mode and source
    assert "Cli.appliedStyle(appliedChromatic)" in STRIP and "sourceLabel()" in STRIP
    # a preview only adds a note, and the Undo for the last appearance change sits here
    assert 'Microcopy.line("appearance.previewing")' in STRIP
    assert "Undo.undo()" in STRIP and '"appearance", "chromatic"' in STRIP
    assert "Accessible.name:" in STRIP


def test_preview_has_three_legible_states():
    assert 'objectName: "previewBanner"' in PREVIEW
    for state in ('"previewing"', '"applying"'):
        assert state in PREVIEW
    assert 'readonly property string previewState: (ThemePipeline.busy || ChromaticPreview.applying) ? "applying"' in PANE
    assert 'Microcopy.line("appearance.clickToUse")' in PREVIEW
    # leaving an item returns to "Now using", never to an empty card
    end = PANE.split("function endPreviewFor(source: string): void {", 1)[1].split("\n    }\n", 1)[0]
    assert "syncCurrentThemePreview()" in end


def test_preview_is_the_honest_specimen_with_measured_contrast():
    assert "ChromaticSpecimenBoard {" in PREVIEW and "palette: root.flat" in PREVIEW
    assert "Colour.contrast(r.fg, r.bg)" in PREVIEW
    assert '"min": 4.5' in PREVIEW and '"min": 3' in PREVIEW
    # a pointed Chromatic style is drawn from its own engine scheme
    assert "ChromaticPreview.variantSchemes[hoverStyle]" in PREVIEW


def test_every_hover_preview_ends_when_the_pointer_or_focus_leaves():
    assert 'onExited: {\n                            if (!cardInteractive.activeFocus)\n                                previewController.endPreviewFor("theme");' in THEMES
    assert "onActiveFocusChanged:" in THEMES and "hoverThemePreview(" in THEMES
    grid = (ROOT / "modules" / "controlcenter" / "components" / "WallpaperGrid.qml").read_text()
    assert 'endPreviewFor("wallpaper")' in grid
    gtk = (APP / "sections" / "GtkColorSchemeSection.qml").read_text()
    assert 'endPreviewFor("gtk-color-scheme")' in gtk


def test_one_selection_language_for_theme_cards():
    assert 'text: qsTr("In use")' in THEMES and THEMES.count("StateChip {") >= 4
    assert "border.width: themeItem.isCurrent || themeItem.isPreviewed ? 2 : 1" in THEMES
    assert "Accessible.checked: themeItem.isCurrent" in THEMES
    # glyph + words, never colour alone; the old staged chips are gone
    assert '"heart" : "check"' in THEMES
    assert 'qsTr("Pending")' not in THEMES and 'qsTr("Selected")' not in THEMES
    assert 'qsTr("Your palettes")' in THEMES


def test_no_apply_buttons_in_appearance():
    for path in APP.rglob("*.qml"):
        text = path.read_text()
        assert not re.search(r'text: qsTr\("Apply\b', text), path.name
        assert "stagedChip" not in text


def test_hover_preview_is_a_user_setting_with_a_default():
    cfg = (ROOT / "config" / "ControlCenterConfig.qml").read_text()
    assert "property bool appearanceHoverPreview: true" in cfg
    assert "appearanceHoverPreview: controlCenter.appearanceHoverPreview" in (ROOT / "config" / "Config.qml").read_text()
    assert '"appearanceHoverPreview": true' in (ROOT / "config" / "shell.default.json").read_text()
    look = (APP / "sections" / "LookSection.qml").read_text()
    assert "Config.controlCenter.appearanceHoverPreview = checked" in look
    assert "hoverPreviewEnabled" in PANE and "appearanceHoverPreview" in (APP / "sections" / "ChromaticVariantGallery.qml").read_text()
    assert "controlCenter.appearanceHoverPreview" in (ROOT / "docs" / "CUSTOMISATION.md").read_text()


def test_microcopy_has_both_voices_and_motion_respects_reduced():
    micro = (ROOT / "services" / "Microcopy.qml").read_text()
    for key in ("appearance.now", "appearance.previewing", "appearance.clickToUse", "appearance.applying"):
        assert micro.count(f'"{key}"') == 2, key
    assert "enabled: !Appearance.anim.reduced" in PREVIEW
    assert "Behavior on" not in STRIP


@requires_qs
def test_offscreen_pane_order_strip_and_banner(tmp_path):
    idle = run_pane(tmp_path / "idle")
    assert idle["sections"] == ORDER, idle["sections"]
    strip = idle["nowUsing"]
    assert strip and strip["visible"] and strip["kind"] == "theme"
    assert strip["title"] == "Hornero Signal Night" and strip["previewName"] == ""
    assert idle["banner"]["visible"] and idle["banner"]["state"] == "now"
    assert "Hornero Signal Night" in idle["banner"]["text"]
    assert not [b for b in idle["buttons"] if b.startswith("Apply")]


@requires_qs
def test_offscreen_theme_preview_then_back_to_now(tmp_path):
    on = run_pane(tmp_path / "on", scene="preview-theme")
    assert on["previewState"] == "previewing" and on["banner"]["state"] == "previewing"
    assert "Hornero Signal Day" in on["banner"]["text"]
    # the strip still names the applied theme, with a note
    assert on["nowUsing"]["title"] == "Hornero Signal Night"
    assert on["nowUsing"]["previewName"] == "Hornero Signal Day"
    off = run_pane(tmp_path / "off", scene="preview-end")
    assert off["previewState"] == "now" and off["banner"]["state"] == "now"
    assert "Hornero Signal Night" in off["banner"]["text"] and off["nowUsing"]["previewName"] == ""


@requires_qs
def test_offscreen_chromatic_style_preview_is_named(tmp_path):
    res = run_pane(tmp_path / "v", scene="preview-variant")
    assert res["variantHovered"] == "vibrant", (res.get("variantEngine"), res.get("variantFailed"))
    assert res["banner"]["state"] == "previewing" and "Chromatic · Vibrant" in res["banner"]["text"]
    assert res["nowUsing"]["title"] == "Hornero Signal Night"


def test_applied_style_reads_both_live_and_engine_shapes():
    cli = (ROOT / "services" / "chromaticcli.js").read_text()
    body = cli.split("function appliedStyle(block) {", 1)[1].split("\n}\n", 1)[0]
    # live schemes carry `variant`; engine documents nest it under `resolved`
    assert "block.variant" in body and "block.resolved.variant" in body
