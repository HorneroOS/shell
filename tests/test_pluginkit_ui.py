import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "plugin/qml/Hornero/PluginKit"

UI_TYPES = [
    "UiText",
    "UiCard",
    "UiButton",
    "UiToggle",
    "UiSlider",
    "UiMetric",
    "UiChip",
    "UiProgress",
    "UiState",
    "UiTooltip",
    "UiPopover",
]

INTERACTIVE = ["UiButton", "UiToggle", "UiSlider"]

ALLOWED_IMPORTS = {"QtQuick", "QtQuick.Controls"}

HEX_COLOR = re.compile(r"#[0-9a-fA-F]{3,8}\b")
IMPORT_RE = re.compile(r"^\s*import\s+([A-Za-z0-9_.]+)", re.MULTILINE)


def test_qmldir_declares_all_ui_types():
    qmldir = (KIT / "qmldir").read_text(encoding="utf-8")
    assert "module Hornero.PluginKit" in qmldir
    for name in UI_TYPES:
        assert f"{name} 1.0 {name}.qml" in qmldir, name
        assert (KIT / f"{name}.qml").is_file(), name


def test_ui_files_import_only_allowed_modules():
    for name in UI_TYPES:
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        imports = IMPORT_RE.findall(src)
        assert imports, name
        for imported in imports:
            assert imported in ALLOWED_IMPORTS, (name, imported)
        assert "qs." not in src, name
        assert "import qs" not in src, name


def test_ui_files_have_no_hex_colors_and_use_theme():
    for name in UI_TYPES:
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        assert not HEX_COLOR.search(src), name
        assert "Theme." in src, name


def test_interactive_ui_types_declare_accessible_name_and_focus():
    for name in INTERACTIVE:
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        assert "Accessible.name" in src, name
        assert "activeFocus" in src, name


def test_uibutton_contract():
    src = (KIT / "UiButton.qml").read_text(encoding="utf-8")
    assert 'property string variant: "primary"' in src
    assert '"ghost"' in src
    assert "property string tooltipText" in src
    # Host-owned UiTooltip (#370) replaces the raw Controls ToolTip.
    assert "UiTooltip" in src
    assert "text: root.tooltipText" in src
    # Primary variant background is Theme.primary, so its focus border
    # must use the contrasting onPrimary token (ghost keeps primary).
    assert 'root.variant === "ghost" ? Theme.primary : Theme.onPrimary' in src


def test_uitext_roles():
    src = (KIT / "UiText.qml").read_text(encoding="utf-8")
    for role in ("title", "body", "caption"):
        assert f'"{role}"' in src
    assert "property string role" in src


def test_uitoggle_contract():
    src = (KIT / "UiToggle.qml").read_text(encoding="utf-8")
    assert "property bool value" in src
    # toggled() is inherited from Switch/AbstractButton; redeclaring it
    # shadows the base signal and desyncs value/checked.
    assert "signal toggled" not in src
    assert "onCheckedChanged" in src
    assert "onValueChanged" in src
    assert "root.value = checked" in src
    assert "checked = root.value" in src
    # Checked track is Theme.primary, so its focus border must contrast.
    assert "root.checked ? Theme.onPrimary : Theme.primary" in src


def test_uislider_contract():
    src = (KIT / "UiSlider.qml").read_text(encoding="utf-8")
    assert src.lstrip().splitlines()[2].startswith("Slider") or "Slider {" in src
    assert 'property string accessibleName: "Slider"' in src


def test_uimetric_contract():
    src = (KIT / "UiMetric.qml").read_text(encoding="utf-8")
    assert "property string label" in src
    assert "property string value" in src
    assert "property string unit" in src


def test_uichip_contract():
    src = (KIT / "UiChip.qml").read_text(encoding="utf-8")
    assert "property string text" in src
    assert "property string tone" in src
    for tone in ("neutral", "primary", "error"):
        assert f'"{tone}"' in src


def test_uiprogress_contract():
    src = (KIT / "UiProgress.qml").read_text(encoding="utf-8")
    assert "from: 0" in src
    assert "to: 1" in src
    assert "indeterminate" in src
    assert "property bool animated: false" in src
    assert "Animation.Infinite" in src
    assert "Timer" not in src


