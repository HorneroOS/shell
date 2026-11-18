"""Hidden settings, `strings` type and UiScrollArea (RFC 0003 section 10a)."""

import importlib.util
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("hornero_validator_extras", ROOT / "scripts/validate_plugin.py")
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)
SCHEMA = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
SERVICE = (ROOT / "services/Plugins.qml").read_text()
SECTION = (ROOT / "modules/controlcenter/extensions/PluginSettingsSection.qml").read_text()
KIT = ROOT / "plugin/qml/Hornero/PluginKit"


def manifest(settings, level=4):
    data = {
        "schemaVersion": 3, "id": "x-y", "name": "X", "version": "1.0.0", "description": "d",
        "author": "a", "license": "MIT", "entrypoint": "Main.qml",
        "files": ["Main.qml", "README.md", "LICENSE"],
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": settings},
    }
    if level:
        data["pluginKit"] = level
    return data


def package(tmp_path, data):
    root = tmp_path / "x-y"
    root.mkdir()
    (root / "manifest.json").write_text(json.dumps(data))
    (root / "Main.qml").write_text("import QtQuick\nItem {}\n")
    (root / "README.md").write_text("# x\n")
    (root / "LICENSE").write_text("MIT\n")
    return root


GOOD = {
    "deadlineEpochMs": {"type": "integer", "default": 0, "hidden": True},
    "tags": {"type": "strings", "default": ["a"], "maxItems": 4, "maxLength": 10, "title": "Tags"},
}


def test_hidden_and_strings_validate(tmp_path):
    data = manifest(GOOD)
    assert not list(Draft202012Validator(SCHEMA).iter_errors(data))
    V.validate_plugin(package(tmp_path, data))


@pytest.mark.parametrize("settings", [
    {"s": {"type": "strings", "default": ["a", "a"], "maxItems": 1}},
    {"s": {"type": "strings", "default": [""]}},
    {"s": {"type": "strings", "default": ["toolongvalue"], "maxLength": 3}},
    {"s": {"type": "strings", "default": [], "minItems": 2}},
    {"s": {"type": "strings", "default": [], "minItems": 3, "maxItems": 1}},
    {"s": {"type": "strings", "default": [], "options": ["a"]}},
    {"s": {"type": "strings", "default": [], "maxLength": 200}},
    {"h": {"type": "boolean", "default": True, "hidden": "yes"}},
    {"a": {"type": "boolean", "default": True},
     "h": {"type": "boolean", "default": True, "hidden": True, "visibleWhen": {"key": "a", "equals": True}}},
])
def test_invalid(tmp_path, settings):
    with pytest.raises(V.ValidationError):
        V.validate_plugin(package(tmp_path, manifest(settings)))


def test_level_gate(tmp_path):
    with pytest.raises(V.ValidationError, match="pluginKit"):
        V.validate_plugin(package(tmp_path, manifest({"h": {"type": "boolean", "default": True, "hidden": True}}, level=None)))


@pytest.mark.parametrize(("decl", "value", "ok"), [
    ({"type": "strings", "default": []}, ["a", "b"], True),
    ({"type": "strings", "default": []}, "a", False),
    ({"type": "strings", "default": []}, [1], False),
    ({"type": "strings", "default": [], "maxItems": 1}, ["a", "b"], False),
    ({"type": "strings", "default": [], "maxLength": 2}, ["abc"], False),
])
def test_value_validity(decl, value, ok):
    assert V.setting_value_valid(decl, value) is ok


def test_runtime_and_ui_wiring():
    assert '"strings"' in SERVICE or "strings:" in SERVICE
    assert "declaration.hidden" in SERVICE
    assert "hidden !== true" in SECTION
    assert "for (const key of root.settingKeys())" in SECTION  # Reset all spares hidden state
    assert "One entry per line" in SECTION


def test_scroll_area_is_part_of_the_kit_and_documented():
    assert "UiScrollArea 1.0 UiScrollArea.qml" in (KIT / "qmldir").read_text()
    src = (KIT / "UiScrollArea.qml").read_text()
    assert "Flickable" in src and "Accessible.name" in src and "activeFocusOnTab: contentHeight > height" in src
    assert "UiScrollArea" in (ROOT / "docs/PLUGINS.md").read_text()
