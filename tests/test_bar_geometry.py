"""Bar size and shape controls (Bars pane): pure geometry logic, content scale and wiring."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
GEO = ROOT / "modules/controlcenter/taskbar/bargeometry.js"
NODE = pytest.mark.skipif(shutil.which("node") is None, reason="node not installed")


def run_js(source: str, body: str):
    script = source.replace(".pragma library", "") + "\n" + body
    out = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def geo(body: str):
    return run_js(GEO.read_text(encoding="utf-8"), body)


BARS = "[{edge:'left',style:'attached',reserve:true,margin:6,thickness:60,density:'values',groups:{start:[{id:'logo',enabled:true,options:{a:1}}],center:[],end:[]}},{edge:'top',style:'inset',reserve:true,margin:6,thickness:34,density:'values',groups:{start:[],center:[],end:[]}}]"


@NODE
def test_thickness_and_margin_are_clamped_to_config_limits():
    out = geo(f"""
const b = {BARS};
console.log(JSON.stringify([
  setBarField(b, 0, 'thickness', 5)[0].thickness, setBarField(b, 0, 'thickness', 500)[0].thickness,
  setBarField(b, 0, 'thickness', 'x')[0].thickness, setBarField(b, 0, 'thickness', 61)[0].thickness,
  setBarField(b, 0, 'margin', -4)[0].margin, setBarField(b, 0, 'margin', 99)[0].margin]));""")
    assert out == [24, 96, 34, 62, 0, 24]


@NODE
def test_edits_never_touch_groups_and_return_copies():
    out = geo(f"""
const b = {BARS};
const n = setBarField(b, 0, 'thickness', 70);
console.log(JSON.stringify({{same: JSON.stringify(n[0].groups) === JSON.stringify(b[0].groups), orig: b[0].thickness, next: n[0].thickness}}));""")
    assert out == {"same": True, "orig": 60, "next": 70}


@NODE
def test_style_density_and_edge_validation():
    out = geo(f"""
const b = {BARS};
console.log(JSON.stringify({{
  badStyle: setBarField(b, 0, 'style', 'glass')[0].style,
  floating: setBarField(b, 0, 'style', 'floating')[0].reserve,
  dock: setBarField(b, 0, 'style', 'dock')[0].reserve,
  badDensity: setBarField(b, 0, 'density', 'tiny')[0].density,
  glyphs: setBarField(b, 0, 'density', 'glyphs')[0].density,
  occupied: setBarField(b, 0, 'edge', 'top')[0].edge,
  free: setBarField(b, 0, 'edge', 'right')[0].edge,
  badEdge: setBarField(b, 0, 'edge', 'middle')[0].edge,
  badIndex: setBarField(b, 9, 'thickness', 40).length}}));""")
    assert out == {"badStyle": "attached", "floating": False, "dock": True, "badDensity": "values",
                   "glyphs": "glyphs", "occupied": "left", "free": "right", "badEdge": "left", "badIndex": 2}


@NODE
def test_reset_returns_to_preset_values_or_factory_fallbacks():
    preset = json.loads((ROOT / "presets/hornero-left.json").read_text(encoding="utf-8"))
    out = geo(f"""
const preset = {json.dumps(preset)};
const b = setBarField(setBarField({BARS}, 0, 'thickness', 90), 0, 'margin', 20);
const r = resetBar(b, 0, preset)[0];
const f = resetBar(b, 1, null)[1];
const g = presetGlobals(preset);
console.log(JSON.stringify({{t: r.thickness, m: r.margin, ft: f.thickness, fm: f.margin, inner: g.innerWidth, cs: g.contentScale, rs: g.roundingScale}}));""")
    assert out == {"t": 60, "m": 6, "ft": 34, "fm": 6, "inner": 44, "cs": 1.25, "rs": 1}


@NODE
def test_every_preset_round_trips_through_the_limits():
    for path in sorted((ROOT / "presets").glob("*.json")):
        preset = json.loads(path.read_text(encoding="utf-8"))
        out = geo(f"""
const p = {json.dumps(preset)};
const ok = p.bar.bars.every(b => {{ const r = resetBar([b], 0, p)[0]; return r.thickness === b.thickness && r.margin === b.margin && r.style === b.style; }});
const g = presetGlobals(p);
console.log(JSON.stringify({{ok: ok, inner: g.innerWidth === p.bar.sizes.innerWidth, cs: g.contentScale === (p.bar.sizes.contentScale ?? 1)}}));""")
        assert out == {"ok": True, "inner": True, "cs": True}, path.stem


@NODE
def test_preview_ratio_is_to_scale():
    out = geo("console.log(JSON.stringify([previewRatio(54, 'left', 1920, 1080), previewRatio(54, 'top', 1920, 1080), previewRatio(99999, 'top', 1920, 1080), previewRatio(10, 'top', 0, 0)]));")
    assert out == [0.028125, 0.05, 1, 0]


@NODE
def test_content_scale_grows_icons_and_labels_but_stays_bounded():
    js = (ROOT / "services/density.js").read_text(encoding="utf-8")
    out = run_js(js, """
const f = factor(1080, 1, true);
console.log(JSON.stringify({base: [icon(f), text(f), clock(f), micro(f)], rail: [icon(f, 1.25), text(f, 1.25), clock(f, 1.25), micro(f, 1.25)],
  tiny: icon(f, 0.1), huge: text(f, 9), unset: icon(f, undefined)}));""")
    assert out["base"] == [16, 12, 16, 11]
    assert out["rail"] == [20, 15, 20, 12]
    assert out["tiny"] == 12 and out["huge"] == 18 and out["unset"] == 16


def test_content_scale_is_a_schema_key_everywhere():
    default = json.loads((ROOT / "config/shell.default.json").read_text(encoding="utf-8"))
    assert default["bar"]["sizes"]["contentScale"] == 1
    assert "property real contentScale: 1" in (ROOT / "config/BarConfig.qml").read_text(encoding="utf-8")
    assert "contentScale: bar.sizes.contentScale" in (ROOT / "config/Config.qml").read_text(encoding="utf-8")
    assert "Config.bar.sizes.contentScale" in (ROOT / "services/Density.qml").read_text(encoding="utf-8")


def test_bars_pane_exposes_the_controls():
    pane = (ROOT / "modules/controlcenter/taskbar/TaskbarPane.qml").read_text(encoding="utf-8")
    assert "BarGeometryEditor" in pane
    editor = (ROOT / "modules/controlcenter/taskbar/BarGeometryEditor.qml").read_text(encoding="utf-8")
    for needle in ("thickness", "margin", '"style"', '"edge"', '"density"', "innerWidth", "contentScale",
                   "densityScale", "autoDensity", "rounding.scale", "spacing.scale", "padding.scale",
                   "resetBar", "resetGlobals", "Config.save()", "Accessible.name"):
        assert needle in editor, needle
