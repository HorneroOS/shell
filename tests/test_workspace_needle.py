"""Workspace strip motion and context: needle travel, ink-through, dimension
breaks and the special-workspace recede.

Static contracts always run. The offscreen render checks need `qs` (skipped
without it): they switch workspaces at runtime in tests/render/harness.qml
and read the live plate geometry and pixels frame by frame. Durations are
scaled x10 (appearance.anim.durations.scale) so frame timing is robust on a
loaded machine; t below is in real (unscaled) milliseconds. Set
NEEDLE_EVIDENCE=<dir> to keep the frame sequences.
"""

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WS = ROOT / "modules" / "bar" / "components" / "workspaces"
RENDER = ROOT / "tests" / "render"
ACTIVE = (WS / "ActiveIndicator.qml").read_text()
STRIP = (WS / "Workspaces.qml").read_text()
CELL = (WS / "Workspace.qml").read_text()
INK = (WS / "PlateInk.qml").read_text()
BREAKS = (WS / "GapBreaks.qml").read_text()
BARCFG = (ROOT / "config" / "BarConfig.qml").read_text()
DEFAULTS = json.loads((ROOT / "config" / "shell.default.json").read_text())["bar"]["workspaces"]
PANE = (ROOT / "modules" / "controlcenter" / "taskbar" / "TaskbarPane.qml").read_text()
RANGES = json.loads((ROOT / "config" / "ranges.json").read_text())["ranges"]
SCALE = 10


def code(src):
    """QML source without // comments (so prose never satisfies a contract)."""
    return re.sub(r"//[^\n]*", "", src)


# --- static contracts --------------------------------------------------------

def test_needle_defaults_and_config_keys():
    assert DEFAULTS["activeTrail"] is True and DEFAULTS["trailRatio"] == 1.6
    assert DEFAULTS["showUnoccupied"] is True and DEFAULTS["gapBreaks"] is True
    for key in ("property bool activeTrail: true", "property real trailRatio: 1.6",
                "property bool showUnoccupied: true", "property bool gapBreaks: true"):
        assert key in BARCFG
    serialised = (ROOT / "config" / "Config.qml").read_text()
    for key in ("trailRatio", "showUnoccupied", "gapBreaks"):
        assert f"{key}: bar.workspaces.{key}" in serialised


def test_needle_is_direction_aware_and_motion_gated():
    assert "Appearance.anim.spatial" in ACTIVE  # off at motion level reduced/off
    assert "Appearance.anim.durations.settleFast" in ACTIVE
    assert "Appearance.anim.curves.settleFast" in ACTIVE
    assert "leadDuration * trailRatio" in ACTIVE
    assert "Math.max(1, Math.min(2.5, Config.bar.workspaces.trailRatio))" in ACTIVE
    # The leading edge is the one facing the target, in either direction.
    assert "forward ? root.trailDuration : root.leadDuration" in ACTIVE
    assert "forward ? root.leadDuration : root.trailDuration" in ACTIVE
    # Zero durations (reduced motion) snap: no animation is started.
    assert "root.leadDuration <= 0" in ACTIVE
    # The tick rides the leading third in flight and recentres at rest.
    assert "root.length * 5 / 6" in ACTIVE and "root.length / 6" in ACTIVE
    assert "root.stretch" in ACTIVE


def test_ink_through_is_a_clip_not_an_effect():
    assert "clip: true" in INK
    assert "MultiEffect" not in code(INK) and "layer.enabled" not in code(INK)
    assert "MultiEffect" not in code(STRIP) and "QtQuick.Effects" not in STRIP
    assert "root.tone.ink" in INK
    assert "readonly property Item numeral: indicator" in CELL
    # Under ink-through the active numeral keeps its resting colour; the
    # clip carries the ink, so it lands with the plate.
    assert "root.isActive && root.inkThrough" in CELL
    for src in (ACTIVE, INK, BREAKS):
        assert "Appearance.rounding.full" not in src


def test_special_workspace_recedes_without_scaling():
    assert "scale:" not in code(STRIP)  # SVL: content is never scaled
    assert "blur" not in code(STRIP)
    assert "recedeShift: 2" in STRIP and "Translate" in STRIP
    assert 'edge === "top" ? -recedeShift : recedeShift' in STRIP
    assert 'edge === "right" ? recedeShift : -recedeShift' in STRIP
    assert "receded: root.receded" in STRIP


def test_dimension_breaks_mark_skipped_numbers():
    assert "Config.bar.workspaces.gapBreaks" in STRIP
    assert "Config.bar.workspaces.showUnoccupied" in STRIP
    assert "n - prev > 1" in STRIP
    assert "inkFaint" in BREAKS
    # 1 px line with 2 px end ticks either side (5 px across).
    assert "height: root.vertical ? 1 : 5" in BREAKS and "width: root.vertical ? 5 : 1" in BREAKS


