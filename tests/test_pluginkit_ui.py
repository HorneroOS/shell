"""PluginKit 3 (Hornero Signal) component contract.

Static checks pin the public API and the Signal Bezel rules (roles only,
no Material names, no ripple/pill shapes, real-data instruments); the
offscreen runtime probes run the REAL Theme and Ui* files over stub shell
modules (tests/pluginkit_harness.py) for keyboard operation, reduced
motion and the instrument specimen.
"""

import re
from pathlib import Path

import pytest

import pluginkit_harness as harness

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "plugin/qml/Hornero/PluginKit"

UI_TYPES = [
    "UiText", "UiEyebrow", "UiIcon", "UiCard", "UiWell", "UiButton", "UiToggle",
    "UiSlider", "UiTextField", "UiTextArea", "UiSpinBox", "UiComboBox", "UiMetric", "UiDetailRow", "UiActionRow", "UiChip",
    "UiProgress", "UiSegmentMeter", "UiMeterRow", "UiSparkline", "UiScope",
    "UiPartition", "UiState", "UiTooltip", "UiPopover", "UiStack",
]
INTERACTIVE = ["UiButton", "UiToggle", "UiSlider", "UiActionRow", "UiTextField", "UiTextArea",
               "UiSpinBox", "UiComboBox"]
ALLOWED_IMPORTS = {"QtQuick", "QtQuick.Controls", "QtQuick.Layouts", "QtQuick.Shapes",
                   "QtQuick.Effects", "qs.utils"}
HEX_COLOR = re.compile(r"#[0-9a-fA-F]{3,8}\b")
IMPORT_RE = re.compile(r"^\s*import\s+([A-Za-z0-9_.]+)", re.MULTILINE)
MATERIAL_THEME = re.compile(
    r"\bTheme\.(primary|onPrimary|surface\w*|onSurface\w*|secondary\w*|tertiary\w*|"
    r"error\w*|outline\w*|background|componentBorder|success|focusRing|fontFamily|"
    r"fontSize\w*|iconSize\w*|spacingSmall|spacingLarge|roundingSmall|duration[A-Z]\w*|"
    r"curve[A-Z]\w*|state\w*Opacity)\b")


def _src(name: str) -> str:
    return (KIT / f"{name}.qml").read_text(encoding="utf-8")


def _code(name: str) -> str:
    """Source without // comments (comments may name retired APIs)."""
    return re.sub(r"//[^\n]*", "", _src(name))


def test_qmldir_declares_all_ui_types():
    qmldir = (KIT / "qmldir").read_text(encoding="utf-8")
    assert "module Hornero.PluginKit" in qmldir
    for name in UI_TYPES:
        assert f"{name} 1.0 {name}.qml" in qmldir, name
        assert (KIT / f"{name}.qml").is_file(), name
    # Retired Material-era files stay gone.
    for retired in ("UiStateLayer", "ThemeBase"):
        assert not (KIT / f"{retired}.qml").exists(), retired
        assert retired not in qmldir, retired


def test_ui_files_import_only_allowed_modules():
    for name in UI_TYPES:
        imports = IMPORT_RE.findall(_src(name))
        assert imports, name
        for imported in imports:
            assert imported in ALLOWED_IMPORTS, (name, imported)


def test_ui_files_use_signal_roles_only():
    for name in UI_TYPES:
        src = _code(name)
        assert not HEX_COLOR.search(src), name
        assert "Theme." in src, name
        assert not MATERIAL_THEME.search(src), (name, MATERIAL_THEME.search(src))


