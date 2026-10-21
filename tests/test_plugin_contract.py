import importlib.util
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "hornero_plugin_validator", ROOT / "scripts/validate_plugin.py"
)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


def make_plugin(tmp_path: Path, qml: str = "import QtQuick\nItem {}") -> Path:
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
            "settings": {"twentyFourHour": {"type": "boolean", "default": True}},
        },
    }
    (plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    (plugin / "Main.qml").write_text(qml, encoding="utf-8")
    (plugin / "README.md").write_text("# Example Clock\n", encoding="utf-8")
    (plugin / "LICENSE").write_text("MIT\n", encoding="utf-8")
    return plugin


def test_schema_declares_the_same_required_manifest_contract():
    schema = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
    Draft202012Validator.check_schema(schema)
    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert set(schema["required"]) == {
        "schemaVersion", "id", "name", "version", "description", "author",
        "license", "entrypoint", "files", "capabilities",
    }
    assert schema["additionalProperties"] is False


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("name", "   "),
        ("description", "\t"),
        ("author", "  "),
        ("license", "\n"),
        ("homepage", "http://example.test"),
        ("entrypoint", "./Main.qml"),
        ("entrypoint", "sub//Main.qml"),
    ],
)
def test_schema_and_validator_reject_noncanonical_metadata(tmp_path, field, value):
    plugin = make_plugin(tmp_path)
    manifest = json.loads((plugin / "manifest.json").read_text())
    manifest[field] = value
    (plugin / "manifest.json").write_text(json.dumps(manifest))
    schema = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())

    assert list(Draft202012Validator(schema).iter_errors(manifest))
    with pytest.raises(VALIDATOR.ValidationError):
        VALIDATOR.validate_plugin(plugin)


@pytest.mark.parametrize(
    "setting",
    [
        {"type": "boolean", "default": "true"},
        {"type": "integer", "default": 1.5},
        {"type": "number", "default": False},
        {"type": "string", "default": 1},
    ],
)
def test_schema_and_validator_reject_mismatched_setting_types(tmp_path, setting):
    plugin = make_plugin(tmp_path)
    manifest = json.loads((plugin / "manifest.json").read_text())
    manifest["capabilities"]["settings"]["twentyFourHour"] = setting
    (plugin / "manifest.json").write_text(json.dumps(manifest))
    schema = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())

    assert list(Draft202012Validator(schema).iter_errors(manifest))
    with pytest.raises(VALIDATOR.ValidationError, match="does not match"):
        VALIDATOR.validate_plugin(plugin)


@pytest.mark.parametrize(
    "mutate",
    [
        lambda manifest: manifest["capabilities"]["settings"].update(
            {"twentyFourHour": {"type": "boolean", "default": True, "description": "  "}}
        ),
        lambda manifest: manifest["capabilities"]["processCommands"].append("BASH"),
        lambda manifest: manifest.update({"placement": "sidebar"}),
    ],
)
def test_schema_and_validator_reject_review_hazards(tmp_path, mutate):
    plugin = make_plugin(tmp_path)
    manifest = json.loads((plugin / "manifest.json").read_text())
    mutate(manifest)
    (plugin / "manifest.json").write_text(json.dumps(manifest))
    schema = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())

    assert list(Draft202012Validator(schema).iter_errors(manifest))
    with pytest.raises(VALIDATOR.ValidationError):
        VALIDATOR.validate_plugin(plugin)


def test_valid_package_passes(tmp_path):
    plugin = make_plugin(tmp_path)
    manifest = json.loads((plugin / "manifest.json").read_text())
    schema = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
    Draft202012Validator(schema).validate(manifest)
    VALIDATOR.validate_plugin(plugin)


def test_signed_package_passes(tmp_path):
    # shell#251 phase 2: the optional author-signature block is a
    # legal manifest field. Shape is schema-checked here; the
    # cryptographic verification itself is horneroctl's job.
    plugin = make_plugin(tmp_path)
    manifest = json.loads((plugin / "manifest.json").read_text())
    manifest["signing"] = {
        "publicKey": "Ulcr" + "A" * 52,
        "signature": "RWQ" + "B" * 96,
    }
    (plugin / "manifest.json").write_text(json.dumps(manifest))
    schema = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
    Draft202012Validator(schema).validate(manifest)
    VALIDATOR.validate_plugin(plugin)


def test_in_tree_example_passes_schema_and_static_validation():
    plugin = ROOT / "examples/plugins/example-clock"
    manifest = json.loads((plugin / "manifest.json").read_text())
    schema = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
    Draft202012Validator(schema).validate(manifest)
    VALIDATOR.validate_plugin(plugin)


def test_internal_shell_import_is_rejected(tmp_path):
    plugin = make_plugin(tmp_path, "import Hornero.Services\nItem {}")
    with pytest.raises(VALIDATOR.ValidationError, match="unsupported module"):
        VALIDATOR.validate_plugin(plugin)


def test_unrecognized_plugin_kit_submodules_are_rejected(tmp_path):
    plugin = make_plugin(tmp_path, "import Hornero.PluginKit.Internal\nItem {}")
    with pytest.raises(VALIDATOR.ValidationError, match="unsupported module"):
        VALIDATOR.validate_plugin(plugin)