def test_uistate_contract():
    src = (KIT / "UiState.qml").read_text(encoding="utf-8")
    assert "property string kind" in src
    assert "property string message" in src
    for kind in ("loading", "error", "empty"):
        assert f'"{kind}"' in src


def test_uicard_contract():
    src = (KIT / "UiCard.qml").read_text(encoding="utf-8")
    assert "Theme.surfaceContainer" in src
    assert "Theme.rounding" in src
    assert "property int padding" in src


def test_no_infinite_animation_unless_animated():
    for name in UI_TYPES:
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        if "Animation.Infinite" in src:
            assert name == "UiProgress", name
            assert "animated" in src, name


# --- Accessibility + keyboard/focus contract (#376) -----------------
# Names/roles already asserted above; these pin the enforceable
# keyboard half: deterministic tab stops, Enter/Space activation,
# slider arrow/Home/End/Page semantics, visible focus stays on the
# control (activeFocus borders asserted above), and host reduced
# motion / high contrast inheritance through Theme.

def test_interactive_controls_are_single_tab_stops_while_enabled():
    for name in INTERACTIVE:
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        assert "activeFocusOnTab: enabled" in src, name


def test_button_and_toggle_activate_on_enter_and_return():
    # Space is native to Button/Switch; Enter/Return are not, so the
    # contract adds them explicitly (offscreen probe proves firing).
    for name in ("UiButton", "UiToggle"):
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        assert "Keys.onReturnPressed" in src, name
        assert "Keys.onEnterPressed" in src, name
        assert "root.click()" in src, name
        assert "event.accepted = true" in src, name


def test_slider_keyboard_steps_scale_with_range():
    src = (KIT / "UiSlider.qml").read_text(encoding="utf-8")
    assert "stepSize: (to - from) / 20" in src
    for key in ("Qt.Key_Home", "Qt.Key_End", "Qt.Key_PageUp", "Qt.Key_PageDown"):
        assert key in src, key
    assert "root.moved()" in src


def test_theme_exposes_host_accessibility_inheritance():
    src = (KIT / "Theme.qml").read_text(encoding="utf-8")
    assert "readonly property color focusRing: Colours.focusRing" in src
    assert "readonly property bool highContrast: Config.appearance.highContrast" in src
    assert "readonly property real animationScale: Appearance.anim.durations.scale" in src
    assert "readonly property bool reducedMotion: animationScale <= 0" in src
    assert "function motionDuration(ms: int): int" in src


def test_host_reduced_motion_gates_kit_animation():
    progress = (KIT / "UiProgress.qml").read_text(encoding="utf-8")
    assert "root.indeterminate && root.animated && !Theme.reducedMotion" in progress
    for name in ("UiTooltip", "UiPopover"):
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        assert "duration: Theme.motionDuration(120)" in src, name
        assert "duration: 120" not in src.replace(
            "duration: Theme.motionDuration(120)", ""), name


def test_reference_examples_are_keyboard_operable():
    examples = ROOT / "examples" / "plugins"
    for main in sorted(examples.glob("*/Main.qml")):
        src = main.read_text(encoding="utf-8")
        if "onClicked" not in src:
            continue
        assert "MouseArea {" not in src, (
            f"{main}: mouse-only action; use a PluginKit control")
        assert "UiButton" in src, main


_STUB_THEME_BASE = """import QtQuick

QtObject {
    readonly property color onPrimary: "#ffffff"
    readonly property color onSurface: "#eeeeee"
    readonly property color onSurfaceVariant: "#bbbbbb"
    readonly property color onBackground: "#eeeeee"
    readonly property color onPrimaryContainer: "#ddeeff"
    readonly property color onSecondary: "#ffffff"
    readonly property color onSecondaryContainer: "#ddeeff"
    readonly property color onTertiary: "#ffffff"
    readonly property color onTertiaryContainer: "#ffeedd"
    readonly property color onErrorContainer: "#ffdddd"
    readonly property color onError: "#ffffff"
}
"""

