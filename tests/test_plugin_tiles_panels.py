"""Quick-setting tile and panel contributions (RFC 0003 sections 4.3, 4.4)."""

import importlib.util
import json
import subprocess
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

from tests.pluginkit_harness import ROOT, qmltestrunner

SPEC = importlib.util.spec_from_file_location("hornero_validator_tiles", ROOT / "scripts/validate_plugin.py")
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)
SCHEMA = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
EXAMPLE = ROOT / "examples/plugins/example-commands"
SERVICE = (ROOT / "services/Plugins.qml").read_text()
TILE = (ROOT / "modules/plugins/PluginQuickTile.qml").read_text()
TOGGLES = (ROOT / "modules/utilities/cards/Toggles.qml").read_text()
PANEL = (ROOT / "modules/controlcenter/extensions/PluginPanelHost.qml").read_text()
PANE = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()

TILE_QML = "import QtQuick\nItem { property bool checked: false; function toggle() {} }\n"


def make(tmp_path, contributes, surfaces, qml=TILE_QML, level=4):
    root = tmp_path / "t-pkg"
    root.mkdir()
    data = {
        "schemaVersion": 3, "pluginKit": level, "id": "t-pkg", "name": "T", "version": "1.0.0", "description": "d",
        "author": "a", "license": "MIT", "entrypoint": "Main.qml",
        "files": ["Main.qml", "Tile.qml", "Panel.qml", "README.md", "LICENSE"],
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
        "contributes": contributes, "surfaces": surfaces,
    }
    (root / "manifest.json").write_text(json.dumps(data))
    for name in ("Main.qml", "Panel.qml"):
        (root / name).write_text("import QtQuick\nItem {}\n")
    (root / "Tile.qml").write_text(qml)
    (root / "README.md").write_text("# x\n")
    (root / "LICENSE").write_text("MIT\n")
    return root


TILES = {"quickSettings": [{"id": "q", "title": "Quiet", "glyph": "bell", "kind": "toggle"}]}
SURF = {"quickSetting": {"entrypoint": "Tile.qml"}}


def test_example_validates_with_all_three_contributions():
    V.validate_plugin(EXAMPLE)
    manifest = json.loads((EXAMPLE / "manifest.json").read_text())
    assert not list(Draft202012Validator(SCHEMA).iter_errors(manifest))
    assert set(manifest["contributes"]) == {"commands", "quickSettings", "panels"}


def test_tile_and_panel_validate(tmp_path):
    V.validate_plugin(make(tmp_path, {**TILES, "panels": [{"id": "p", "title": "P"}]},
                           {**SURF, "panel": {"entrypoint": "Panel.qml"}}))


@pytest.mark.parametrize(("contributes", "surfaces", "qml", "message"), [
    (TILES, {"settings": {"entrypoint": "Panel.qml"}}, TILE_QML, "needs surfaces.quickSetting"),
    ({"panels": [{"id": "p", "title": "P"}]}, {**SURF, "panel": {"entrypoint": "Panel.qml"}}, TILE_QML, "needs contributes.quickSettings"),
    ({"quickSettings": [{"id": "q", "title": "Q", "kind": "dial"}]}, SURF, TILE_QML, "kind must be"),
    ({"quickSettings": [{"id": "q", "title": "Q"}] * 2}, SURF, TILE_QML, "duplicates"),
    ({"quickSettings": [{"id": f"q{i}", "title": "Q"} for i in range(5)]}, SURF, TILE_QML, "1 to 4"),
    ({"panels": [{"id": "p", "title": "P", "kind": "toggle"}]}, {"panel": {"entrypoint": "Panel.qml"}}, TILE_QML, "unknown fields"),
    (TILES, SURF, "import QtQuick\nItem {}\n", "toggle"),
])
def test_invalid(tmp_path, contributes, surfaces, qml, message):
    with pytest.raises(V.ValidationError, match=message):
        V.validate_plugin(make(tmp_path, contributes, surfaces, qml))


def test_level_gate(tmp_path):
    with pytest.raises(V.ValidationError, match="PluginKit 4"):
        V.validate_plugin(make(tmp_path, TILES, SURF, level=3))


def test_tiles_are_host_drawn_isolated_and_opt_in():
    assert "asynchronous: true" in TILE and "Plugins.markFailed" in TILE and "try {" in TILE
    assert "root.ready && root.state.busy !== true" in TILE
    assert "accessibleName:" in TILE
    assert "PluginQuickTile" in TOGGLES and "StableList" in TOGGLES
    assert "placedTiles" in SERVICE and "quickTilesList" in SERVICE
    # off until the person adds the tile
    assert "setQuickTile(tileRow.tileKey, checked)" in PANE


def test_panels_load_only_while_open_in_their_own_loader():
    assert "active: root.available" in PANEL and "asynchronous: true" in PANEL
    assert "root.open &&" in PANEL and "Plugins.markFailed" in PANEL
    assert "PluginPanelHost" in PANE and "openPanelKey" in PANE


TESTS = """import QtQuick
import QtTest
import Fake 1.0
TestCase {
  name: "tiles"
  PluginsConfig { id: c }
  function init() { c.quickTiles = [] }
  function test_place_and_remove() {
    verify(c.setQuickTile("a-b:q", true)); verify(c.setQuickTile("a-b:q", true))
    compare(c.quickTilesList().length, 1)
    verify(c.setQuickTile("c:r", true)); compare(c.quickTilesList()[1], "c:r")
    verify(c.setQuickTile("a-b:q", false)); compare(c.quickTilesList().length, 1)
  }
  function test_invalid_and_limit() {
    verify(!c.setQuickTile("bad key", true)); verify(!c.setQuickTile("a:Q", true)); verify(!c.setQuickTile("a#i1:q", true))
    for (var i = 0; i < c.maxQuickTiles; i++) verify(c.setQuickTile("p" + i + ":q", true))
    verify(!c.setQuickTile("extra:q", true))
  }
  function test_malformed_stored() {
    c.quickTiles = ["a:q", "a:q", 5, null, "Bad:Q", "b:r"]
    compare(c.quickTilesList().length, 2)
    c.quickTiles = "nope"; compare(c.quickTilesList().length, 0)
  }
}
"""


@pytest.mark.skipif(qmltestrunner() is None, reason="qmltestrunner not installed")
def test_quick_tile_placement_model(tmp_path):
    module = tmp_path / "imports" / "Fake"
    module.mkdir(parents=True)
    source = (ROOT / "config/PluginsConfig.qml").read_text()
    source = source.replace("import Quickshell.Io\n", "").replace("JsonObject {", "QtObject {", 1)
    (module / "PluginsConfig.qml").write_text(source)
    (module / "qmldir").write_text("module Fake\nPluginsConfig 1.0 PluginsConfig.qml\n")
    test = tmp_path / "tst.qml"
    test.write_text(TESTS)
    r = subprocess.run([str(qmltestrunner()), "-import", str(tmp_path / "imports"), "-input", str(test), "-o", "-,txt"],
                       capture_output=True, text=True, timeout=120, env={"QT_QPA_PLATFORM": "offscreen", "PATH": "/usr/bin"})
    assert r.returncode == 0 and "FAIL" not in r.stdout, r.stdout + r.stderr
