"""Offscreen render check for the workspace cells (needs `qs`, skipped without it).

Renders Cockpit (horizontal), Hornero Left (vertical rail) and Cockpit Clear
with several workspaces holding windows, then checks from the live geometry:
cells share one cross-axis size, never overlap, and the numeral and every
window glyph stay inside their cell without touching each other.
"""

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
RENDER = ROOT / "tests" / "render"

pytestmark = pytest.mark.skipif(
    shutil.which("qs") is None or shutil.which("dbus-run-session") is None or shutil.which("rsync") is None,
    reason="needs quickshell, dbus-run-session and rsync",
)


@pytest.fixture(scope="module")
def tree(tmp_path_factory):
    base = tmp_path_factory.mktemp("wsrender")
    dest = base / "tree"
    subprocess.run(["bash", str(RENDER / "build.sh"), str(ROOT), str(dest)], check=True, capture_output=True)
    return base, dest


def probe(tree, preset, height=1080):
    base, dest = tree
    env = dict(os.environ, HORNERO_SCRATCH=str(base))
    out = base / f"{preset}.png"
    subprocess.run(
        ["bash", str(RENDER / "render.sh"), str(dest), str(ROOT / "presets" / f"{preset}.json"), "-", "-", "1280", str(height), "1", str(out)],
        check=True, capture_output=True, env=env,
    )
    log = (base / f"{preset}.png.log").read_text(errors="replace")
    m = re.search(r"WSPROBE (\{.*\})", log)
    assert m, "no WSPROBE line: the strip did not render"
    return json.loads(m.group(1))


@pytest.mark.parametrize("preset", ["cockpit", "hornero-left", "cockpit-clear"])
def test_cells_do_not_overlap_and_glyphs_stay_inside(tree, preset):
    data = probe(tree, preset)
    vertical = data["vertical"]
    cells = data["cells"]
    assert len(cells) >= 5
    assert any(c["glyphs"] > 0 for c in cells), "fixture must show window glyphs"
    cross = [c["w"] if vertical else c["h"] for c in cells]
    assert len(set(cross)) == 1, f"cells differ in cross size: {cross}"
    # Along the main axis cells are disjoint and in order.
    for a, b in zip(cells, cells[1:]):
        end = a["y"] + a["h"] if vertical else a["x"] + a["w"]
        start = b["y"] if vertical else b["x"]
        assert start >= end, f"cells overlap: {a} {b}"
    for c in cells:
        w, h = c["w"], c["h"]
        assert 0 <= c["nx"] and c["nx"] + c["nw"] <= w + 0.5, c
        assert 0 <= c["ny"] and c["ny"] + c["nh"] <= h + 0.5, c
        if c["glyphs"]:
            assert c["gx"] >= 0 and c["gx"] + c["gw"] <= w + 0.5, c
            assert c["gy"] >= 0 and c["gy"] + c["gh"] <= h + 0.5, c
            # The glyph group starts after the numeral: no overlap, no negative margin.
            if vertical:
                assert c["gy"] >= c["ny"] + c["nh"] - 0.5, c
            else:
                assert c["gx"] >= c["nx"] + c["nw"] - 0.5, c
