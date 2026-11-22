"""Typed settings schema v2 and the `pluginKit` level (RFC 0003, apiLevel 4)."""

import importlib.util
import json
import re
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "hornero_plugin_validator_v2", ROOT / "scripts/validate_plugin.py"
)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

SCHEMA = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
SERVICE = (ROOT / "services/Plugins.qml").read_text()
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text()
SECTION = (ROOT / "modules/controlcenter/extensions/PluginSettingsSection.qml").read_text()
PANE = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()
INFO = (ROOT / "plugin/qml/Hornero/PluginKit/PluginKitInfo.qml").read_text()


def manifest(settings: dict, plugin_kit: int | None = 4) -> dict:
    data = {
        "schemaVersion": 3,
        "id": "example-clock",
        "name": "Example Clock",
        "version": "1.0.0",
        "description": "A sample clock card.",
        "author": "Example Author",
        "license": "MIT",
        "entrypoint": "Main.qml",
        "files": ["Main.qml", "README.md", "LICENSE"],
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": settings},
    }
    if plugin_kit is not None:
        data["pluginKit"] = plugin_kit
    return data


def package(tmp_path: Path, data: dict) -> Path:
    root = tmp_path / "example-clock"
    root.mkdir()
    (root / "manifest.json").write_text(json.dumps(data), encoding="utf-8")
    (root / "Main.qml").write_text("import QtQuick\nItem {}\n", encoding="utf-8")
    (root / "README.md").write_text("# x\n", encoding="utf-8")
    (root / "LICENSE").write_text("MIT\n", encoding="utf-8")
    return root


V4_SETTINGS = {
    "tint": {"type": "colour", "default": "#33ccff", "title": "Accent", "group": "Look"},
    "tintAlpha": {"type": "colour", "default": "#33ccff80", "alpha": True, "group": "Look"},
    "metrics": {"type": "list", "default": ["cpu"], "options": ["cpu", "gpu", "mem"], "minItems": 1, "maxItems": 2},
    "note": {"type": "text", "default": "hello\nworld", "rows": 4, "maxLength": 200},
    "folder": {"type": "path", "default": "notes", "kind": "directory"},
    "size": {"type": "integer", "default": 12, "minimum": 8, "maximum": 32, "step": 2, "unit": "px", "title": "Text size"},
    "units": {"type": "enum", "default": "c", "options": ["c", "f"]},
    "gauge": {"type": "boolean", "default": True, "visibleWhen": {"key": "units", "equals": "c"}},
}


def test_v4_settings_validate_in_schema_and_validator(tmp_path):
    data = manifest(V4_SETTINGS)
    assert not list(Draft202012Validator(SCHEMA).iter_errors(data))
    VALIDATOR.validate_plugin(package(tmp_path, data))


@pytest.mark.parametrize(
    "settings",
    [
        {"tint": {"type": "colour", "default": "#33ccff"}},
        {"metrics": {"type": "list", "default": [], "options": ["a"]}},
        {"note": {"type": "text", "default": ""}},
        {"folder": {"type": "path", "default": ""}},
        {"size": {"type": "integer", "default": 1, "title": "Size"}},
        {"flag": {"type": "boolean", "default": True, "group": "G"}},
    ],
)
def test_level_4_features_require_the_pluginkit_declaration(tmp_path, settings):
    with pytest.raises(VALIDATOR.ValidationError, match="pluginKit"):
        VALIDATOR.validate_plugin(package(tmp_path, manifest(settings, plugin_kit=None)))
    other = tmp_path / "declared-3"
    other.mkdir()
    with pytest.raises(VALIDATOR.ValidationError, match="pluginKit"):
        VALIDATOR.validate_plugin(package(other, manifest(settings, plugin_kit=3)))


def test_level_3_manifest_is_unchanged_and_needs_no_declaration(tmp_path):
    base = {"units": {"type": "enum", "default": "c", "options": ["c", "f"]}}
    VALIDATOR.validate_plugin(package(tmp_path, manifest(base, plugin_kit=None)))


