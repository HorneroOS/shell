"""Appearance consistency: QML applies theming through native layers first —
GtkSettings (gsettings) for GTK application and the ImageAnalyser plugin
for wallpaper tone analysis — and reaches outside the repo only through
`horneroctl` verbs owned by HorneroOS/hornero. No `dots-*` wrapper may
remain in QML; QML must never call gtk-theme-manager.sh directly, never
run bare `python3 generate-m3-colors`, and never spawn bare `python3`
for theme listing (theme packs list via
`horneroctl appearance theme list --full`)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML_DIRS = [ROOT / d for d in ("modules", "services", "config", "utils", "components")]

# Every dots-* wrapper the shell ever shelled out to. All retired: the
# native horneroctl verbs cover each one (see docs/MIGRATION.md).
RETIRED_WRAPPERS = [
    "dots-gtk-theme",
    "dots-m3-colors",
    "dots-color-scheme",
    "dots-appearance",
    "dots-accent-override",
    "dots-night-mode",
    "dots-wallpaper-current",
    "dots-wallpaper-set",
    "dots-recorder",
    "dots-screenshooter",
    "dots-settings-gui",
    "dots-snappy-switcher",
    "dots-hyprlock-theme",
    "dots-lockscreen",
    "dots-sysupdate",
    "dots-keyboard-help",
    "dots-theme-selector",
]


def _qml_files():
    for d in QML_DIRS:
        yield from d.rglob("*.qml")


def _hits(needle):
    return [p for p in _qml_files() if needle in p.read_text()]


def test_no_direct_gtk_theme_manager():
    hits = _hits("gtk-theme-manager.sh")
    assert not hits, f"direct gtk-theme-manager.sh calls in: {hits}"


def test_no_bare_generate_m3_colors():
    hits = _hits("generate-m3-colors")
    assert not hits, f"bare generate-m3-colors calls in: {hits}"


def test_no_retired_dots_wrappers_in_qml():
    hits = []
    for path in _qml_files():
        text = path.read_text()
        for dead in RETIRED_WRAPPERS:
            if dead in text:
                hits.append(f"{path.relative_to(ROOT)}: {dead}")
    assert not hits, f"retired wrappers referenced by QML:\n" + "\n".join(hits)


def test_canonical_cli_calls_present():
    # Only files that actually spawn processes count (AppList.qml routes a
    # "scheme" launcher keyword without spawning anything).
    def _spawning():
        for p in _qml_files():
            text = p.read_text()
            if "execDetached" in text or "command:" in text:
                yield p, text

    spawning = list(_spawning())
    gtk = [p for p, text in spawning if '"gtk"' in text]
    assert gtk, "expected horneroctl appearance gtk calls in QML"
    scheme = [p for p, text in spawning if '"scheme"' in text]
    assert scheme, "expected horneroctl scheme calls in QML"
    m3 = [p for p, text in spawning if '"m3"' in text]
    assert m3, "expected horneroctl appearance colors m3 calls in QML"
    for path in gtk + scheme + m3:
        assert '"horneroctl"' in path.read_text(), (
            f"{path.relative_to(ROOT)}: appearance calls must go through horneroctl"
        )


def test_no_bare_python_theme_loader():
    py_hits = [p for p in _qml_files()
               if '"python3"' in p.read_text() or "'python3'" in p.read_text()]
    assert not py_hits, f"bare python3 spawn in QML: {py_hits}"
    loader_hits = _hits("list-themes")
    assert not loader_hits, f"list-themes.py references in QML: {loader_hits}"


def test_theme_listing_uses_cli():
    hits = [p for p in _qml_files() if '"horneroctl"' in p.read_text()]
    assert hits, "expected horneroctl calls in QML"
    list_hits = [p for p in hits
                 if '"theme"' in p.read_text() and '"list"' in p.read_text()
                 and '"--full"' in p.read_text()]
    assert list_hits, (
        f"theme listing must use `horneroctl appearance theme list --full`: {hits}"
    )


def test_native_gtk_layer_present():
    layer = ROOT / "services" / "GtkSettings.qml"
    assert layer.exists(), "services/GtkSettings.qml native layer missing"
    text = layer.read_text()
    assert "gsettings" in text, "GtkSettings must drive gsettings natively"
    assert "toGsettingsScheme" in text, "GtkSettings must map policy deterministically"
    pipeline = (ROOT / "services" / "ThemePipeline.qml").read_text()
    assert "GtkSettings.applyFull" in pipeline, "ThemePipeline finalize must use GtkSettings"
    assert "GtkSettings.applyGtkTheme" in pipeline, "ThemePipeline setGtk must use GtkSettings"
    assert "GtkSettings.applyColorScheme" in pipeline, "ThemePipeline color-scheme must use GtkSettings"
    assert "GtkSettings.applyIconTheme" in pipeline, "ThemePipeline setIcons must use GtkSettings"


def test_theme_pack_apply_uses_registry_and_propagates_errors():
    text = (ROOT / "services" / "GtkSettings.qml").read_text()
    assert 'if (kind === "full" && _themeId)' in text, (
        "a selected pack id must use the shared GTK pack resolver even when "
        "the pack also declares an explicit GTK theme name"
    )
    compat = text[text.index("function _compatFor"):text.index("// Native apply:")]
    assert 'if [[ -n "\\${HORNERO_THEME_ID:-}" ]]; then' in compat
    assert "|| true" not in compat, "failed GTK operations must reach the caller"
    assert "exitCode === 0" in text and "root._finishApply(false" in text, (
        "the compatibility process must not report success after a failed command"
    )


def test_native_gtk_apply_persists_gsettings_to_gtk_ini():
    text = (ROOT / "services" / "GtkSettings.qml").read_text()
    native = text.split("id: nativeProc", 1)[1].split("id: compatProc", 1)[0]
    assert "if (exitCode === 0)" in native
    assert "root._compatKind = root._nativeKind" in native
    assert "compatProc.running = true" in native, (
        "successful gsettings writes must also persist GTK theme/icon/scheme "
        "to settings.ini through the horneroctl adapter"
    )


def test_theme_pipeline_uses_installed_catalogue_metadata():
    catalogue = (ROOT / "services" / "ThemeCatalogue.qml").read_text()
    pipeline = (ROOT / "services" / "ThemePipeline.qml").read_text()
    launcher = (ROOT / "modules" / "launcher" / "services" / "Themes.qml").read_text()
    assert '\"list\", \"--full\"' in catalogue
    assert "ThemeCatalogue.themeById(job.themeId)" in pipeline
    assert "cfg.wallpaperPath" in pipeline
    assert "ThemeCatalogue.reload()" in launcher


def test_color_only_theme_preview_preserves_the_current_wallpaper():
    launcher = (ROOT / "modules" / "launcher" / "services" / "Themes.qml").read_text()
    pane = (ROOT / "modules" / "controlcenter" / "appearance" / "AppearancePane.qml").read_text()
    section = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "ThemesSection.qml").read_text()
    preview = pane.split("function startThemePreview(modelData: var, resolvedWallpaper: string): void", 1)[1].split(
        "function clearPreviewFor", 1
    )[0]

    assert "readonly property bool colorOnly: modelData.colorOnly === true" in launcher
    assert 'previewWallpaperPath = resolvedWallpaper || Wallpapers.actualCurrent || "";' in preview
    assert "!Themes.hasAvailableWallpaper(modelData)" in preview
    assert "previewing with your current wallpaper" in preview
    theme_preview_path = launcher.split("function previewPathFor(theme: var): string", 1)[1].split(
        "function palettePreviewPathFor", 1
    )[0]
    palette_preview_path = launcher.split("function palettePreviewPathFor", 1)[1].split(
        "list: themes.instances", 1
    )[0]
    assert "if (defaultWallpaper && wallpaperPaths[defaultWallpaper])" in palette_preview_path
    assert "if (wallpaperPaths[wallpaper])" in palette_preview_path
    assert "if (useCurrentFallback)" in palette_preview_path
    assert 'return Wallpapers.actualCurrent || "";' in palette_preview_path
    assert 'return palettePreviewPathFor(theme, true) || theme.preview || "";' in theme_preview_path
    assert "startThemePreview(themeItem.modelData, Themes.palettePreviewPathFor(themeItem.modelData, true))" in section
    assert "startThemePreview(theme, Themes.palettePreviewPathFor(theme, true))" in pane


def test_recipe_without_wallpaper_uses_the_current_wallpaper_when_applying():
    pane = (ROOT / "modules" / "controlcenter" / "appearance" / "AppearancePane.qml").read_text()
    section = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "ThemesSection.qml").read_text()
    launcher = (ROOT / "modules" / "launcher" / "services" / "Themes.qml").read_text()

    assert "function wallpaperOverrideFor(theme: var): string" in launcher
    assert "function hasAvailableWallpaper(theme: var): bool" in launcher
    assert 'return Wallpapers.actualCurrent || "";' in launcher
    assert 'stagedThemeWallpaper = Themes.wallpaperOverrideFor(theme);' in pane
    assert 'ThemePipeline.applyTheme(id, Themes.wallpaperOverrideFor(modelData));' in launcher
    assert "&& !Wallpapers.actualCurrent" in section
    assert "Choose a wallpaper in Appearance → Background before applying this theme." in section
    assert "disabled: themeItem.missingWallpaper || themeItem.missingCurrentWallpaper" in section


def test_appearance_shares_installed_styles_for_theme_readiness():
    catalogue = (ROOT / "services" / "ThemeCatalogue.qml").read_text()
    themes = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "ThemesSection.qml").read_text()
    gtk = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "GtkThemeSection.qml").read_text()
    icons = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "IconThemeSection.qml").read_text()

    assert "function loadAppearanceChoices(): void" in catalogue
    assert '"appearance", "gtk", "list"' in catalogue
    assert '"appearance", "gtk", "icons"' in catalogue
    assert "ThemeCatalogue.loadAppearanceChoices()" in themes
    assert "ThemeCatalogue.gtkThemes.indexOf(modelData.gtkTheme) < 0" in themes
    assert "ThemeCatalogue.iconThemes.indexOf(modelData.iconTheme) < 0" in themes
    assert "ThemeCatalogue.gtkThemes" in gtk and "Process {" not in gtk
    assert "ThemeCatalogue.iconThemes" in icons and "Process {" not in icons
    assert "try an available fallback" in themes


def test_appearance_choice_catalogues_can_start_before_they_are_loaded():
    catalogue = (ROOT / "services" / "ThemeCatalogue.qml").read_text()
    loader = catalogue.split("function loadAppearanceChoices(): void", 1)[1].split(
        "function _finishAppearanceChoices", 1
    )[0]

    # The view-level loading property is true before the first request, so it
    # must not be used as the process-start guard.
    assert "if (gtkListProc.running || iconListProc.running)" in loader
    assert "if (appearanceChoicesLoaded && !appearanceChoicesFailed)" in loader
    assert "gtkListProc.running = true;" in loader
    assert "iconListProc.running = true;" in loader
    assert "if (appearanceChoicesLoading" not in loader


def test_theme_cards_distinguish_unverified_gtk_and_icon_dependencies():
    themes = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "ThemesSection.qml").read_text()
    gtk = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "GtkThemeSection.qml").read_text()
    icons = (ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "IconThemeSection.qml").read_text()

    assert "readonly property bool gtkAvailabilityUnknown: ThemeCatalogue.gtkThemesFailed" in themes
    assert "readonly property bool iconAvailabilityUnknown: ThemeCatalogue.iconThemesFailed" in themes
    assert "Couldn't verify GTK and icon styles" in themes
    assert "ThemeCatalogue.loadAppearanceChoices()" in gtk
    assert "ThemeCatalogue.loadAppearanceChoices()" in icons
    assert "Checking installed GTK styles…" in gtk
    assert "Checking installed icon styles…" in icons
    assert "!ThemeCatalogue.appearanceChoicesLoading" in gtk
    assert "!ThemeCatalogue.appearanceChoicesLoading" in icons


def test_native_analyser_layer_present():
    layer = ROOT / "services" / "WallpaperAnalysis.qml"
    assert layer.exists(), "services/WallpaperAnalysis.qml native layer missing"
    text = layer.read_text()
    assert "ImageAnalyser" in text, "WallpaperAnalysis must wrap ImageAnalyser"
    assert "dominantColour" in text, "WallpaperAnalysis must expose dominantColour"
    assert "luminance" in text, "WallpaperAnalysis must expose luminance"
    colours = (ROOT / "services" / "Colours.qml").read_text()
    assert "wallDominantColour" in colours, "Colours must expose native dominant colour"
    assert "wallLuminance" in colours, "Colours must keep native luminance"
    pane = (ROOT / "modules" / "controlcenter" / "appearance" / "AppearancePane.qml").read_text()
    assert "previewAnalyser" in pane, "AppearancePane must analyse previews natively"


def test_dynamic_appearance_cannot_claim_a_catalogue_theme():
    colours = (ROOT / "services" / "Colours.qml").read_text()
    themes = (ROOT / "modules/controlcenter/appearance/sections/ThemesSection.qml").read_text()
    pane = (ROOT / "modules/controlcenter/appearance/AppearancePane.qml").read_text()

    assert 'scheme.name === "dynamic" ? ""' in colours
    assert "themeStateReady && !!Colours.themeId" in themes
    assert "savedThemeMissing" in themes
    assert 'Colours.scheme === "dynamic" ? qsTr("Following your wallpaper")' in themes
    assert 'previewSource = "current"' in pane
    assert 'previewTitle = Colours.scheme === "dynamic" ? qsTr("Following your wallpaper")' in pane
    assert 'if (previewActive && previewSource !== "current")' in pane
    assert "if (!root.themeStateReady)" in colours
