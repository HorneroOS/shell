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
    "UiDetailRow",
    "UiActionRow",
    "UiChip",
    "UiProgress",
    "UiState",
    "UiTooltip",
    "UiPopover",
]

INTERACTIVE = ["UiButton", "UiToggle", "UiSlider", "UiActionRow"]

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
    # Primary variant background is Theme.primary, so its label uses the
    # contrasting onPrimary token; ghost keeps primary outside bars.
    assert 'root.variant === "primary" ? Theme.onPrimary' in src
    assert "root.inBar ? Theme.onSurface : Theme.primary" in src


def test_uitext_roles():
    src = (KIT / "UiText.qml").read_text(encoding="utf-8")
    for role in ("title", "subtitle", "body", "caption"):
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
    # Focus border uses Theme.focusRing: it contrasts against the host
    # surface outside the control in both states (onPrimary does not).
    assert "border.color: Theme.focusRing" in src
    assert "visible: root.activeFocus && Theme.keyboardFocus" in src


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
    # Fades take their duration from Theme motion tokens, which are zero
    # under reduced motion (Theme.durationNormal / durationExpressiveFastSpatial).
    gated = {"UiTooltip": "Theme.durationExpressiveFastSpatial", "UiPopover": "Theme.durationNormal"}
    for name, token in gated.items():
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        assert token in src, name
        assert "duration: 120" not in src, name


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
    readonly property int fontSizeBody: 12
    readonly property int fontSizeTitle: 15
    readonly property int fontSizeDisplay: 28
    readonly property string iconFontFamily: "Sans"
    readonly property int iconSize: 15
    readonly property int iconSizeLarge: 18
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
    readonly property int durationSmall: 200
    readonly property int durationNormal: 400
    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveStandardDecel: [0, 0, 0, 1, 1, 1]
    readonly property bool keyboardFocus: true
    readonly property real stateHoverOpacity: 0.08
    readonly property int durationExpressiveFastSpatial: 350
    readonly property var curveExpressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property real statePressedOpacity: 0.12
    function motionDuration(ms: int): int {
        return reducedMotion ? 0 : Math.round(ms * animationScale);
    }
}
"""

_STUB_QMLDIR = """module Hornero.PluginKit
singleton Theme 1.0 Theme.qml
internal ThemeBase ThemeBase.qml
UiText 1.0 UiText.qml
UiIcon 1.0 UiIcon.qml
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
UiStateLayer 1.0 UiStateLayer.qml
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
    for name in UI_TYPES + ["UiStack", "UiStateLayer", "UiIcon"]:
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


# Singletons defined outside the PluginKit module, mapped to the shell
# module that owns them. A PluginKit file referencing one of these must
# import its owning module, or the identifier is undefined at runtime and
# every colour/value silently resolves to undefined (black cards, invisible
# text). Regression for shell#408: Theme.qml used Colours with only
# `import qs.config`, so Colours (services/Colours.qml) was not defined.
SHELL_SINGLETONS = {
    "Colours": "qs.services",
    "Appearance": "qs.config",
    "Config": "qs.config",
}


def test_pluginkit_files_import_the_module_defining_each_shell_singleton():
    for path in sorted(KIT.glob("*.qml")):
        src = path.read_text(encoding="utf-8")
        imports = set(IMPORT_RE.findall(src))
        for name, module in SHELL_SINGLETONS.items():
            if re.search(rf"\b{name}\.", src):
                assert module in imports, (path.name, name, module)


def test_ui_button_fits_narrow_bar_rails():
    """Bar indicators on a thin vertical rail (64 px) clipped at the host
    Loader edge: UiButton must detect the host rail from its ancestors,
    shrink its label to fit (never clip characters) and keep its
    implicit width within the rail. Regression for the bar pills (#410).
    """
    src = (KIT / "UiButton.qml").read_text(encoding="utf-8")
    assert "hostCompact" in src
    assert "hostAvailableWidth" in src
    assert "Text.Fit" in src
    assert "Math.min(root.railWidth" in src
    assert "implicitLeftPadding" in src