@pytest.mark.parametrize("level", [2, 6, True, "4", 4.0, None])
def test_pluginkit_field_is_bounded(tmp_path, level):
    data = manifest({}, plugin_kit=0)
    data["pluginKit"] = level
    with pytest.raises(VALIDATOR.ValidationError):
        VALIDATOR.validate_plugin(package(tmp_path, data))


@pytest.mark.parametrize(
    "settings",
    [
        {"tint": {"type": "colour", "default": "red"}},
        {"tint": {"type": "colour", "default": "#33ccff80"}},  # alpha not declared
        {"tint": {"type": "colour", "default": "#33ccff", "options": ["a"]}},
        {"m": {"type": "list", "default": ["x"], "options": ["a"]}},
        {"m": {"type": "list", "default": ["a", "a"], "options": ["a", "b"]}},
        {"m": {"type": "list", "default": [], "options": ["a"], "minItems": 1}},
        {"m": {"type": "list", "default": ["a"], "options": ["a", "b"], "minItems": 2, "maxItems": 1}},
        {"m": {"type": "list", "default": [], "options": ["a"], "maxItems": 2}},
        {"t": {"type": "text", "default": "x", "rows": 13}},
        {"t": {"type": "text", "default": "x", "rows": 0}},
        {"p": {"type": "path", "default": "/etc/passwd"}},
        {"p": {"type": "path", "default": "~/.ssh/id_rsa"}},
        {"p": {"type": "path", "default": "../up"}},
        {"p": {"type": "path", "default": "", "kind": "socket"}},
        {"p": {"type": "path", "default": "", "mustExist": "yes"}},
        {"n": {"type": "integer", "default": 1, "step": 0}},
        {"n": {"type": "integer", "default": 1, "step": 1.5}},
        {"n": {"type": "number", "default": 1, "step": -1}},
        {"s": {"type": "string", "default": "x", "unit": "px"}},
        {"s": {"type": "string", "default": "x", "step": 1}},
        {"s": {"type": "string", "default": "x", "title": ""}},
        {"s": {"type": "string", "default": "x", "title": "t" * 49}},
        {"s": {"type": "string", "default": "x", "group": "g" * 33}},
        {"n": {"type": "integer", "default": 1, "unit": "pixels!!!"}},
        # visibleWhen
        {"a": {"type": "boolean", "default": True, "visibleWhen": {"key": "a", "equals": True}}},
        {"a": {"type": "boolean", "default": True, "visibleWhen": {"key": "zzz", "equals": True}}},
        {"a": {"type": "boolean", "default": True, "visibleWhen": {"key": "b"}},
         "b": {"type": "boolean", "default": True}},
        {"a": {"type": "boolean", "default": True, "visibleWhen": {"key": "b", "equals": "yes"}},
         "b": {"type": "boolean", "default": True}},
        {"a": {"type": "boolean", "default": True, "visibleWhen": {"key": "b", "equals": True}},
         "b": {"type": "boolean", "default": True, "visibleWhen": {"key": "a", "equals": True}}},
    ],
)
def test_invalid_v4_declarations_are_rejected(tmp_path, settings):
    with pytest.raises(VALIDATOR.ValidationError):
        VALIDATOR.validate_plugin(package(tmp_path, manifest(settings)))


