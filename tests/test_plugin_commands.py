"""Command contributions (RFC 0003 section 4.2, PluginKit 4): manifest
declaration, validator, schema, host wiring, launcher and IPC."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("hornero_validator_commands", ROOT / "scripts/validate_plugin.py")
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

SCHEMA = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
SERVICE = (ROOT / "services/Plugins.qml").read_text()
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text()
COMMAND_HOST = (ROOT / "modules/plugins/PluginCommandHost.qml").read_text()
SHELL = (ROOT / "shell.qml").read_text()
EXAMPLE = ROOT / "examples/plugins/example-commands"
RUN_QML = "import QtQuick\nItem { function run(commandId: string, args: string): string { return \"\" } }\n"


def make(tmp_path: Path, *, commands=None, level=4, surface=True, qml=RUN_QML, extra=None) -> Path:
    root = tmp_path / "cmd-pkg"
    root.mkdir()
    data = {
        "schemaVersion": 3, "id": "cmd-pkg", "name": "Cmd", "version": "1.0.0", "description": "d",
        "author": "a", "license": "MIT", "entrypoint": "Main.qml",
        "files": ["Main.qml", "Commands.qml", "README.md", "LICENSE"],
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
    }
    if level is not None:
        data["pluginKit"] = level
    if commands is not None:
        data["contributes"] = {"commands": commands}
    if surface:
        data["surfaces"] = {"commands": {"entrypoint": "Commands.qml"}}
    data.update(extra or {})
    (root / "manifest.json").write_text(json.dumps(data))
    (root / "Main.qml").write_text("import QtQuick\nItem {}\n")
    (root / "Commands.qml").write_text(qml)
    (root / "README.md").write_text("# x\n")
    (root / "LICENSE").write_text("MIT\n")
    return root


GOOD = [{"id": "greet", "title": "Say hello", "glyph": "bolt", "keywords": ["hi"], "description": "d"}]


def test_example_validates_and_schema_accepts_it():
    VALIDATOR.validate_plugin(EXAMPLE)
    manifest = json.loads((EXAMPLE / "manifest.json").read_text())
    assert not list(Draft202012Validator(SCHEMA).iter_errors(manifest))


def test_valid_commands_pass(tmp_path):
    VALIDATOR.validate_plugin(make(tmp_path, commands=GOOD))


@pytest.mark.parametrize(
    ("kwargs", "message"),
    [
        ({"commands": GOOD, "level": None}, "PluginKit 4"),
        ({"commands": GOOD, "level": 3}, "PluginKit 4"),
        ({"commands": GOOD, "surface": False}, "surfaces.commands"),
        ({"commands": None, "surface": True}, "contributes.commands"),
        ({"commands": []}, "1 to 16"),
        ({"commands": GOOD * 2}, "duplicates"),
        ({"commands": [{"id": "Bad", "title": "t"}]}, "id must match"),
        ({"commands": [{"id": "ok"}]}, "id and title"),
        ({"commands": [{"id": "ok", "title": ""}]}, "title"),
        ({"commands": [{"id": "ok", "title": "t" * 49}]}, "title"),
        ({"commands": [{"id": "ok", "title": "t", "glyph": "not-a-glyph"}]}, "glyph"),
        ({"commands": [{"id": "ok", "title": "t", "keywords": ["a"] * 9}]}, "keywords"),
        ({"commands": [{"id": "ok", "title": "t", "keywords": ["a", "a"]}]}, "keywords"),
        ({"commands": [{"id": "ok", "title": "t", "exec": "rm -rf /"}]}, "unknown fields"),
        ({"commands": [{"id": f"c{i}", "title": "t"} for i in range(17)]}, "1 to 16"),
        ({"commands": GOOD, "qml": "import QtQuick\nItem {}\n"}, "function run"),
    ],
)
def test_invalid_commands_are_rejected(tmp_path, kwargs, message):
    with pytest.raises(VALIDATOR.ValidationError, match=message):
        VALIDATOR.validate_plugin(make(tmp_path, **kwargs))


def test_unknown_contribution_kinds_are_rejected(tmp_path):
    root = make(tmp_path, commands=GOOD)
    data = json.loads((root / "manifest.json").read_text())
    data["contributes"]["widgets"] = []
    (root / "manifest.json").write_text(json.dumps(data))
    with pytest.raises(VALIDATOR.ValidationError, match="unknown kinds"):
        VALIDATOR.validate_plugin(root)


def test_a_commands_surface_without_level_4_is_rejected_even_alone(tmp_path):
    root = tmp_path / "x"
    root.mkdir()
    pkg = make(root, commands=GOOD, level=3)
    with pytest.raises(VALIDATOR.ValidationError, match="PluginKit 4"):
        VALIDATOR.validate_plugin(pkg)


def test_host_records_contributions_and_gates_the_surface():
    assert '"commands"' in HOST.split("knownSurfaces =")[1].split(";")[0]
    assert "Plugins.markContributes" in HOST
    assert "is a PluginKit 4 surface and requires pluginKit 4" in HOST
    for needle in ("function normalizeContributes", "function markContributes", "function commandList", "function commandPlugins"):
        assert needle in SERVICE


def test_command_host_is_lazy_isolated_and_user_gesture_only():
    assert "PluginCommandHost {}" in SHELL
    # lazy per-extension Loader, loaded on first invocation, own failure state
    assert "property bool wanted: false" in COMMAND_HOST and "active: slot.wanted" in COMMAND_HOST
    assert "Plugins.markFailed" in COMMAND_HOST
    # handler errors and exceptions are contained
    assert "try {" in COMMAND_HOST and "catch (e)" in COMMAND_HOST
    # arguments are bounded and passed through untouched
    assert "maxArgsLength" in COMMAND_HOST
    # only declared commands run, never an arbitrary id
    assert "Plugins.commandList().find(c => c.pluginId === pluginId && c.id === commandId)" in COMMAND_HOST
    # no key binding, no process spawn of extension-provided text
    assert "execDetached([\"notify-send\"" in COMMAND_HOST
    assert "execDetached" not in COMMAND_HOST.replace('execDetached(["notify-send"', "")


def test_launcher_and_ipc_surface():
    assert '"prefix": root.providerPrefix' in COMMAND_HOST and 'providerPrefix: "do"' in COMMAND_HOST
    assert 'target: "plugincommands"' in COMMAND_HOST
    assert "function list()" in COMMAND_HOST and "function run(" in COMMAND_HOST
    ipc = (ROOT / "docs/IPC.md").read_text()
    assert "plugincommands" in ipc
    docs = (ROOT / "docs/PLUGINS.md").read_text()
    assert "plugincommands run" in docs and "contributes.commands" in docs
