"""example-broken QA fixture (qa#81, shell#380 load-failure isolation).

The fixture must be installable (statically valid, so discovery finds
it) yet deterministically fail to *load* at runtime, so PluginHost
marks only it failed while a healthy neighbour still loads. Safe mode
must stay unaffected: it loads no plugin at all.
"""
import importlib.util
import json
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parent.parent
FIXTURE = ROOT / "examples" / "plugins" / "example-broken"
HOST = (ROOT / "modules" / "plugins" / "PluginHost.qml").read_text()
BAR_HOST = (ROOT / "modules" / "plugins" / "PluginBarWidgets.qml").read_text()
SERVICE = (ROOT / "services" / "Plugins.qml").read_text()

_spec = importlib.util.spec_from_file_location(
    "hornero_plugin_validator_broken", ROOT / "scripts" / "validate_plugin.py"
)
assert _spec and _spec.loader
VALIDATOR = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(VALIDATOR)


def test_broken_fixture_passes_schema_and_static_validation():
    # Valid manifest is the point: failure must be at load time, not
    # manifest rejection, or the scenario proves nothing.
    manifest = json.loads((FIXTURE / "manifest.json").read_text())
    schema = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
    Draft202012Validator(schema).validate(manifest)
    VALIDATOR.validate_plugin(FIXTURE)


def test_broken_fixture_manifest_shape():
    manifest = json.loads((FIXTURE / "manifest.json").read_text())
    assert manifest["id"] == "example-broken"
    assert manifest["entrypoint"] == "Main.qml"
    # Background placement: loaded by the headless PluginHost Loader,
    # the canonical per-plugin fault-isolation path.
    assert manifest["placement"] == "background"
    assert manifest["files"] == ["Main.qml", "README.md", "LICENSE"]
    assert manifest["capabilities"] == {
        "processCommands": [], "networkHosts": [], "settings": {},
    }


def test_broken_fixture_fails_to_load_by_unresolved_type():
    source = (FIXTURE / "Main.qml").read_text()
    assert "BrokenFixtureMissingType" in source
    # The missing type is defined nowhere the QML engine could resolve
    # it from: not a PluginKit public type, not an in-tree component.
    kit = ROOT / "plugin" / "qml" / "Hornero" / "PluginKit" / "qmldir"
    assert "BrokenFixtureMissingType" not in kit.read_text()
    assert not list(ROOT.rglob("BrokenFixtureMissingType.qml"))
    # Imports stay within the validator's allowed surface, which is
    # why static validation passes while engine creation fails.
    imports = [l.strip() for l in source.splitlines() if l.strip().startswith("import ")]
    assert imports == ["import QtQuick"]


def test_host_marks_broken_failed_and_healthy_neighbour_loaded():
    # Background fixture: PluginHost Loader.Error -> markFailed with
    # the loader's (sanitized, bounded) diagnostic.
    assert "status === Loader.Error" in HOST
    assert 'Plugins.markFailed(slot.modelData.id, pluginLoader.errorString' in HOST
    assert "status === Loader.Ready" in HOST and "Plugins.markLoaded" in HOST
    # Each plugin gets its own delegate/Loader, so one failure cannot
    # take down neighbours sharing the host.
    assert "Repeater" in HOST and "Loader" in HOST
    # Healthy neighbour example-clock is a bar plugin: its own Loader
    # in the bar host marks it loaded on Ready, failed only on Error.
    clock = json.loads(
        (ROOT / "examples/plugins/example-clock/manifest.json").read_text()
    )
    assert clock["placement"] == "bar"
    assert "status === Loader.Ready" in BAR_HOST
    assert "Plugins.markLoaded(modelData.id)" in BAR_HOST
    assert "Plugins.markFailed(modelData.id" in BAR_HOST
    # markFailed records state + a bounded, redacted diagnostic entry.
    assert 'root.setState(id, "failed", clean)' in SERVICE
    assert 'root.logDiagnostic(id, "failed", clean)' in SERVICE
    assert "slice(-50)" in SERVICE and "sanitizeDetail" in SERVICE
    assert "diagnosticsLog: root.diagnosticsLog" in SERVICE


def test_broken_fixture_never_ships_enabled_by_default():
    readme = (FIXTURE / "README.md").read_text()
    assert "QA fixture" in readme
    assert "never ship enabled" in readme.lower() or "must never ship enabled" in readme.lower()
    # Nothing in-tree enables it: no config default names it.
    assert "example-broken" not in (ROOT / "config/shell.default.json").read_text()


def test_safe_mode_unaffected_by_broken_fixture():
    # Safe mode empties the host model before any manifest/QML load,
    # so the broken fixture cannot block recovery.
    assert "Plugins.safeMode ? []" in HOST
    assert 'state: enabled && root.safeMode ? "safe-mode"' in SERVICE or '"safe-mode"' in SERVICE
    assert "if (root.safeMode)" in SERVICE