def test_theme_exposes_signal_tokens():
    src = _src("Theme")
    for token in ("readonly property var palette: Signal.palette",
                  "readonly property var font: Appearance.font",
                  "readonly property var rounding: Appearance.rounding",
                  "readonly property var spacing: Appearance.spacing",
                  "readonly property var padding: Appearance.padding",
                  "readonly property var anim: Appearance.anim",
                  "readonly property bool highContrast: Config.appearance.highContrast",
                  "readonly property bool keyboardFocus: FocusMode.keyboard",
                  "function duration(name: string): int"):
        assert token in src, token
    # Experience-driven motion level, glow gate and telemetry cadence.
    # Mode, motion, glow, density and cadence come from the shell's
    # Experience service (one owner), never re-derived in PluginKit.
    assert "readonly property string experience: ExperienceBridge.mode" in src
    assert "readonly property string motionLevel: Appearance.anim.effectiveLevel" in src
    assert "readonly property bool glowEnabled: ExperienceBridge.glow" in src
    assert "readonly property bool scanlines: ExperienceBridge.scanlines" in src
    assert "readonly property int telemetryIntervalMs: ExperienceBridge.telemetryIntervalMs" in src
    assert "readonly property real glowBlur: 4" in src
    assert "readonly property real glowAlpha: 0.4" in src
    bridge = _src("ExperienceBridge")
    for token in ("Experience.mode", "Experience.glow", "Experience.scanlines",
                  "Experience.telemetryIntervalMs", "Experience.density"):
        assert token in bridge, token
    # No Material aliases and no on*-beside-base trap: roles live on palette.
    assert not re.search(r"property\s+color\s+", src)


def test_interactive_ui_types_declare_accessible_name_and_focus():
    for name in INTERACTIVE:
        src = _src(name)
        assert "Accessible.name" in src, name
        assert "activeFocus" in src, name
        assert "activeFocusOnTab: enabled" in src, name
        assert "Theme.palette.focus" in src, name
        assert "Theme.keyboardFocus" in src, name


def test_no_ripple_scale_or_pill_shapes():
    for name in UI_TYPES:
        src = _code(name)
        assert "UiStateLayer" not in src and "ripple" not in src.lower(), name
        assert "radius: height / 2" not in src, name
        assert "radius: width / 2" not in src, name
        assert "scale:" not in src, name
        assert "Animation.Infinite" not in src, name


def test_uibutton_contract():
    src = _src("UiButton")
    assert 'property string variant: "secondary"' in src
    for variant in ("primary", "secondary", "quiet", "danger"):
        assert f'"{variant}"' in src, variant
    assert 'property string glyph: ""' in src and "property bool open" in src
    assert "iconName" not in src
    assert "Theme.palette.onSignal" in src and "Theme.palette.signal" in src
    # Rest → hover raised → pressed lifted; open = raised + signal underline.
    assert "Theme.palette.lifted" in src and "Theme.palette.raised" in src
    assert "radius: Theme.rounding.small" in src
    # Bar rails: quiet segment, narrow-rail fit, island styling.
    assert 'root.inBar ? "quiet"' in src
    assert "Text.Fit" in src and "Math.min(root.railWidth" in src
    assert "islandColoured" in src and "hostIconColor.a > 0" in src
    assert "Keys.onReturnPressed" in src and "Keys.onEnterPressed" in src


def test_text_roles_and_tabular_figures():
    src = _src("UiText")
    for role in ("body", "caption", "subtitle", "title", "eyebrow", "value", "readout", "display"):
        assert f'"{role}"' in src, role
    assert '"tnum": 1' in src
    assert "Font.AllUppercase" in src and "0.08" in src
    assert "Theme.font.family.mono" in src and "Theme.font.family.display" in src


def test_icon_takes_glyph_names_without_fill_axis():
    icon = _code("UiIcon")
    assert 'property string name: ""' in icon
    assert "Glyphs.glyph(root.name)" in icon
    assert "fill" not in icon.lower()
    for name in ("UiButton", "UiChip", "UiCard", "UiDetailRow"):
        assert 'property string glyph: ""' in _src(name), name
    action = _src("UiActionRow")
    assert 'property string glyph: ""' in action and 'property string trailingGlyph: ""' in action


