"""Island inset and active-workspace inset: islands keep a gap from the bar's
cross-axis edges, the active highlight sits inside its track, both are
end-user controls with per-layout defaults (Cockpit Clear ships 0)."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PRESETS = sorted((ROOT / "presets").glob("*.json"))
NODE = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def js(file: str, expr: str):
    src = (ROOT / file).read_text(encoding="utf-8").replace(".pragma library", "", 1)
    out = subprocess.run([shutil.which("node"), "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
                         capture_output=True, text=True, timeout=30)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout)


@NODE
def test_island_keeps_the_inset_on_thin_bars_and_the_natural_gap_on_rails():
    out = js("services/density.js", """
return {cockpitBottom: chip(24, 28, islandInset(4, 1, 28)),   // thin strip: 28 - 8
        rail: chip(44, 60, islandInset(4, 1, 60)),            // chunky rail: cell wins
        flush: chip(24, 28, islandInset(0, 1, 28)),           // inset 0: as before
        floor: chip(24, 24, islandInset(12, 1, 24)),          // never under 18
        scaled: islandInset(4, 1.5, 100), clamped: [islandInset(99, 1, 100), islandInset(-3, 1, 100), islandInset('x', 1, 100)],
        quarter: islandInset(12, 1, 24)}""")
    assert out["cockpitBottom"] == 20 and out["rail"] == 44 and out["flush"] == 24
    assert out["floor"] == 18 and out["scaled"] == 6 and out["clamped"] == [12, 0, 0] and out["quarter"] == 6


@NODE
def test_inset_scales_with_the_density_factor():
    out = js("services/density.js", "return [islandInset(4, factor(720, 1, true), 100), islandInset(4, factor(2160, 1, true), 100), islandInset(4, 1.5, 100)]")
    assert out == [4, 4, 6]


@NODE
def test_active_inset_never_squeezes_the_numeral():
    out = js("services/density.js", """
return [activeInset(4, 1, 24, 16), activeInset(8, 1, 24, 16), activeInset(0, 1, 24, 16), activeInset(99, 1, 44, 16), activeInset(4, 1, 18, 16)]""")
    assert out == [4, 4, 0, 8, 1]


def test_defaults_are_declared_serialised_and_validated():
    cfg = (ROOT / "config/BarConfig.qml").read_text(encoding="utf-8")
    assert "property int islandInset: 4" in cfg and "property int activeInset: 4" in cfg
    ser = (ROOT / "config/Config.qml").read_text(encoding="utf-8")
    assert "islandInset: bar.sizes.islandInset" in ser and "activeInset: bar.workspaces.activeInset" in ser
    default = json.loads((ROOT / "config/shell.default.json").read_text(encoding="utf-8"))["bar"]
    assert default["sizes"]["islandInset"] == 4 and default["workspaces"]["activeInset"] == 4
    geo = (ROOT / "modules/controlcenter/taskbar/bargeometry.js").read_text(encoding="utf-8")
    assert "islandInset: { min: 0, max: 12" in geo and "activeInset: { min: 0, max: 8" in geo


# Per-layout defaults: roomier on the chunky rails and the thicker Cockpit strip,
# none on Cockpit Clear (its reference draws no island).
INSET = {"cockpit-clear": 0, "cockpit": 5, "hornero-left": 6, "hornero-right": 6, "dock-bottom": 5, "classic-bottom": 5}


def test_every_preset_ships_both_insets_and_clear_ships_zero():
    for path in PRESETS:
        bar = json.loads(path.read_text(encoding="utf-8"))["bar"]
        isl = INSET.get(path.stem, 4)
        assert bar["sizes"]["islandInset"] == isl, path.stem
        assert bar["workspaces"]["activeInset"] == (0 if isl == 0 else 4), path.stem
        # An island never ends up thinner than its cell by more than the inset
        # asks for: thick bars keep their cell, so nothing shrinks below 18 px.
        for b in bar["bars"]:
            body = b["thickness"]
            assert body - 2 * bar["sizes"]["islandInset"] >= 18, (path.stem, b["edge"])


@NODE
def test_reset_returns_the_layouts_insets():
    clear = json.loads((ROOT / "presets/cockpit-clear.json").read_text(encoding="utf-8"))
    cockpit = json.loads((ROOT / "presets/cockpit.json").read_text(encoding="utf-8"))
    for preset, want in ((clear, [0, 0]), (cockpit, [5, 4])):
        out = js("modules/controlcenter/taskbar/bargeometry.js",
                 f"const g = presetGlobals({json.dumps(preset)}); return [g.islandInset, g.activeInset]")
        assert out == want
    assert js("modules/controlcenter/taskbar/bargeometry.js", "const g = presetGlobals(null); return [g.islandInset, g.activeInset, clamp('islandInset', 99), clamp('activeInset', -1)]") == [4, 4, 12, 0]


def test_pane_exposes_both_controls_and_resets_them():
    pane = (ROOT / "modules/controlcenter/taskbar/BarGeometryEditor.qml").read_text(encoding="utf-8")
    for needle in ("Config.bar.sizes.islandInset", "Config.bar.workspaces.activeInset",
                   "Config.bar.sizes.islandInset = g.islandInset", "Config.bar.workspaces.activeInset = g.activeInset",
                   'qsTr("Island inset (px)")', 'qsTr("Active workspace inset (px)")'):
        assert needle in pane, needle


def test_bar_wires_the_island_size_into_every_island():
    bar = (ROOT / "modules/bar/Bar.qml").read_text(encoding="utf-8")
    assert "Density.chip(pillThickness)" in bar
    assert bar.count("cross: root.islandCross") == 5
    for name in ("Tray", "StatusIcons", "ExtensionsIsland", "workspaces/Workspaces"):
        src = (ROOT / "modules/bar/components" / f"{name}.qml").read_text(encoding="utf-8")
        assert "property int cross: Density.inner" in src, name
    ws = (ROOT / "modules/bar/components/workspaces/Workspaces.qml").read_text(encoding="utf-8")
    assert "Density.activeInset(cross)" in ws
    ind = (ROOT / "modules/bar/components/workspaces/ActiveIndicator.qml").read_text(encoding="utf-8")
    assert "root.crossSize - root.inset * 2" in ind and "Density.inner - Appearance.padding.small" not in ind
