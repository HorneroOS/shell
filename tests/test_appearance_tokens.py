"""Hornero Signal appearance tokens (RFC 0001 §3).

Covers the built-in role tables in services/Signal.qml and their native
apply path in services/ThemePipeline.qml, the factory default theme key
(config/AppearanceConfig.qml + Config.qml + config/shell.default.json), the
always-listed built-ins in the theme registry, the one-shot legacy
migration, typography/geometry/motion tokens and the audited
contrast/hover/focus/disabled/selection states of the shared controls.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from signal_tokens import BUILT_INS, ROOT, SIGNAL, built_in_themes, luminance  # noqa: E402

PIPELINE = ROOT / "services" / "ThemePipeline.qml"
APPEARANCE_CONFIG = ROOT / "config" / "AppearanceConfig.qml"
CONFIG_QML = ROOT / "config" / "Config.qml"
FACTORY = ROOT / "config" / "shell.default.json"
THEME_CATALOGUE = ROOT / "services" / "ThemeCatalogue.qml"


def test_mode_coherence_no_leakage():
    themes = built_in_themes()
    night = themes["hornero-signal-night"]
    day = themes["hornero-signal-day"]
    assert night["mode"] == "dark" and day["mode"] == "light"
    for role in ("ground", "sunken", "base", "panel", "raised", "lifted"):
        assert luminance(night["palette"][role]) < 0.05, role
        assert luminance(day["palette"][role]) > 0.5, role
    # Elevation increases from base to lifted in both modes.
    order = ("base", "panel", "raised", "lifted")
    for theme in (night, day):
        lums = [luminance(theme["palette"][r]) for r in order]
        assert lums == sorted(lums), theme["id"]


def test_signal_apply_path_sets_mode_and_theme():
    text = SIGNAL.read_text()
    assert 'readonly property string defaultThemeId: "hornero-signal-night"' in text
    assert "function isBuiltInTheme(id: string): bool" in text
    assert "function applyScheme(scheme: var): bool" in text
    body = text[text.index("function applyScheme"):text.index("function applyBuiltInTheme")]
    assert "themeMode = scheme.mode" in body, "apply must drive the mode (no leakage)"
    assert "themeId = scheme.id" in body
    assert "isCompletePalette(scheme.palette)" in body, "partial schemes are rejected"
    load = text[text.index("function load("):text.index("function load(") + 600]
    assert "scheme.schemaVersion === 2" in load


def test_live_scheme_path_is_the_contract():
    paths = (ROOT / "utils" / "Paths.qml").read_text()
    assert "readonly property string signalScheme: `${state}/signal/scheme.json`" in paths
    text = SIGNAL.read_text()
    assert "path: root.schemePath" in text and "watchChanges: true" in text
    assert '"schemaVersion": 2' in text
    # Atomic write: temp file + mv, payload passed through the environment.
    assert 'mv -f "$tmp" "$HORNERO_SIGNAL_SCHEME"' in text
    assert '"HORNERO_SIGNAL_PAYLOAD": writeSchemeProc.payload' in text


def test_pipeline_applies_builtins_natively_without_wallpaper_synthesis():
    text = PIPELINE.read_text()
    apply = text[text.index("function applyTheme("):text.index("function applyThemeFromIpc(")]
    assert "Signal.isBuiltInTheme(id)" in apply
    assert apply.index("Signal.isBuiltInTheme(id)") < apply.index("applyThemeCliProc.running = true")
    native = text[text.index("function _applyTheme("):text.index("function _continueThemeApply(")]
    assert "Signal.applyScheme(scheme)" in native
    assert "Signal.persistScheme(scheme)" in native
    for gone in ("colors\", \"m3", "scheme\", \"regenerate", "schemeType", "--scheme-type"):
        assert gone not in text, gone
    marker = '} else if (job.kind === "wallpaper") {'
    wallpaper = text[text.index(marker) + len(marker):]
    wallpaper = wallpaper[:wallpaper.index("} else if")]
    assert "writeWallpaperPointer.running = true" in wallpaper
    assert "Signal" not in wallpaper, "wallpaper changes never recolour the UI"


def test_catalogue_themes_need_a_complete_palette():
    text = PIPELINE.read_text()
    scheme_for = text[text.index("function schemeFor("):text.index("function _pump(")]
    assert "Signal.isCompletePalette(cfg.palette)" in scheme_for
    catalogue = THEME_CATALOGUE.read_text()
    assert "Signal.isCompletePalette(item.palette)" in catalogue


def test_factory_theme_key_end_to_end():
    assert 'property string theme: "hornero-signal-night"' in APPEARANCE_CONFIG.read_text()
    assert "theme: appearance.theme" in CONFIG_QML.read_text(), (
        "serializeAppearance must persist the theme key")
    factory = json.loads(FACTORY.read_text())
    assert factory["appearance"]["theme"] == "hornero-signal-night"
    assert factory["appearance"]["reducedMotion"] is False
    assert factory["appearance"]["font"]["family"] == {
        "sans": "IBM Plex Sans", "mono": "IBM Plex Mono", "display": "IBM Plex Sans Condensed"}
    assert "curves" not in factory["appearance"]["anim"]


def test_registry_lists_builtins_first():
    text = THEME_CATALOGUE.read_text()
    assert "function _withBuiltIns(items: var)" in text
    positions = [text.index(f'id: "{theme_id}"') for theme_id in BUILT_INS]
    assert positions == sorted(positions), "night, day, contrast order"
    assert "root.themes = root._withBuiltIns(JSON.parse(text))" in text, (
        "CLI results must merge over built-ins, never replace them")
    assert "root.themes = root._withBuiltIns([])" in text, (
        "built-ins must survive an empty/failed registry")


def test_one_shot_legacy_migration():
    text = CONFIG_QML.read_text()
    migrate = text[text.index("function migrateLegacyAppearance()"):]
    migrate = migrate[:migrate.index("\n    }\n")]
    for old, new in (("hornero-dark", "hornero-signal-night"),
                     ("hornero-light", "hornero-signal-day"),
                     ("hornero-199x", "hornero-signal-night"),
                     ("Rubik", "IBM Plex Sans"),
                     ("CaskaydiaCove NF", "IBM Plex Mono")):
        assert f'"{old}": "{new}"' in text, old
    assert "Glyphs.has(" in migrate, "persisted non-glyph icon names fall back"
    loaded = text[text.index("onLoaded: {"):]
    assert loaded.index("root.migrateLegacyAppearance()") < loaded.index("root.loaded = true")


def test_typography_tokens():
    text = APPEARANCE_CONFIG.read_text()
    assert 'property string sans: "IBM Plex Sans"' in text
    assert 'property string mono: "IBM Plex Mono"' in text
    assert 'property string display: "IBM Plex Sans Condensed"' in text
    for name, size in (("small", 11), ("smaller", 12), ("normal", 13), ("larger", 15),
                       ("large", 18), ("extraLarge", 28), ("display", 56)):
        assert f"property int {name}: {size} * scale" in text, name


def test_geometry_tokens_on_four_px_grid():
    text = APPEARANCE_CONFIG.read_text()

    def block(name):
        return text[text.index(f"component {name}: JsonObject {{"):].split("\n    }", 1)[0]

    assert re.findall(r"property int (\w+): (\d+) \* scale", block("Rounding")) == [
        ("small", "3"), ("normal", "5"), ("large", "8"), ("full", "1000")]
    assert re.findall(r"property int (\w+): (\d+) \* scale", block("Spacing")) == [
        ("small", "4"), ("smaller", "8"), ("normal", "12"), ("larger", "16"), ("large", "24")]
    assert re.findall(r"property int (\w+): (\d+) \* scale", block("Padding")) == [
        ("small", "4"), ("smaller", "6"), ("normal", "8"), ("larger", "12"), ("large", "16")]


def test_motion_tokens():
    text = (ROOT / "config" / "Appearance.qml").read_text()
    curves = dict((k, v) for k, v in re.findall(r"property list<real> (\w+): \[([^\]]+)\]", text))
    assert curves == {
        "standard": "0.2, 0, 0, 1, 1, 1",
        "enter": "0.05, 0.7, 0.1, 1, 1, 1",
        "exit": "0.3, 0, 1, 1, 1, 1",
        "sweep": "0.65, 0, 0.35, 1, 1, 1",
        # Factory "smooth" spatial curves; snappy reuses `standard`, lively
        # (spring, <= 6 % overshoot) has its own.
        "settleSmooth": "0.32, 1.24, 0.42, 1, 1, 1",
        "settleFastSmooth": "0.34, 1.3, 0.5, 1, 1, 1",
        "settleLively": "0.3, 1.4, 0.4, 1, 1, 1",
        "settleFastLively": "0.34, 1.42, 0.5, 1, 1, 1",
    }
    for name, ms in (("quick", 90), ("short", 160), ("medium", 240), ("long", 360),
                     ("scan", 480), ("settleFast", 220), ("settle", 320)):
        assert f'"{name}": Math.round({ms} * motion._k)' in text, name
    # Experience motion level (§11.3): full/standard share timings,
    # reduced halves them, off (or reduced motion) zeroes them.
    assert 'readonly property real _k: reduced ? 0 : effectiveLevel === "reduced" ? _scale * 0.5 : _scale' in text
    assert '"fade": motion.reduced ? 90 : Math.round(90 * motion._scale)' in text
    assert '(Config.appearance.reducedMotion || SystemMotion.reduced) ? "off"' in text
    assert 'readonly property bool reduced: effectiveLevel === "off"' in text
    # Curves/durations are tokens, never persisted knobs.
    config = APPEARANCE_CONFIG.read_text()
    assert "list<real>" not in config and "property real scale: 1" in config


def test_no_retired_motion_names_in_code():
    retired = re.compile(r"anim\.(curves|durations)\.(emphasized\w*|standardAccel|standardDecel|"
                         r"expressive\w*|small|normal|large|extraLarge)\b")
    hits = []
    for d in ("components", "config", "modules", "plugin/qml", "services", "utils"):
        for path in (ROOT / d).rglob("*.qml"):
            for m in retired.finditer(path.read_text(errors="ignore")):
                hits.append(f"{path.relative_to(ROOT)}: {m.group(0)}")
    assert not hits, hits


def _control(name):
    return (ROOT / "components" / "controls" / name).read_text()


def test_text_selection_states_use_tokens():
    text = _control("StyledTextField.qml")
    assert "selectionColor: Signal.palette.signal" in text
    assert "selectedTextColor: Signal.palette.onSignal" in text
    assert "Qt.alpha(Signal.palette.ink, 0.38)" in text, (
        "disabled text must use the 38% ink token")


def test_search_focus_and_disabled_states():
    text = _control("SearchBar.qml")
    assert "root.activeFocus ? Signal.palette.signal" in text, (
        "search needs a visible focus boundary")
    assert "opacity: root.enabled ? 1 : 0.5" in text


def test_disabled_states_use_token_dimming():
    for name in ("StyledSwitch.qml", "StyledSlider.qml",
                 "StyledRadioButton.qml", "FilledSlider.qml"):
        assert "root.enabled ? 1 : 0.5" in _control(name), (
            f"{name} must dim when disabled")
    for name in ("ButtonBase.qml", "TextButton.qml", "ToggleButton.qml"):
        text = _control(name)
        assert "property bool disabled" in text, f"{name} needs a disabled prop"
        assert "disabled: root.disabled" in text, (
            f"{name} must wire disabled into its StateLayer (no hover when off)")
        assert "opacity: root.disabled ? 0.5 : 1" in text


def test_state_colours_stay_on_tokens():
    # Hover/focus/disabled/selection colours must resolve through the token
    # model so every built-in stays coherent; no literal hex in controls.
    offenders = []
    for path in (ROOT / "components" / "controls").glob("*.qml"):
        for i, line in enumerate(path.read_text().splitlines(), 1):
            if re.search(r"#[0-9a-fA-F]{3,8}", line):
                offenders.append(f"{path.name}:{i}:{line.strip()}")
    assert not offenders, f"literal colours in controls: {offenders}"