def test_toggle_is_a_rocker():
    src = _src("UiToggle")
    assert "property bool value" in src and "signal toggled" not in src
    assert "root.value = checked" in src and "checked = root.value" in src
    assert "Theme.palette.signalWell" in src and "Theme.palette.sunken" in src
    assert "Theme.anim.curves.settleFast" in src


def test_slider_is_a_fader():
    src = _src("UiSlider")
    assert 'property string accessibleName: "Slider"' in src
    assert "stepSize: (to - from) / 20" in src
    for key in ("Qt.Key_Home", "Qt.Key_End", "Qt.Key_PageUp", "Qt.Key_PageDown"):
        assert key in src, key
    assert "implicitWidth: 6" in src and "implicitHeight: 16" in src


def test_chip_tones_and_on_air():
    src = _src("UiChip")
    for tone in ("neutral", "signal", "cue", "phosphor", "alert", "live"):
        assert f'"{tone}"' in src, tone
    assert "radius: Theme.rounding.small" in src
    assert "Theme.palette.onSignal" in src


def test_progress_never_pulses():
    src = _src("UiProgress")
    assert "indeterminate" in src and "SequentialAnimation" not in src and "Timer" not in src


def test_card_is_an_instrument_module():
    src = _src("UiCard")
    assert "Theme.palette.panel" in src and "Theme.palette.rule" in src
    assert "UiEyebrow" in src and "property int channel" in src
    assert 'p.hostSurface === "dashboard" || p.hostSurface === "desktop"' in src
    # Registration tick: 2 × 10 signal on focus, not a glow.
    assert "width: 2" in src and "height: 10" in src


def test_instruments_follow_the_real_data_rule():
    meter = _src("UiSegmentMeter")
    assert "property bool available: true" in meter
    assert "root.available && isFinite(root.value)" in meter
    assert "Theme.palette.rule" in meter and "Theme.palette.phosphor" in meter
    scope = _src("UiScope")
    assert "property bool available: true" in scope
    assert "opacity: 0.22" in scope  # persistence
    assert "Theme.scanlines" in scope and "Theme.glowEnabled" in scope
    assert "GlowBudget.acquire(root)" in scope
    assert '"—"' in scope
    for name in ("UiMetric", "UiDetailRow", "UiMeterRow"):
        assert '"—"' in _src(name), name
    spark = _src("UiSparkline")
    assert "n < 2" in spark  # fewer than two real samples draws nothing


def test_glow_budget_rations_three_items():
    src = _src("GlowBudget")
    assert "readonly property int limit: 3" in src
    for name in ("UiScope", "UiSparkline"):
        body = _src(name)
        assert "layer.enabled: root.glowing" in body, name
        assert "shadowOpacity: Theme.glowAlpha" in body and "blurMax: Theme.glowBlur" in body, name


def test_popover_and_tooltip_use_signal_motion():
    popover = _src("UiPopover")
    assert "Theme.anim.curves.enter" in popover and "Theme.anim.curves.exit" in popover
    assert 'Theme.duration("short")' in popover and 'Theme.duration("quick")' in popover
    assert "from: Theme.reducedMotion ? 0 : 6" in popover  # 6 px scan-in travel
    assert "id: notch" in popover and "Theme.palette.signal" in popover
    assert "Theme.palette.panel" in popover
    tooltip = _src("UiTooltip")
    assert 'Theme.duration("fade")' in tooltip
    assert "Theme.palette.lifted" in tooltip and "Theme.palette.ruleStrong" in tooltip


def test_reference_examples_are_keyboard_operable():
    examples = ROOT / "examples" / "plugins"
    for main in sorted(examples.glob("*/Main.qml")):
        src = main.read_text(encoding="utf-8")
        if "onClicked" not in src:
            continue
        assert "MouseArea {" not in src, f"{main}: mouse-only action; use a PluginKit control"
        assert "UiButton" in src, main