@pytest.mark.parametrize(
    ("declaration", "value", "valid"),
    [
        ({"type": "colour", "default": "#000000"}, "#ABCDEF", True),
        ({"type": "colour", "default": "#000000"}, "#abcdef80", False),
        ({"type": "colour", "default": "#000000", "alpha": True}, "#abcdef80", True),
        ({"type": "colour", "default": "#000000"}, "blue", False),
        ({"type": "colour", "default": "#000000"}, 5, False),
        ({"type": "list", "default": [], "options": ["a", "b"]}, ["b", "a"], True),
        ({"type": "list", "default": [], "options": ["a", "b"]}, ["a", "a"], False),
        ({"type": "list", "default": [], "options": ["a", "b"]}, ["c"], False),
        ({"type": "list", "default": [], "options": ["a", "b"]}, "a", False),
        ({"type": "list", "default": ["a"], "options": ["a", "b"], "minItems": 1}, [], False),
        ({"type": "list", "default": [], "options": ["a", "b"], "maxItems": 1}, ["a", "b"], False),
        ({"type": "text", "default": "", "maxLength": 3}, "a\nb", True),
        ({"type": "text", "default": "", "maxLength": 3}, "a\nbc", False),
        ({"type": "path", "default": ""}, "/home/me/notes.txt", True),
        ({"type": "path", "default": ""}, "a\x00b", False),
        ({"type": "path", "default": ""}, "x" * 1025, False),
        ({"type": "path", "default": ""}, ["a"], False),
    ],
)
def test_value_validation_for_the_new_types(declaration, value, valid):
    assert VALIDATOR.setting_value_valid(declaration, value) is valid


def test_stored_invalid_value_migrates_to_the_default():
    declaration = {"type": "list", "default": ["a"], "options": ["a", "b"]}
    assert VALIDATOR.migrated_setting_value(declaration, ["gone"]) == ["a"]
    assert VALIDATOR.migrated_setting_value(declaration, ["b"]) == ["b"]


def test_schema_and_validator_agree_on_every_new_field():
    setting_props = SCHEMA["properties"]["capabilities"]["properties"]["settings"]["additionalProperties"]["properties"]
    assert set(setting_props) == VALIDATOR.SETTING_FIELDS
    assert set(setting_props["type"]["enum"]) == set(VALIDATOR.SETTING_TYPES)


def test_schema_rejects_misplaced_new_fields():
    validator = Draft202012Validator(SCHEMA)
    for settings in (
        {"x": {"type": "string", "default": "a", "step": 1}},
        {"x": {"type": "boolean", "default": True, "alpha": True}},
        {"x": {"type": "colour", "default": "#000000", "options": ["a"]}},
        {"x": {"type": "path", "default": "", "rows": 3}},
        {"x": {"type": "list", "default": [], "options": ["a"], "rows": 3}},
    ):
        assert list(validator.iter_errors(manifest(settings))), settings


def test_runtime_mirrors_the_validator():
    for kind in VALIDATOR.SETTING_TYPES:
        assert f'"{kind}"' in SERVICE or f"{kind}:" in SERVICE
    for field in ("title", "group", "unit", "step", "visibleWhen", "minItems", "maxItems", "rows", "mustExist", "alpha"):
        assert field in SERVICE, f"runtime must mirror {field}"
    assert "/^#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?$/" in SERVICE


def test_api_level_is_four_and_host_refuses_a_newer_requirement():
    # Level 5 (shell#709 dashboard pages) supersedes the level-4 kit
    # this suite introduced; v2 settings keep requiring only 4.
    assert re.search(r"apiLevel:\s*5", INFO)
    assert VALIDATOR.PLUGINKIT_API_LEVEL == 5
    assert "manifest.pluginKit > Plugins.kitLevel" in HOST


def test_generated_ui_renders_every_new_type_and_the_preview():
    for needle in ('"colour"', '"list"', '"text"', '"path"', "conditionMet", "startsGroup", "field.unit", "root.storageKey"):
        assert needle in SECTION, needle
    assert "PluginPreviewFrame" in PANE
    preview = (ROOT / "modules/controlcenter/extensions/PluginPreviewFrame.qml").read_text()
    assert "Plugins.hasSurface" in preview and "asynchronous: true" in preview


def test_kit_chip_and_plain_lists():
    pane = PANE
    assert 'entry?.pluginKit >= 4 ? qsTr("PluginKit 4")' in pane
    assert "Plugins.markPluginKit" in HOST
    assert "function plain(" in SERVICE and "root.plain(stored)" in SERVICE