def test_control_center_exposes_needle_with_reset():
    assert 'qsTr("Needle travel")' in PANE and "Config.bar.workspaces.activeTrail = checked" in PANE
    block = re.search(r'SizeSlider \{[^}]*key: "trailRatio"[^}]*\}', PANE, re.S)
    assert block, "trail ratio slider (SizeSlider carries the Reset button)"
    body = block.group(0)
    assert "from: 1" in body and "to: 2.5" in body and "defaultValue: 1.6" in body
    assert RANGES["bar.workspaces.trailRatio"] == {"min": 1, "max": 2.5, "step": 0.1, "default": 1.6}
    assert 'qsTr("Show empty workspaces")' in PANE and 'qsTr("Gap breaks")' in PANE


# --- offscreen render checks -------------------------------------------------

needs_qs = pytest.mark.skipif(
    shutil.which("qs") is None or shutil.which("dbus-run-session") is None or shutil.which("rsync") is None,
    reason="needs quickshell, dbus-run-session and rsync",
)


def merge(a, b):
    for k, v in b.items():
        if isinstance(v, dict) and isinstance(a.get(k), dict):
            merge(a[k], v)
        else:
            a[k] = v
    return a


@pytest.fixture(scope="module")
def tree(tmp_path_factory):
    base = tmp_path_factory.mktemp("wsneedle")
    dest = base / "tree"
    subprocess.run(["bash", str(RENDER / "build.sh"), str(ROOT), str(dest)], check=True, capture_output=True)
    return base, dest


def render(tree, preset, name, overrides=None, env=None):
    base, dest = tree
    pre = json.loads((ROOT / "presets" / f"{preset}.json").read_text())
    merge(pre, overrides or {})
    pfile = base / f"{name}.json"
    pfile.write_text(json.dumps(pre))
    frames = Path(os.environ["NEEDLE_EVIDENCE"]) / name if os.environ.get("NEEDLE_EVIDENCE") else base / name
    frames.mkdir(parents=True, exist_ok=True)
    out = frames / "final.png"
    e = dict(os.environ, HORNERO_SCRATCH=str(base), HFRAMES=str(frames), **(env or {}))
    subprocess.run(["bash", str(RENDER / "render.sh"), str(dest), str(pfile), "-", "-", "1280", "1080", "1", str(out)],
                   check=True, capture_output=True, env=e)
    log = Path(str(out) + ".log").read_text(errors="replace")
    rest = [json.loads(m) for m in re.findall(r"NEEDLEREST (\{.*\})", log)]
    fr = sorted((json.loads(m) for m in re.findall(r"NEEDLEFRAME (\{.*\})", log)), key=lambda f: f["i"])
    return {"dir": frames, "rest": rest[0] if rest else None, "frames": fr, "log": log}


def travel(tree, preset, src, dst, tag="", overrides=None):
    ov = merge({"appearance": {"anim": {"durations": {"scale": SCALE}}}}, overrides or {})
    env = {"WSACTIVE": str(src), "WSTO": str(dst), "HFRAMEMS": "200", "HFRAMECOUNT": "22"}
    r = render(tree, preset, f"{preset}-{src}to{dst}{tag}", ov, env)
    assert r["rest"] and r["frames"], "the strip did not render or switch"
    return r


def axis(g):
    return ("y", "h") if g["vertical"] else ("x", "w")


def cell(g, ws):
    return next(c for c in g["cells"] if c["ws"] == ws)


def frame_at(r, real_ms):
    return min(r["frames"], key=lambda f: abs(f["done"]["t"] / SCALE - real_ms))["done"]


def span(g, thing):
    p, s = axis(g)
    return thing[p], thing[p] + thing[s]


def settled(r, ws):
    g = r["frames"][-1]["done"]
    p, s = axis(g)
    c = cell(g, ws)
    assert abs(g["plate"][s] - c[s]) <= 0.5, (g["plate"], c)
    assert abs(g["plate"][p] - c[p]) <= 0.5, (g["plate"], c)


@needs_qs
@pytest.mark.parametrize("preset", ["cockpit", "hornero-left", "cockpit-clear"])
def test_needle_stretches_across_passed_cells_then_lands_as_one_cell(tree, preset):
    fwd = travel(tree, preset, 1, 4)
    g = frame_at(fwd, 110)
    assert g["plate"]["needle"]
    lo, hi = span(g, g["plate"])
    c2, c4 = span(g, cell(g, 2)), span(g, cell(g, 4))
    # Lead edge already in cell 4 while the trailing edge is still in cell 2.
    assert hi >= c4[0], (g["plate"], c4)
    assert lo <= c2[1], (g["plate"], c2)
    _, s = axis(g)
    assert g["plate"][s] > 2 * cell(g, 2)[s], "plate spans more than two cells mid-flight"
    settled(fwd, 4)

    back = travel(tree, preset, 4, 1)
    g = frame_at(back, 110)
    lo, hi = span(g, g["plate"])
    c1, c3 = span(g, cell(g, 1)), span(g, cell(g, 3))
    assert lo <= c1[1], (g["plate"], c1)  # lead (start) edge reached cell 1
    assert hi >= c3[0], (g["plate"], c3)  # trail still in cell 3
    settled(back, 1)


