"""Per-instance desktop widgets (RFC 0003 section 6, PluginKit 4).

Behaviour of the instance model is tested by running the real
config/PluginsConfig.qml logic under qmltestrunner (its JsonObject base is
swapped for a QtObject: persistence is Quickshell's, the model is ours);
the wiring through the host, facade, validator and Control Center is
checked statically like the rest of the plugin suite.
"""

from __future__ import annotations

import importlib.util
import json
import re
import subprocess
from pathlib import Path

import pytest

from tests.pluginkit_harness import ROOT, qmltestrunner

SPEC = importlib.util.spec_from_file_location("hornero_validator_instances", ROOT / "scripts/validate_plugin.py")
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)

SERVICE = (ROOT / "services/Plugins.qml").read_text()
FRAME = (ROOT / "modules/plugins/DesktopWidgetFrame.qml").read_text()
WIDGETS = (ROOT / "modules/plugins/PluginDesktopWidgets.qml").read_text()
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text()
FACADE = (ROOT / "plugin/qml/Hornero/PluginKit/Settings.qml").read_text()
PANE = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()
CONFIG = (ROOT / "config/Config.qml").read_text()
EXAMPLE = ROOT / "examples/plugins/example-instance-clock"

TESTS = """import QtQuick
import QtTest
import Fake 1.0

TestCase {
  name: "instances"
  PluginsConfig { id: c }

  function init() { c.settings = ({}); c.instances = ({}); c.desktopWidgets = ({}); c.desktopWidgetSlots = ({}); }

  function test_keys() {
    compare(c.instanceKey("a-b", ""), "a-b")
    compare(c.instanceKey("a-b", "i1"), "a-b#i1")
    verify(c.validPluginId("a-b"))
    verify(c.validPluginId("a-b#i1"))
    verify(!c.validPluginId("a-b#"))
    verify(!c.validPluginId("a-b#I1"))
    verify(!c.validPluginId("a-b#i1#i2"))
    verify(!c.validPluginId("a#b#c"))
    verify(!c.validPluginId("#i1"))
    verify(!c.validInstanceId("toolongid1"))
  }

  function test_add_assigns_unique_ids_and_caps() {
    compare(c.addInstance("clock", "Home", ""), "i1")
    compare(c.addInstance("clock", "", ""), "i2")
    compare(c.instancesOf("clock").length, 2)
    compare(c.instancesOf("clock")[0].label, "Home")
    for (var n = 0; n < 20; n++) c.addInstance("clock", "", "")
    compare(c.instancesOf("clock").length, c.maxInstances)
    compare(c.addInstance("clock", "", ""), "")
    compare(c.addInstance("Bad Id", "", ""), "")
    compare(c.addInstance("clock#i1", "", ""), "")
  }

  function test_id_is_reused_after_removal() {
    c.addInstance("clock", "", ""); c.addInstance("clock", "", "")
    verify(c.removeInstance("clock", "i1"))
    compare(c.addInstance("clock", "", ""), "i1")
  }

  function test_duplicate_copies_stored_settings_only() {
    c.setSetting("clock", "label", "Main")
    var id = c.addInstance("clock", "Copy", "clock")
    compare(c.settings["clock#" + id].label, "Main")
    c.setSetting("clock#" + id, "label", "Changed")
    compare(c.settings["clock"].label, "Main")
    var blank = c.addInstance("clock", "Blank", "")
    verify(c.settings["clock#" + blank] === undefined)
  }

  function test_settings_are_namespaced_per_instance() {
    var id = c.addInstance("clock", "", "")
    verify(c.setSetting("clock#" + id, "k", 1))
    verify(c.setSetting("clock", "k", 2))
    compare(c.settings["clock#" + id].k, 1)
    compare(c.settings["clock"].k, 2)
    verify(c.resetSetting("clock#" + id, "k"))
    verify(c.settings["clock#" + id] === undefined)
    compare(c.settings["clock"].k, 2)
  }

  function test_remove_deletes_settings_geometry_and_slot_everywhere() {
    var id = c.addInstance("clock", "", "")
    var key = "clock#" + id
    c.setSetting(key, "k", 1); c.setSetting("clock", "k", 2)
    c.setDesktopWidgetGeometry(key, "DP-1", { fx: 0.5, fy: 0.5, width: 300, height: 200 }, true)
    c.setDesktopWidgetGeometry("clock", "DP-1", { fx: 0.1, fy: 0.1, width: 300, height: 200 }, true)
    c.setDesktopWidgetSlot(key, "DP-2", "top-left")
    verify(c.removeInstance("clock", id))
    compare(c.instancesOf("clock").length, 0)
    verify(c.settings[key] === undefined)
    verify(c.desktopWidgetGeometry(key, "DP-1") === null)
    verify(c.desktopWidgets["DP-1"][key] === undefined)
    verify(c.desktopWidgetSlots["DP-2"][key] === undefined)
    // the primary widget is untouched
    compare(c.settings["clock"].k, 2)
    verify(c.desktopWidgetGeometry("clock", "DP-1") !== null)
    verify(!c.removeInstance("clock", id))
  }

  function test_rename_is_bounded() {
    var id = c.addInstance("clock", "", "")
    verify(c.renameInstance("clock", id, "  " + "x".repeat(60) + "  "))
    compare(c.instancesOf("clock")[0].label.length, 32)
    verify(!c.renameInstance("clock", "zz", "n"))
  }

  function test_malformed_stored_instances_are_ignored() {
    c.instances = { clock: [ { id: "ok", label: "A" }, { id: "ok", label: "dup" }, { id: "Bad Id" }, null, 5, { id: "i2" } ], other: "nope" }
    var list = c.instancesOf("clock")
    compare(list.length, 2)
    compare(list[0].id, "ok")
    compare(list[1].id, "i2")
    compare(c.instancesOf("other").length, 0)
    c.instances = [1, 2]
    compare(c.instancesOf("clock").length, 0)
  }

  function test_geometry_and_slot_accept_instance_keys() {
    verify(c.setDesktopWidgetGeometry("clock#i1", "DP-1", { fx: 2, fy: -1, width: 500, height: 300 }, true))
    var g = c.desktopWidgetGeometry("clock#i1", "DP-1")
    compare(g.fx, 1); compare(g.fy, 0)
    verify(c.setDesktopWidgetSlot("clock#i1", "DP-1", "top-right"))
    compare(c.desktopWidgetSlot("clock#i1", "DP-1"), "top-right")
    compare(c.desktopWidgetSlot("clock", "DP-1"), "bottom-right")
  }
}
"""