def test_undeclared_process_command_is_rejected(tmp_path):
    plugin = make_plugin(tmp_path, 'import Quickshell.Io\nProcess { command: ["curl", "example.test"] }')
    with pytest.raises(VALIDATOR.ValidationError, match="undeclared or disallowed command"):
        VALIDATOR.validate_plugin(plugin)


def test_process_without_literal_argv_is_rejected(tmp_path):
    plugin = make_plugin(tmp_path, 'import Quickshell.Io\nProcess { command: commandFromSettings }')
    with pytest.raises(VALIDATOR.ValidationError, match="literal argv array"):
        VALIDATOR.validate_plugin(plugin)


def test_declared_process_command_and_network_host_are_accepted(tmp_path):
    plugin = make_plugin(
        tmp_path,
        'import QtQuick\nimport Quickshell.Io\nItem {\n'
        ' Process { command: ["curl", "https://api.example.test/status"] }\n'
        ' property string endpoint: "https://api.example.test/status"\n}',
    )
    manifest = json.loads((plugin / "manifest.json").read_text())
    manifest["capabilities"]["processCommands"] = ["curl"]
    manifest["capabilities"]["networkHosts"] = ["api.example.test"]
    (plugin / "manifest.json").write_text(json.dumps(manifest))
    VALIDATOR.validate_plugin(plugin)


def test_shell_interpreter_and_privilege_escalation_are_rejected(tmp_path):
    plugin = make_plugin(tmp_path, 'import QtQuick\nItem { property string command: "sudo reboot" }')
    with pytest.raises(VALIDATOR.ValidationError, match="forbidden"):
        VALIDATOR.validate_plugin(plugin)


def test_manifest_rejects_path_traversal(tmp_path):
    plugin = make_plugin(tmp_path)
    manifest = json.loads((plugin / "manifest.json").read_text())
    manifest["entrypoint"] = "../outside.qml"
    (plugin / "manifest.json").write_text(json.dumps(manifest))
    with pytest.raises(VALIDATOR.ValidationError, match="safe relative path"):
        VALIDATOR.validate_plugin(plugin)


def test_package_requires_readme_and_license(tmp_path):
    plugin = make_plugin(tmp_path)
    manifest = json.loads((plugin / "manifest.json").read_text())
    manifest["files"].remove("LICENSE")
    (plugin / "manifest.json").write_text(json.dumps(manifest))
    with pytest.raises(VALIDATOR.ValidationError, match="README.md and LICENSE"):
        VALIDATOR.validate_plugin(plugin)


def test_unlisted_files_are_rejected(tmp_path):
    plugin = make_plugin(tmp_path)
    (plugin / "extra.qml").write_text("import QtQuick\nItem {}")
    with pytest.raises(VALIDATOR.ValidationError, match="unlisted files"):
        VALIDATOR.validate_plugin(plugin)


def test_symlinked_files_are_rejected(tmp_path):
    plugin = make_plugin(tmp_path)
    (plugin / "link.qml").symlink_to(plugin / "Main.qml")
    with pytest.raises(VALIDATOR.ValidationError, match="symbolic links"):
        VALIDATOR.validate_plugin(plugin)


def test_settings_defaults_must_match_the_declared_type(tmp_path):
    plugin = make_plugin(tmp_path)
    manifest = json.loads((plugin / "manifest.json").read_text())
    manifest["capabilities"]["settings"]["twentyFourHour"]["default"] = "yes"
    (plugin / "manifest.json").write_text(json.dumps(manifest))
    with pytest.raises(VALIDATOR.ValidationError, match="does not match"):
        VALIDATOR.validate_plugin(plugin)


def test_duplicate_manifest_keys_are_rejected(tmp_path):
    plugin = make_plugin(tmp_path)
    (plugin / "manifest.json").write_text('{"schemaVersion": 1, "schemaVersion": 1}')
    with pytest.raises(VALIDATOR.ValidationError, match="duplicate key"):
        VALIDATOR.validate_plugin(plugin)


def test_plugin_host_repeater_has_a_visual_root():
    # Regression: a Repeater placed directly under PluginHost's Scope
    # (a non-visual QObject) never materialises its delegates in
    # Quickshell — they are counted but never complete, so manifests
    # were never read and every plugin stayed "pending" forever.
    # The host must wrap the Repeater in a (hidden) Item root.
    host = (ROOT / "modules/plugins/PluginHost.qml").read_text(encoding="utf-8")
    item_at = host.find("Item {")
    repeater_at = host.find("Repeater {")
    assert item_at != -1 and repeater_at != -1
    assert item_at < repeater_at, "Repeater must be nested inside an Item root"
    header = host[item_at:repeater_at]
    assert "visible: false" in header, "the delegate root Item must stay invisible"


def test_extensions_pane_surfaces_trust_state():
    # shell#251: installed rows show the horneroctl trust state and
    # offer the two-step Trust… → Confirm trust flow for untrusted or
    # stale-trust plugins. The pane only invokes horneroctl; it never
    # writes receipts itself.
    pane = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text(encoding="utf-8")
    assert 'qsTr("Trust: %1")' in pane
    assert 'qsTr("Trust…")' in pane
    assert 'qsTr("Confirm trust")' in pane
    assert 'runLifecycle("trust", row.modelData.id)' in pane
    assert "pendingTrust" in pane