SHELL_SINGLETONS = {
    "Signal": "qs.services",
    "Glyphs": "qs.utils",
    "Appearance": "qs.config",
    "Config": "qs.config",
}


def test_pluginkit_files_import_the_module_defining_each_shell_singleton():
    for path in sorted(KIT.glob("*.qml")):
        src = path.read_text(encoding="utf-8")
        imports = set(IMPORT_RE.findall(src))
        for name, module in SHELL_SINGLETONS.items():
            if re.search(rf"(?<![.\w]){name}\.", src):
                assert module in imports, (path.name, name, module)


def test_bar_and_dashboard_hosts_advertise_their_surface():
    bar_host = (ROOT / "modules/plugins/PluginBarWidgets.qml").read_text(encoding="utf-8")
    assert 'readonly property string hostSurface: "bar"' in bar_host
    assert "readonly property int hostAvailableWidth: root.availableWidth" in bar_host
    dash_host = (ROOT / "modules/plugins/PluginDashboardCards.qml").read_text(encoding="utf-8")
    assert 'readonly property string hostSurface: "dashboard"' in dash_host


def _runner_or_skip():
    if harness.qmltestrunner() is None:
        pytest.skip("NOT RUN (offscreen): Qt6 qmltestrunner not available")


def test_keyboard_only_operation_offscreen(tmp_path):
    """Runtime probe (#376) with the real Theme: tab order, Enter/Space,
    slider keys, popover focus restore, reduced-motion inheritance.
    QML-level evidence only — no compositor grab or AT-SPI claim."""
    _runner_or_skip()
    harness.build(tmp_path)
    result = harness.run(ROOT / "tests/qa/tst_pluginkit_keyboard.qml", tmp_path)
    out = result.stdout + result.stderr
    assert "PluginKitKeyboard" in out, out
    assert ", 0 failed" in out, out
    assert result.returncode == 0, out


@pytest.mark.parametrize("experience,light", [("everyday", False), ("signal", False), ("signal", True)])
def test_specimen_renders_offscreen(tmp_path, experience, light):
    """Every Signal component renders with fixture data; unavailable
    instruments show no value; glow only in the signal experience on dark
    themes. Set SPECIMEN_OUT=<dir> to keep the PNGs for review."""
    import os

    _runner_or_skip()
    harness.build(tmp_path, experience=experience)
    if light:
        signal = tmp_path / "qs/services/Signal.qml"
        signal.write_text(signal.read_text().replace("property bool light: false", "property bool light: true"))
    out_dir = os.environ.get("SPECIMEN_OUT", "")
    out = str(Path(out_dir) / f"pluginkit-{experience}-{'day' if light else 'night'}.png") if out_dir else ""
    fixture = tmp_path / "tst_specimen.qml"
    fixture.write_text((ROOT / "tests/qa/tst_pluginkit_specimen.qml").read_text(encoding="utf-8")
                       .replace('property string specimenPath: ""', f"property string specimenPath: {out!r}".replace("'", '"')),
                       encoding="utf-8")
    result = harness.run(fixture, tmp_path)
    text = result.stdout + result.stderr
    assert "PluginKitSpecimen" in text, text
    assert ", 0 failed" in text, text
    expected_glow = experience == "signal" and not light
    assert f"glow {experience} {str(expected_glow).lower()}" in text, text


def test_pluginkit_colour_js_is_a_byte_copy_of_the_shell_model():
    shell = (ROOT / "services/chromatic.js").read_bytes()
    assert (KIT / "Colour.js").read_bytes() == shell, "re-copy services/chromatic.js to PluginKit/Colour.js"


def test_detail_row_value_elides_instead_of_overprinting_the_label():
    source = (KIT / "UiDetailRow.qml").read_text(encoding="utf-8")
    assert "elide: Text.ElideMiddle" in source
    assert "root.width * 0.6" in source
    assert "root.width - valueItem.width" in source