@pytest.mark.skipif(qmltestrunner() is None, reason="qmltestrunner not installed")
def test_instance_model_behaviour(tmp_path):
    module = tmp_path / "imports" / "Fake"
    module.mkdir(parents=True)
    source = (ROOT / "config/PluginsConfig.qml").read_text()
    source = source.replace("import Quickshell.Io\n", "").replace("JsonObject {", "QtObject {", 1)
    (module / "PluginsConfig.qml").write_text(source, encoding="utf-8")
    (module / "qmldir").write_text("module Fake\nPluginsConfig 1.0 PluginsConfig.qml\n", encoding="utf-8")
    test = tmp_path / "tst_instances.qml"
    test.write_text(TESTS, encoding="utf-8")
    result = subprocess.run(
        [str(qmltestrunner()), "-import", str(tmp_path / "imports"), "-input", str(test), "-o", "-,txt"],
        capture_output=True, text=True, timeout=120,
        env={"QT_QPA_PLATFORM": "offscreen", "PATH": "/usr/bin"},
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "FAIL" not in result.stdout, result.stdout


def test_instances_persist_through_config_serialisation():
    assert "instances: plugins.instances" in CONFIG


def test_service_expands_instances_only_for_extensions_that_opt_in():
    assert "declared.instances !== true" in SERVICE
    assert "Config.plugins.instancesOf(entry.id)" in SERVICE
    # load state, diagnostics and safe mode stay per plugin
    assert "instanceKey: entry.id" in SERVICE and "id: entry.id" not in SERVICE.split("function desktopPlugins")[1].split("function ")[0]


def test_geometry_slot_and_solver_are_keyed_by_instance():
    assert "root.instanceKey" in FRAME
    for old in ("desktopWidgetGeometry(root.pluginId", "perScreen[root.pluginId]", "setDesktopWidgetGeometry(root.pluginId"):
        assert old not in FRAME, old
    assert "entry.instanceKey" in WIDGETS
    assert "hostInstanceId" in FRAME


def test_facade_and_host_gate():
    assert 'property string instanceId: ""' in FACADE
    assert "namespaceKey" in FACADE
    assert "surfaces.desktop.instances" in HOST


def test_control_center_retargets_settings_and_preview_to_the_selected_instance():
    assert "PluginInstancesSection" in PANE
    assert "storageKey: Config.plugins.instanceKey" in PANE
    assert "instanceId: instancesSection" in PANE


def test_example_validates_and_reads_its_instance():
    VALIDATOR.validate_plugin(EXAMPLE)
    manifest = json.loads((EXAMPLE / "manifest.json").read_text())
    assert manifest["pluginKit"] == 4 and manifest["surfaces"]["desktop"]["instances"] is True
    assert "instanceId: root.hostInstanceId" in (EXAMPLE / "Main.qml").read_text()


def _manifest(tmp_path: Path, instances, plugin_kit=4, qml="Item { property string hostInstanceId: \"\"; Settings { pluginId: \"x-y\"; instanceId: hostInstanceId } }"):
    root = tmp_path / "x-y"
    root.mkdir()
    data = {
        "schemaVersion": 3, "id": "x-y", "name": "X", "version": "1.0.0", "description": "d",
        "author": "a", "license": "MIT", "entrypoint": "Main.qml", "placement": "desktop",
        "files": ["Main.qml", "README.md", "LICENSE"],
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
        "surfaces": {"desktop": {"entrypoint": "Main.qml", "instances": instances}},
    }
    if plugin_kit is not None:
        data["pluginKit"] = plugin_kit
    (root / "manifest.json").write_text(json.dumps(data))
    (root / "Main.qml").write_text("import QtQuick\nimport Hornero.PluginKit\n" + qml + "\n")
    (root / "README.md").write_text("# x\n")
    (root / "LICENSE").write_text("MIT\n")
    return root


def test_validator_requires_level_4_and_a_real_instance_reader(tmp_path):
    VALIDATOR.validate_plugin(_manifest(tmp_path, True))
    (tmp_path / "a").mkdir()
    with pytest.raises(VALIDATOR.ValidationError, match="PluginKit 4"):
        VALIDATOR.validate_plugin(_manifest(tmp_path / "a", True, plugin_kit=None))
    (tmp_path / "b").mkdir()
    with pytest.raises(VALIDATOR.ValidationError, match="hostInstanceId"):
        VALIDATOR.validate_plugin(_manifest(tmp_path / "b", True, qml="Item {}"))
    (tmp_path / "c").mkdir()
    with pytest.raises(VALIDATOR.ValidationError, match="boolean"):
        VALIDATOR.validate_plugin(_manifest(tmp_path / "c", "yes"))
    (tmp_path / "d").mkdir()
    # false needs no declaration and no reader
    VALIDATOR.validate_plugin(_manifest(tmp_path / "d", False, plugin_kit=None, qml="Item {}"))
