"""Extension settings schema, migration/reset semantics, and the
generated Control Center settings UI (shell#374)."""

import importlib.util
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "hornero_plugin_validator_settings", ROOT / "scripts/validate_plugin.py"
)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

SCHEMA = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
SERVICE = (ROOT / "services/Plugins.qml").read_text()
FACADE = (ROOT / "plugin/qml/Hornero/PluginKit/Settings.qml").read_text()
CONFIG = (ROOT / "config/PluginsConfig.qml").read_text()
SECTION = (ROOT / "modules/controlcenter/extensions/PluginSettingsSection.qml").read_text()
PANE = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()


def make_plugin(tmp_path: Path, settings: dict) -> Path:
    plugin = tmp_path / "example-clock"
    plugin.mkdir()
    manifest = {
        "schemaVersion": 1,
        "id": "example-clock",
        "name": "Example Clock",
        "version": "1.0.0",
        "description": "A sample clock card.",
        "author": "Example Author",
        "license": "MIT",
        "entrypoint": "Main.qml",
        "files": ["Main.qml", "README.md", "LICENSE"],
        "capabilities": {
            "processCommands": [],
            "networkHosts": [],
            "settings": settings,
        },
    }
    (plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    (plugin / "Main.qml").write_text("import QtQuick\nItem {}\n", encoding="utf-8")
    (plugin / "README.md").write_text("# Example Clock\n", encoding="utf-8")
    (plugin / "LICENSE").write_text("MIT\n", encoding="utf-8")
    return plugin


def manifest_with(settings: dict) -> dict:
    return {
        "schemaVersion": 1,
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


ALL_TYPES = {
    "enabled": {"type": "boolean", "default": True, "description": "Turn it on."},
    "refreshMinutes": {"type": "integer", "default": 15, "minimum": 1, "maximum": 120},
    "opacity": {"type": "number", "default": 0.9, "minimum": 0.1, "maximum": 1},
    "label": {"type": "string", "default": "Weather", "minLength": 1, "maxLength": 40},
    "units": {"type": "enum", "default": "metric", "options": ["metric", "imperial"]},
}


def test_all_typed_settings_validate_in_schema_and_validator(tmp_path):
    plugin = make_plugin(tmp_path, ALL_TYPES)
    VALIDATOR.validate_plugin(plugin)
    assert not list(Draft202012Validator(SCHEMA).iter_errors(manifest_with(ALL_TYPES)))


def test_v1_settings_without_constraints_still_validate(tmp_path):
    # Backward compatibility: pre-#374 declarations are unchanged.
    legacy = {"twentyFourHour": {"type": "boolean", "default": True}}
    VALIDATOR.validate_plugin(make_plugin(tmp_path, legacy))
    assert not list(Draft202012Validator(SCHEMA).iter_errors(manifest_with(legacy)))


@pytest.mark.parametrize(
    "settings",
    [
        # enum contract
        {"units": {"type": "enum", "default": "metric"}},
        {"units": {"type": "enum", "default": "kelvin", "options": ["metric"]}},
        {"units": {"type": "enum", "default": "metric", "options": []}},
        {"units": {"type": "enum", "default": "metric", "options": ["metric", "metric"]}},
        {"units": {"type": "enum", "default": "metric", "options": ["metric", 3]}},
        {"units": {"type": "enum", "default": "metric", "options": ["metric"], "minimum": 1}},
        # numeric constraints
        {"count": {"type": "integer", "default": 5, "minimum": 10, "maximum": 1}},
        {"count": {"type": "integer", "default": 50, "maximum": 10}},
        {"count": {"type": "integer", "default": 5, "minimum": 1.5}},
        {"ratio": {"type": "number", "default": 2.0, "maximum": 1.0}},
        {"count": {"type": "integer", "default": True}},
        # string constraints
        {"label": {"type": "string", "default": "toolong", "maxLength": 3}},
        {"label": {"type": "string", "default": "", "minLength": 1}},
        {"label": {"type": "string", "default": "x", "minLength": 5, "maxLength": 2}},
        {"label": {"type": "string", "default": "x", "maxLength": 4097}},
        {"label": {"type": "string", "default": "x" * 4097}},
        # misplaced / unknown / invented types
        {"flag": {"type": "boolean", "default": True, "minimum": 0}},
        {"flag": {"type": "boolean", "default": True, "options": ["a"]}},
        {"label": {"type": "string", "default": "x", "pattern": ".*"}},
        {"where": {"type": "path", "default": "/etc/passwd"}},
        {"where": {"type": "filepath", "default": "notes.txt"}},
        {"flag": {"type": "boolean"}},
        {"Bad Key": {"type": "boolean", "default": True}},
    ],
)
def test_invalid_setting_declarations_are_rejected(tmp_path, settings):
    with pytest.raises(VALIDATOR.ValidationError):
        VALIDATOR.validate_plugin(make_plugin(tmp_path, settings))


@pytest.mark.parametrize(
    "settings",
    [
        {"units": {"type": "enum", "default": "metric"}},
        {"units": {"type": "enum", "default": "metric", "options": []}},
        {"units": {"type": "enum", "default": "metric", "options": ["metric", "metric"]}},
        {"flag": {"type": "boolean", "default": True, "minimum": 0}},
        {"count": {"type": "integer", "default": 5, "minimum": 1.5}},
        {"label": {"type": "string", "default": "x", "pattern": ".*"}},
        {"label": {"type": "string", "default": "x", "maxLength": 4097}},
        {"where": {"type": "path", "default": "/etc/passwd"}},
    ],
)
def test_schema_rejects_what_it_can_express(settings):
    assert list(Draft202012Validator(SCHEMA).iter_errors(manifest_with(settings)))


def test_schema_and_validator_agree_on_the_closed_type_set():
    setting_schema = SCHEMA["properties"]["capabilities"]["properties"]["settings"]
    declared = set(setting_schema["additionalProperties"]["properties"]["type"]["enum"])
    assert declared == set(VALIDATOR.SETTING_TYPES) == {
        "boolean", "integer", "number", "string", "enum"
    }
    assert "path" not in declared
    for kind in declared:
        assert f'"{kind}"' in SERVICE, f"runtime must mirror setting type {kind}"


@pytest.mark.parametrize(
    ("declaration", "value", "valid"),
    [
        ({"type": "boolean", "default": True}, False, True),
        ({"type": "boolean", "default": True}, 1, False),
        ({"type": "integer", "default": 3, "minimum": 1, "maximum": 5}, 5, True),
        ({"type": "integer", "default": 3, "minimum": 1, "maximum": 5}, 6, False),
        ({"type": "integer", "default": 3}, 3.0, False),
        ({"type": "integer", "default": 3}, True, False),
        ({"type": "number", "default": 0.5, "maximum": 1}, 1, True),
        ({"type": "number", "default": 0.5}, float("inf"), False),
        ({"type": "string", "default": "a", "minLength": 1, "maxLength": 3}, "ab", True),
        ({"type": "string", "default": "a", "maxLength": 3}, "abcd", False),
        ({"type": "string", "default": "a"}, "x" * 4097, False),
        ({"type": "enum", "default": "a", "options": ["a", "b"]}, "b", True),
        ({"type": "enum", "default": "a", "options": ["a", "b"]}, "c", False),
        ({"type": "enum", "default": "a", "options": ["a", "b"]}, 1, False),
    ],
)
def test_setting_value_valid(declaration, value, valid):
    assert VALIDATOR.setting_value_valid(declaration, value) is valid


@pytest.mark.parametrize(
    ("declaration", "stored", "expected"),
    [
        # Still-valid stored values survive a manifest update untouched.
        ({"type": "boolean", "default": True}, False, False),
        ({"type": "integer", "default": 15, "minimum": 1, "maximum": 120}, 30, 30),
        ({"type": "enum", "default": "metric", "options": ["metric", "imperial"]}, "imperial", "imperial"),
        # Type changed under the stored value -> default, no coercion.
        ({"type": "integer", "default": 15}, "30", 15),
        ({"type": "boolean", "default": True}, "yes", True),
        # Enum option removed -> default.
        ({"type": "enum", "default": "metric", "options": ["metric"]}, "imperial", "metric"),
        # Range/length tightened -> default (never clamped).
        ({"type": "integer", "default": 15, "maximum": 20}, 60, 15),
        ({"type": "string", "default": "hi", "maxLength": 4}, "hello world", "hi"),
        # Malformed stored shapes -> default, no crash.
        ({"type": "string", "default": "hi"}, {"nested": True}, "hi"),
        ({"type": "number", "default": 0.5}, None, 0.5),
        ({"type": "integer", "default": 3}, [3], 3),
    ],
)
def test_migration_falls_back_to_default(declaration, stored, expected):
    assert VALIDATOR.migrated_setting_value(declaration, stored) == expected


def test_runtime_mirrors_validation_migration_and_normalization():
    assert "function settingValueValid(declaration: var, value: var): bool" in SERVICE
    assert "function migratedSettingValue(declaration: var, stored: var): var" in SERVICE
    assert "function normalizeSettings(settings: var): var" in SERVICE
    assert "function settingDeclarationValid(declaration: var): bool" in SERVICE
    assert "const normalized = root.normalizeSettings(settings)" in SERVICE
    assert "settings: normalized" in SERVICE
    assert "declaration.options.includes(value)" in SERVICE
    # String length counts Unicode code points (like the schema),
    # not UTF-16 code units.
    assert "[...value].length" in SERVICE
    assert "length > 4096" in SERVICE
    # Blank descriptions are rejected at runtime too (schema parity).
    assert r"!/\S/.test(declaration.description)" in SERVICE


def test_facade_reads_through_migration_and_writes_through_constraints():
    assert "Plugins.migratedSettingValue(declaration, stored)" in FACADE
    assert "Plugins.settingConstraintsSatisfied(value, declaration)" in FACADE
    assert 'if (type === "enum")' in FACADE
    assert "Config.plugins.setSetting(pluginId, key, value)" in FACADE


def test_reset_removes_stored_values_and_saves():
    assert "function resetSetting(pluginId: string, key: string): bool" in CONFIG
    assert "function resetSettings(pluginId: string): bool" in CONFIG
    assert "delete next[pluginId][key]" in CONFIG
    assert "delete next[pluginId]" in CONFIG
    reset_body = CONFIG[CONFIG.index("function resetSetting"):]
    assert "saveRequested()" in reset_body
    # Facade reset goes through the same Shell-owned storage.
    assert "function resetValue(key: string): bool" in FACADE
    assert "Config.plugins.resetSetting(pluginId, key)" in FACADE
    assert "function resetAll(): bool" in FACADE
    assert "Config.plugins.resetSettings(pluginId)" in FACADE
    # Generated UI reset (per-field and confirmed reset-all).
    assert "Config.plugins.resetSetting(root.pluginId, field.key)" in SECTION
    assert "Config.plugins.resetSettings(root.pluginId)" in SECTION
    assert "confirmResetAll" in SECTION


def test_generated_ui_covers_every_type_with_native_controls():
    assert 'field.decl.type === "boolean"' in SECTION and "StyledSwitch" in SECTION
    assert 'field.decl.type === "integer"' in SECTION and "CustomSpinBox" in SECTION
    # Spinbox edits assign value from JS; a restoring Binding keeps
    # Reset / slider changes in sync instead of a plain binding.
    assert "Binding.RestoreBindingOrValue" in SECTION
    assert 'field.decl.type === "number"' in SECTION and "StyledSlider" in SECTION
    assert 'field.decl.type === "string"' in SECTION and "StyledTextField" in SECTION
    assert 'field.decl.type === "enum"' in SECTION and "ToggleButton" in SECTION
    # Generation is driven by the declarations, sorted for stability,
    # and every value flows through the shared validation/storage.
    assert "Plugins.normalizeSettings(root.settings)" in SECTION
    assert "Object.keys(root.declarations).sort()" in SECTION
    assert "Plugins.migratedSettingValue(decl, stored)" in SECTION
    assert "Plugins.settingValueValid(decl, value)" in SECTION
    assert "Config.plugins.setSetting(root.pluginId, key, value)" in SECTION
    # Descriptions surface visibly, as accessible text, and as tooltip.
    assert "field.description" in SECTION
    assert "Accessible.description: field.description" in SECTION
    assert "Tooltip {" in SECTION
    assert "tooltip: field.description" in SECTION
    # Bounded numbers get a slider only when both bounds are declared.
    assert 'typeof field.decl.minimum === "number" && typeof field.decl.maximum === "number"' in SECTION


def test_pane_shows_settings_only_for_plugins_that_declare_them():
    assert "function pluginSettings(entry): var" in PANE
    assert "function hasPluginSettings(entry): bool" in PANE
    assert "PluginSettingsSection {" in PANE
    assert "visible: root.hasPluginSettings(row.modelData)" in PANE
    assert "root.settingsPluginId === row.modelData.id" in PANE
    # No settings -> the section itself renders nothing.
    assert "visible: root.settingKeys().length > 0" in SECTION
    # Installed-but-not-hosted entries fall back to the capabilities
    # horneroctl reports; hosted entries use the normalized settings.
    assert "entry.capabilities" in PANE and "Plugins.normalizeSettings(declared)" in PANE


def test_generated_ui_never_writes_outside_shell_owned_storage():
    for source in (SECTION, FACADE):
        assert "FileView" not in source
        assert "Process" not in source
    assert "horneroctl" not in SECTION
