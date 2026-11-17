"""Per-layout override map: pure logic (node) and wiring."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "services" / "layouts.js"
NODE = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")
FACTORY = json.loads((ROOT / "config" / "shell.default.json").read_text())


def run(body: str):
    script = JS.read_text().replace(".pragma library", "") + "\n" + body
    out = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def test_factory_ships_no_overrides_and_schema_is_wired():
    assert FACTORY["layouts"] == {"overrides": {}}
    assert "property var overrides: ({})" in (ROOT / "config" / "LayoutsConfig.qml").read_text()
    cfg = (ROOT / "config" / "Config.qml").read_text()
    for needle in ("property alias layouts: adapter.layouts", "layouts: serializeLayouts()", "overrides: layouts.overrides", "property LayoutsConfig layouts"):
        assert needle in cfg


def test_overridable_keys_exist_in_the_schema():
    keys = json.loads(subprocess.run(["node", "-e", JS.read_text().replace(".pragma library", "") + "\nconsole.log(JSON.stringify(KEY_IDS))"], capture_output=True, text=True, check=True).stdout) if shutil.which("node") else []
    for key in keys:
        node = FACTORY
        for part in key.split("."):
            assert part in node, key
            node = node[part]


@NODE
def test_sanitize_drops_unknown_ids_keys_and_bad_values_and_clamps():
    out = run("""console.log(JSON.stringify(sanitize({
  'cockpit': {'bar.sizes.innerWidth': 999, 'bar.sizes.textScale': 'x', 'bar.typeface': 'serif', 'nope': 1, 'bar.sizes.autoDensity': false},
  'Bad Id': {'bar.typeface': 'sans'}, 'empty': {'bar.typeface': 'serif'}, 'x': 5, 'zen': {'appearance.rounding.scale': 0.1}})))""")
    assert out == {"cockpit": {"bar.sizes.innerWidth": 56, "bar.sizes.autoDensity": False}, "zen": {"appearance.rounding.scale": 0.5}}


@NODE
def test_remember_forget_apply_roundtrip_without_mutating_input():
    out = run("""
var live = {'bar.sizes.innerWidth': 30, 'bar.typeface': 'sans', 'bar.sizes.autoDensity': true, 'appearance.spacing.scale': 1.25, 'bar.sizes.textWeight': 999};
var base = {'cockpit': {'bar.typeface': 'mono'}};
var frozen = JSON.stringify(base);
var m = remember(base, 'horizon', function (k) { return live[k]; });
var written = {};
var keys = applyRow(m, 'horizon', function (k, v) { written[k] = v; });
console.log(JSON.stringify({m: m, keys: keys.length, written: written, base: JSON.stringify(base) === frozen,
  none: applyRow(m, 'missing', function () { throw 1; }), gone: forget(m, 'horizon'), drift: drift(m, 'horizon', function (k) { return k === 'bar.typeface' ? 'mono' : live[k]; })}));""")
    assert out["m"]["cockpit"] == {"bar.typeface": "mono"}
    assert out["m"]["horizon"]["bar.sizes.textWeight"] == 600
    assert out["written"] == out["m"]["horizon"] and out["keys"] == 5
    assert out["base"] is True and out["none"] == []
    assert "horizon" not in out["gone"] and "cockpit" in out["gone"]
    assert sorted(out["drift"]) == ["bar.sizes.textWeight", "bar.typeface"]  # live 999 was clamped to 600 when saved


def test_shell_wiring_and_controls():
    singleton = (ROOT / "services" / "Layouts.qml").read_text()
    assert "pragma Singleton" in singleton and 'import "layouts.js" as Model' in singleton
    assert "Config.layouts.overrides" in singleton and "Config.save()" in singleton
    grid = (ROOT / "modules" / "layoutpicker" / "PresetGrid.qml").read_text()
    assert "Layouts.reapplyAfterPreset(applyProc.layoutId)" in grid
    exp = (ROOT / "services" / "Experience.qml").read_text()
    assert "Layouts.reapplyAfterPreset(layoutProc.layoutId)" in exp and exp.count("layoutProc.layoutId =") == 2
    pane = (ROOT / "modules" / "controlcenter" / "layout" / "LayoutPane.qml").read_text()
    assert "LayoutTweaksRow" in pane and "grid.currentPreset" in pane
    row = (ROOT / "modules" / "controlcenter" / "layout" / "LayoutTweaksRow.qml").read_text()
    for call in ("Layouts.remember(", "Layouts.applyNow(", "Layouts.forget("):
        assert call in row