def test_state_layer_and_motion_contract_matches_native():
    """Extension controls use the shell's state contract (#419): hover 8%,
    pressed 12%, ripple with standardDecel, keyboard-only focus ring and
    reduced-motion gating. Numbers live in Theme, never in controls.
    """
    theme = (KIT / "Theme.qml").read_text(encoding="utf-8")
    assert "stateHoverOpacity: 0.08" in theme
    assert "statePressedOpacity: 0.12" in theme
    assert "curveStandardDecel" in theme and "curveStandard" in theme
    assert "keyboardFocus: FocusMode.keyboard" in theme
    assert "reducedMotion ? 0" in theme

    layer = (KIT / "UiStateLayer.qml").read_text(encoding="utf-8")
    assert "Theme.stateHoverOpacity" in layer and "Theme.statePressedOpacity" in layer
    assert "Theme.curveStandardDecel" in layer
    assert "Theme.reducedMotion" in layer

    button = (KIT / "UiButton.qml").read_text(encoding="utf-8")
    assert "UiStateLayer" in button and "HoverHandler" in button
    assert "Theme.keyboardFocus" in button
    assert "Theme.focusRing" in button


def test_popover_and_tooltip_fades_use_native_motion_tokens():
    """Native popouts fade over the normal duration (standard curve) and
    native tooltips over expressiveFastSpatial. PluginKit must use the same
    tokens, not hard-coded 120 ms fades scaled twice (#421).
    """
    popover = (KIT / "UiPopover.qml").read_text(encoding="utf-8")
    tooltip = (KIT / "UiTooltip.qml").read_text(encoding="utf-8")
    assert "Theme.durationNormal" in popover and "Theme.curveStandard" in popover
    assert "motionDuration(120)" not in popover
    assert "Theme.durationExpressiveFastSpatial" in tooltip
    assert "Theme.curveExpressiveFastSpatial" in tooltip
    assert "motionDuration(120)" not in tooltip


def test_toggle_thumb_matches_native_switch_motion():
    """Native switch thumb stretches while pressed (x1.3), has 8% hover and
    10% press layers, and animates over the normal duration. Keyboard-only
    focus ring (#419).
    """
    src = (KIT / "UiToggle.qml").read_text(encoding="utf-8")
    assert "HoverHandler" in src
    assert "pressedWidth" in src and "root.down" in src
    assert "opacity: root.down ? 0.1 : hover.hovered ? 0.08 : 0" in src
    assert "Theme.durationNormal" in src and "Theme.curveStandard" in src
    assert "Theme.keyboardFocus" in src


def test_slider_handle_matches_native_handle_motion():
    """Native handle reacts to hover with a state layer and swells while
    dragged (FilledSlider), animating over the half-normal duration. The
    focus ring is keyboard-only (#419 follow-up).
    """
    src = (KIT / "UiSlider.qml").read_text(encoding="utf-8")
    assert "HoverHandler" in src
    assert "UiStateLayer" in src
    assert "root.pressed ? 1.2 : 1" in src
    assert "Theme.durationNormal / 2" in src and "Theme.curveStandardDecel" in src
    assert "Theme.keyboardFocus" in src


def test_theme_declares_no_on_colour_beside_its_base():
    """Qt parses `onX: <expr>` declared beside a property X as the
    X-changed signal handler, so the colour silently reads #000000 (#427).
    Theme.qml must keep every on* colour in ThemeBase.
    """
    theme = (KIT / "Theme.qml").read_text(encoding="utf-8")
    assert not re.search(r"property\s+color\s+on[A-Z]", theme)
    base = (KIT / "ThemeBase.qml").read_text(encoding="utf-8")
    assert "readonly property color onSurface" in base
    assert re.search(r"^ThemeBase \{", theme, re.M)
    assert "internal ThemeBase ThemeBase.qml" in (KIT / "qmldir").read_text(encoding="utf-8")


_PROBE_COLOURS = """pragma Singleton
import QtQuick
QtObject {
    readonly property bool light: false
    readonly property color focusRing: "#ffd166"
    readonly property var palette: ({ m3primary: "#a5baf5", m3onPrimary: "#2a4073", m3surface: "#080e1b",
        m3surfaceContainer: "#11192c", m3onSurface: "#dee5ff", m3onSurfaceVariant: "#a0aacb", m3error: "#ff8a80",
        m3background: "#080e1b", m3onBackground: "#dee5ff", m3surfaceDim: "#080e1b", m3surfaceBright: "#33404d",
        m3surfaceContainerLowest: "#05080b", m3surfaceContainerLow: "#0c1323", m3surfaceContainerHigh: "#1b2833",
        m3surfaceContainerHighest: "#1b253f", m3surfaceVariant: "#1b2833", m3primaryContainer: "#a5baf5",
        m3onPrimaryContainer: "#203769", m3secondary: "#8ed8ff", m3onSecondary: "#07131a",
        m3secondaryContainer: "#8ed8ff", m3onSecondaryContainer: "#07131a", m3tertiary: "#c8a6ff",
        m3onTertiary: "#130c1f", m3tertiaryContainer: "#c8a6ff", m3onTertiaryContainer: "#130c1f",
        m3errorContainer: "#8a1a1e", m3onErrorContainer: "#1a0808", m3onError: "#1a0808", m3outline: "#6b7593",
        m3outlineVariant: "#b8c8d8", m3success: "#a8e6a1" })
}
"""