_STUB_THEME = """pragma Singleton
import QtQuick

// Offscreen stub mirroring the real Theme property names. The on*
// colors live in ThemeBase because this Qt rejects an on* property
// declared beside its base-name property in one file.
ThemeBase {
    readonly property bool light: false
    readonly property color primary: "#7aa2ff"
    readonly property color surface: "#111111"
    readonly property color surfaceContainer: "#222222"
    readonly property color error: "#ff5555"
    readonly property color background: "#000000"
    readonly property color surfaceDim: "#111111"
    readonly property color surfaceBright: "#333333"
    readonly property color surfaceContainerLowest: "#0a0a0a"
    readonly property color surfaceContainerLow: "#181818"
    readonly property color surfaceContainerHigh: "#2a2a2a"
    readonly property color surfaceContainerHighest: "#383838"
    readonly property color surfaceVariant: "#444444"
    readonly property color primaryContainer: "#334466"
    readonly property color secondary: "#88cc88"
    readonly property color secondaryContainer: "#335533"
    readonly property color tertiary: "#cc88cc"
    readonly property color tertiaryContainer: "#553355"
    readonly property color errorContainer: "#663333"
    readonly property color outline: "#888888"
    readonly property color outlineVariant: "#555555"
    readonly property color success: "#66bb66"
    readonly property string fontFamily: "Sans"
    readonly property string monoFontFamily: "Monospace"
    readonly property int fontSizeSmall: 11
    readonly property int fontSize: 13
    readonly property int fontSizeLarge: 18
    readonly property int spacingSmall: 7
    readonly property int spacing: 12
    readonly property int spacingLarge: 20
    readonly property int roundingSmall: 6
    readonly property int rounding: 10
    readonly property int roundingLarge: 16
    property bool stubReducedMotion: false
    property real stubAnimScale: 1
    readonly property color focusRing: "#ffcc00"
    readonly property bool highContrast: false
    readonly property bool reducedMotion: stubReducedMotion
    readonly property real animationScale: stubAnimScale
    function motionDuration(ms: int): int {
        return reducedMotion ? 0 : Math.round(ms * animationScale);
    }
}
"""

_STUB_QMLDIR = """module Hornero.PluginKit
singleton Theme 1.0 Theme.qml
internal ThemeBase ThemeBase.qml
UiText 1.0 UiText.qml
UiCard 1.0 UiCard.qml
UiButton 1.0 UiButton.qml
UiToggle 1.0 UiToggle.qml
UiSlider 1.0 UiSlider.qml
UiMetric 1.0 UiMetric.qml
UiChip 1.0 UiChip.qml
UiProgress 1.0 UiProgress.qml
UiState 1.0 UiState.qml
UiTooltip 1.0 UiTooltip.qml
UiPopover 1.0 UiPopover.qml
UiStack 1.0 UiStack.qml
"""


def test_keyboard_only_operation_offscreen(tmp_path):
    """Runtime probe (#376): drive the reference fixture keyboard-only
    offscreen (tab order, Enter/Space, slider keys, popover focus
    restore, reduced-motion scaling). QML-level evidence only — no
    compositor grab or AT-SPI claim. Skips without Qt6 qmltestrunner.
    """
    import os
    import shutil
    import subprocess

    import pytest

    runner = Path("/usr/lib/qt6/bin/qmltestrunner")
    if not runner.is_file():
        candidate = shutil.which("qmltestrunner6")
        if not candidate:
            pytest.skip("Qt6 qmltestrunner not available")
        runner = Path(candidate)

    kit = tmp_path / "Hornero" / "PluginKit"
    kit.mkdir(parents=True)
    for name in UI_TYPES + ["UiStack"]:
        shutil.copy(KIT / f"{name}.qml", kit / f"{name}.qml")
    (kit / "ThemeBase.qml").write_text(_STUB_THEME_BASE, encoding="utf-8")
    (kit / "Theme.qml").write_text(_STUB_THEME, encoding="utf-8")
    (kit / "qmldir").write_text(_STUB_QMLDIR, encoding="utf-8")
    fixture = ROOT / "tests" / "qa" / "tst_pluginkit_keyboard.qml"

    env = dict(os.environ, QT_QPA_PLATFORM="offscreen",
               QML2_IMPORT_PATH=str(tmp_path))
    result = subprocess.run(
        [str(runner), "-input", str(fixture)],
        capture_output=True, text=True, env=env, timeout=120)
    out = result.stdout + result.stderr
    assert "PluginKitKeyboard" in out, out
    assert "0 failed" in out, out
    assert result.returncode == 0, out
