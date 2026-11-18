"""Offscreen renders of the dashboard home (media deck, compositions).

Needs `qs`, dbus-run-session and rsync, plus a build of this branch's
plugin: set HORNERO_PLUGIN_QML to the build's `qml` directory. Skipped
otherwise (CI has no Quickshell). Renders land in the pytest temp dir; set
HORNERO_RENDER_OUT to keep them (evidence).
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
PLUGIN = os.environ.get("HORNERO_PLUGIN_QML", "")

pytestmark = pytest.mark.skipif(
    not PLUGIN or not Path(PLUGIN, "Hornero/Internal").is_dir()
    or shutil.which("qs") is None or shutil.which("dbus-run-session") is None or shutil.which("rsync") is None,
    reason="needs HORNERO_PLUGIN_QML (plugin build), quickshell, dbus-run-session and rsync",
)


@pytest.fixture(scope="module")
def tree(tmp_path_factory):
    base = tmp_path_factory.mktemp("dashrender")
    dest = base / "tree"
    subprocess.run(["bash", str(RENDER / "build-dash.sh"), str(ROOT), str(dest)], check=True, capture_output=True)
    return base, dest


def render(tree, name, overrides, w, h, playing):
    base, dest = tree
    out_dir = Path(os.environ.get("HORNERO_RENDER_OUT") or base)
    out_dir.mkdir(parents=True, exist_ok=True)
    preset = base / f"{name}.json"
    preset.write_text(json.dumps(overrides))
    out = out_dir / f"{name}.png"
    env = dict(os.environ, HORNERO_SCRATCH=str(base), QML2_IMPORT_PATH=PLUGIN)
    if playing:
        env["DECK_PLAYER"] = "1"
    else:
        env.pop("DECK_PLAYER", None)
    subprocess.run(["bash", str(RENDER / "render.sh"), str(dest), str(preset), "-", "-", str(w), str(h), "1", str(out)],
                   check=True, capture_output=True, env=env)
    log = Path(f"{out}.log").read_text(errors="replace")
    m = re.search(r"DASHPROBE (\{.*\})", log)
    assert m, f"no DASHPROBE line:\n{log[-3000:]}"
    assert out.exists() and out.stat().st_size > 0
    return json.loads(m.group(1)), out, log


@pytest.mark.parametrize("playing", [True, False], ids=["playing", "idle"])
def test_classic_strip_deck_renders(tree, playing):
    data, out, log = render(tree, f"deck-strip-{'playing' if playing else 'idle'}",
                            {"dashboard": {"composition": "classic"}}, 1366, 768, playing)
    assert "SpectrumMeter" not in log or "is not a type" not in log, log[-2000:]
    assert data["w"] <= 1366 - 32 and data["h"] <= 768 - 32, data