def _rgb(hexstr):
    h = hexstr.lstrip("#")[-6:]
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def _nearest(img, c, colour):
    best = 1e9
    for y in range(int(c["ny"]), int(c["ny"] + c["nh"]) + 1):
        for x in range(int(c["nx"]), int(c["nx"] + c["nw"]) + 1):
            px = img.getpixel((x, y))[:3]
            best = min(best, sum((a - b) ** 2 for a, b in zip(px, colour)) ** 0.5)
    return best


@needs_qs
@pytest.mark.parametrize("preset", ["cockpit", "hornero-left"])
def test_numerals_under_the_plate_turn_ink_mid_flight(tree, preset):
    image = pytest.importorskip("PIL.Image")
    r = travel(tree, preset, 1, 4, "-ink")
    ink, muted = _rgb(r["rest"]["ink"]), _rgb(r["rest"]["inkMuted"])
    checked = 0
    for f in r["frames"]:
        g = f["done"]
        if g["t"] / SCALE > 220:
            break
        img = image.open(r["dir"] / f"frame-{f['i']:02d}.png").convert("RGB")
        lo, hi = span(g, g["plate"])
        for c in g["cells"]:
            p, s = axis(g)
            n0 = c["ny"] if g["vertical"] else c["nx"]
            n1 = n0 + (c["nh"] if g["vertical"] else c["nw"])
            if c["ws"] in (2, 3) and lo <= n0 and n1 <= hi:
                assert _nearest(img, c, ink) < 40, (f["i"], c["ws"])
                checked += 1
    assert checked, "no frame had a passed numeral fully under the plate"
    # At rest the passed cells read muted again (the ink is the plate's).
    img = image.open(r["dir"] / "final.png").convert("RGB")
    g = r["frames"][-1]["done"]
    c3 = cell(g, 3)
    assert _nearest(img, c3, muted) < _nearest(img, c3, ink), "cell 3 stays muted at rest"


@needs_qs
def test_needle_off_and_reduced_motion_do_not_stretch(tree):
    off = travel(tree, "cockpit", 1, 4, "-off", {"bar": {"workspaces": {"activeTrail": False}}})
    g = frame_at(off, 110)
    assert not g["plate"]["needle"]
    _, s = axis(g)
    # Both edges move together: never longer than the larger end cell.
    assert g["plate"][s] <= max(cell(g, 1)[s], cell(g, 4)[s]) + 0.5
    reduced = travel(tree, "cockpit", 1, 4, "-reduced", {"appearance": {"reducedMotion": True}})
    g = reduced["frames"][0]["done"]
    p, s = axis(g)
    assert abs(g["plate"][p] - cell(g, 4)[p]) <= 0.5 and abs(g["plate"][s] - cell(g, 4)[s]) <= 0.5, "instant jump"


@needs_qs
@pytest.mark.parametrize("preset", ["cockpit", "hornero-left", "cockpit-clear"])
def test_one_dimension_break_where_numbers_skip(tree, preset):
    # Fixture: workspaces 1, 2, 4, 5 hold windows, 3 is empty.
    r = travel(tree, preset, 1, 1, "-gaps", {"bar": {"workspaces": {"showUnoccupied": False}}})
    g = r["rest"]
    shown = [c["ws"] for c in g["cells"] if c["visible"]]
    assert shown == [1, 2, 4, 5]
    assert [c["ws"] for c in g["cells"] if c["gap"]] == [4]
    p, s = axis(g)
    c2, c4 = cell(g, 2), cell(g, 4)
    assert c4[p] - (c2[p] + c2[s]) >= 6, "the break widens the gap to hold its mark"
    plain = travel(tree, preset, 1, 1, "-nogaps", {"bar": {"workspaces": {"showUnoccupied": False, "gapBreaks": False}}})
    assert not any(c["gap"] for c in plain["rest"]["cells"])


@needs_qs
@pytest.mark.parametrize("preset", ["cockpit", "hornero-left", "cockpit-clear"])
def test_special_workspace_recedes_2px_away_from_content_without_scaling(tree, preset):
    base = travel(tree, preset, 1, 1, "-base")["rest"]
    spec = render(tree, preset, f"{preset}-special", {}, {"WSACTIVE": "1", "WSTO": "1", "WSSPECIAL": "1",
                                                          "HFRAMEMS": "200", "HFRAMECOUNT": "1"})["rest"]
    assert spec["receded"] and not base["receded"]
    dx = {"top": (0, -2), "bottom": (0, 2), "left": (-2, 0), "right": (2, 0)}[spec["edge"]]
    for a, b in zip(base["cells"], spec["cells"]):
        assert (b["w"], b["h"]) == (a["w"], a["h"]), "no scaling"
        assert abs(b["x"] - a["x"] - dx[0]) <= 0.5 and abs(b["y"] - a["y"] - dx[1]) <= 0.5, (a, b)