_PROBE_APPEARANCE = """pragma Singleton
import QtQuick
QtObject {
    readonly property var font: ({ family: { sans: "Sans", mono: "Monospace" }, size: { small: 11, normal: 13, large: 18 } })
    readonly property var spacing: ({ small: 7, normal: 12, large: 20 })
    readonly property var rounding: ({ small: 6, normal: 10, large: 16 })
    readonly property var anim: ({ durations: { scale: 1, small: 200, normal: 400, expressiveFastSpatial: 350 },
        curves: { standard: [0.2, 0, 0, 1, 1, 1], standardDecel: [0, 0, 0, 1, 1, 1], expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1] } })
}
"""

_PROBE_TEST = """import QtQuick
import QtTest
import Hornero.PluginKit
TestCase {
    name: "RealThemeOnColours"
    UiText { id: title; role: "title"; text: "T" }
    UiText { id: caption; role: "caption"; text: "C" }
    function test_on_colours_are_the_palette() {
        compare(String(Theme.onSurface), "#dee5ff");
        compare(String(Theme.onSurfaceVariant), "#a0aacb");
        compare(String(Theme.onPrimary), "#2a4073");
        compare(String(Theme.onPrimaryContainer), "#203769");
        compare(String(title.color), "#dee5ff");
        compare(String(caption.color), "#a0aacb");
    }
}
"""


def test_real_theme_on_colours_resolve_offscreen(tmp_path):
    """Runtime proof with the REAL Theme.qml/ThemeBase.qml/UiText.qml and stub
    qs modules: every on* colour equals the palette, never #000000 (#427).
    """
    import os
    import shutil
    import subprocess

    import pytest

    runner = Path("/usr/lib/qt6/bin/qmltestrunner")
    if not runner.is_file():
        candidate = shutil.which("qmltestrunner6")
        if not candidate:
            pytest.skip("NOT RUN (offscreen): Qt6 qmltestrunner not available")
        runner = Path(candidate)
    services = tmp_path / "qs" / "services"
    config = tmp_path / "qs" / "config"
    kit = tmp_path / "Hornero" / "PluginKit"
    for d in (services, config, kit):
        d.mkdir(parents=True)
    (services / "qmldir").write_text("module qs.services\nsingleton Colours 1.0 Colours.qml\nsingleton FocusMode 1.0 FocusMode.qml\n", encoding="utf-8")
    (services / "Colours.qml").write_text(_PROBE_COLOURS, encoding="utf-8")
    (services / "FocusMode.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { property bool keyboard: false }\n", encoding="utf-8")
    (config / "qmldir").write_text("module qs.config\nsingleton Appearance 1.0 Appearance.qml\nsingleton Config 1.0 Config.qml\n", encoding="utf-8")
    (config / "Appearance.qml").write_text(_PROBE_APPEARANCE, encoding="utf-8")
    (config / "Config.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject { readonly property var appearance: ({ highContrast: false }) }\n", encoding="utf-8")
    for name in ("Theme.qml", "ThemeBase.qml", "UiText.qml"):
        shutil.copy(KIT / name, kit / name)
    (kit / "qmldir").write_text("module Hornero.PluginKit\nsingleton Theme 1.0 Theme.qml\ninternal ThemeBase ThemeBase.qml\nUiText 1.0 UiText.qml\n", encoding="utf-8")
    fixture = tmp_path / "tst_real_theme.qml"
    fixture.write_text(_PROBE_TEST, encoding="utf-8")
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
    result = subprocess.run([str(runner), "-import", str(tmp_path), "-input", str(fixture)],
                            capture_output=True, text=True, env=env, timeout=120)
    out = result.stdout + result.stderr
    assert "RealThemeOnColours" in out, out
    assert ", 0 failed" in out, out
    assert result.returncode == 0, out


