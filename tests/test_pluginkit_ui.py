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