def test_buttons_cards_and_text_read_like_native_controls():
    """Taste pass: ghost is a text button (no outline) with explicit
    outlined/tonal variants; bar indicators use the plain onSurface label and
    a full-pill hover like native bar items; rail sizing applies in bars only
    (a compact dashboard card also reports hostCompact); a UiCard inside a
    dashboard card draws no second surface or inset; titles are semibold.
    """
    button = (KIT / "UiButton.qml").read_text(encoding="utf-8")
    assert 'border.width: root.variant === "outlined" ? 1 : 0' in button
    assert 'root.variant === "tonal" ? Theme.surfaceContainerHighest' in button
    assert 'hostContext.hostSurface === "bar"' in button
    assert "readonly property bool railCompact: inBar &&" in button
    assert "radius: root.inBar ? height / 2 : Theme.rounding" in button

    card = (KIT / "UiCard.qml").read_text(encoding="utf-8")
    assert 'p.hostSurface === "dashboard"' in card
    assert 'color: hostedOnDashboard ? "transparent" : Theme.surfaceContainer' in card
    assert "property int padding: hostedOnDashboard ? 0 : Theme.spacing" in card

    text = (KIT / "UiText.qml").read_text(encoding="utf-8")
    assert "Font.DemiBold" in text and "font.bold" not in text

    bar_host = (ROOT / "modules/plugins/PluginBarWidgets.qml").read_text(encoding="utf-8")
    assert 'readonly property string hostSurface: "bar"' in bar_host
    assert "readonly property int hostAvailableWidth: root.availableWidth" in bar_host
    dash_host = (ROOT / "modules/plugins/PluginDashboardCards.qml").read_text(encoding="utf-8")
    assert 'readonly property string hostSurface: "dashboard"' in dash_host


def test_native_type_scale_and_icons():
    """Native text is sized in points (StyledText); PluginKit used the same
    numbers as pixels, so extension text rendered ~25% smaller than native.
    Extensions also get the native Material Symbols icon and a native card
    header (icon + title).
    """
    for name in ("UiText", "UiButton", "UiChip", "UiTooltip", "UiToggle"):
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        assert "font.pixelSize" not in src, name
        assert "font.pointSize" in src, name
    theme = (KIT / "Theme.qml").read_text(encoding="utf-8")
    assert "iconFontFamily: Appearance.font.family.material" in theme
    assert "fontSizeBody: Appearance.font.size.smaller" in theme
    icon = (KIT / "UiIcon.qml").read_text(encoding="utf-8")
    assert "Theme.iconFontFamily" in icon and "FILL:" in icon and "GRAD:" in icon
    assert "UiIcon 1.0 UiIcon.qml" in (KIT / "qmldir").read_text(encoding="utf-8")
    card = (KIT / "UiCard.qml").read_text(encoding="utf-8")
    assert "property string title" in card and "property string icon" in card
    assert "UiIcon" in card and "Accessible.Heading" in card
    button = (KIT / "UiButton.qml").read_text(encoding="utf-8")
    # AbstractButton owns a FINAL `icon` group, hence iconName.
    assert "property string iconName" in button and "UiIcon" in button
    assert "property string icon:" not in button


def test_uidetailrow_is_the_native_popout_row():
    src = (KIT / "UiDetailRow.qml").read_text(encoding="utf-8")
    assert 'property string label: ""' in src
    assert 'property string value: ""' in src
    assert "Text.AlignRight" in src
    assert "valueItem.implicitWidth" in src  # filler must leave room for the value


def test_uiactionrow_is_the_native_popout_action():
    src = (KIT / "UiActionRow.qml").read_text(encoding="utf-8")
    assert 'property string text: ""' in src
    assert "signal clicked()" in src
    assert "UiStateLayer" in src  # native hover/press layer, not a button pill
    assert "Theme.focusRing" in src  # keyboard-only focus ring
    assert "Keys.onSpacePressed" in src  # Space activates (not a Controls Button)
    assert "Text.ElideRight" in src  # label fills the row and elides
    assert "UiActionRow 1.0 UiActionRow.qml" in (KIT / "qmldir").read_text(encoding="utf-8")


def test_uibutton_transparent_island_colour_falls_back_to_bar_colour():
    src = (KIT / "UiButton.qml").read_text(encoding="utf-8")
    assert "islandColoured" in src and "hostIconColor.a > 0" in src
    assert "root.islandColoured ? root.hostStyle.hostIconColor" in src
