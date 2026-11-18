"""The drawer panels and the bar popout surface must not bind in a cycle.

Shell 1.3.1 logged `Binding loop detected for property "placement"` (QML
Wrapper at modules/drawers/Panels.qml) at startup: Panels bound the popout's
machined fillet to `popouts.edge`, which is derived from the solved
`placement`, so the fillet became a dependent of the placement while the
placement was being evaluated. The fillet is now keyed on the owning bar's
edge (`ownerEdge`), which is known before placement.

The static test pins that no Panels binding on the popout surface reads its
solved placement. The runtime test loads the real Panels.qml (every drawer
wrapper and the real bar popout surface) offscreen next to a stand-in bar on
each edge, opens a popout, and fails on any binding-loop warning. It is
skipped, never faked, without quickshell. The full shell load gate
(tests/test_full_shell_loads.py) rejects binding loops too.
"""
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from chromatic_ui_harness import QS, ROOT, _strip_panel_windows, requires_qs


def _block(source: str, opener: str) -> str:
    start = source.index(opener)
    depth = 0
    for i in range(source.index("{", start), len(source)):
        depth += {"{": 1, "}": -1}.get(source[i], 0)
        if depth == 0:
            return source[start:i + 1]
    raise AssertionError(f"unterminated {opener}")


def test_popout_bindings_in_panels_never_read_the_solved_placement():
    block = _block((ROOT / "modules/drawers/Panels.qml").read_text(), "BarPopouts.Wrapper {")
    code = "\n".join(ln for ln in block.splitlines() if not ln.strip().startswith("//"))
    # Anything AnchoredSurface derives from `placement` (edge, target, side).
    for derived in ("popouts.edge", "popouts.placement", "popouts.target", "root.popouts.edge"):
        assert derived not in code, derived
    assert "fillet: root.bar.filletOn(popouts.ownerEdge)" in code
    assert "filletRule: root.bar.filletRule(popouts.ownerEdge)" in code
    wrapper = (ROOT / "modules/bar/popouts/Wrapper.qml").read_text()
    # ownerEdge comes from the owner spec or the config, never from placement.
    line = next(ln for ln in wrapper.splitlines() if "property string ownerEdge:" in ln)
    assert "placement" not in line and "edge:" not in line.split("ownerEdge:", 1)[1]


def _run(tmp: Path, edge: str) -> str:
    root = tmp / "root"

    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__", "assets"}]

    shutil.copytree(ROOT, root, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    os.symlink(ROOT / "assets", root / "assets")
    _strip_panel_windows(root)
    shutil.copy(ROOT / "tests/qml/panels_loops/harness.qml", root / "shell.qml")
    xdg = tmp / "xdg"
    for sub in ("config/hornero", "state/hornero", "data/hornero", "cache", "home", "rt"):
        (xdg / sub).mkdir(parents=True)
    (xdg / "rt").chmod(0o700)
    (xdg / "config/hornero/shell.json").write_text((ROOT / "config/shell.default.json").read_text())
    env = {
        "PATH": os.environ["PATH"],
        "XDG_CONFIG_HOME": str(xdg / "config"), "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"), "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": str(xdg / "rt"), "HOME": str(xdg / "home"),
        "QML2_IMPORT_PATH": os.pathsep.join(filter(None, [str(root / "plugin" / "qml"), os.environ.get("HORNERO_PLUGIN_QML", "")])),
        "QT_QPA_PLATFORM": "offscreen", "LIBGL_ALWAYS_SOFTWARE": "1", "PL_EDGE": edge,
        "GIO_USE_VFS": "local", "GVFS_DISABLE_FUSE": "1",
    }
    try:
        proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
                              capture_output=True, text=True, timeout=120, env=env, cwd=tmp)
        out = proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode(errors="replace") + (e.stderr or b"").decode(errors="replace")
    shutil.rmtree(root, ignore_errors=True)
    return re.sub(r"\x1b\[[0-9;]*m", "", out)


@requires_qs
@pytest.mark.parametrize("edge", ["top", "bottom", "left", "right"])
def test_panels_and_popouts_load_without_binding_loops(tmp_path, edge):
    if shutil.which("dbus-run-session") is None:
        pytest.skip("NOT RUN: dbus-run-session is not installed")
    log = _run(tmp_path, edge)
    assert "PANELS-DONE" in log, log[-3000:]
    done = next(ln for ln in log.splitlines() if "PANELS-DONE" in ln)
    assert '"attached":true' in done and f'"edge":"{edge}"' in done and '"fillet":6' in done, done
    loops = [ln for ln in log.splitlines() if "Binding loop detected" in ln]
    assert not loops, "\n".join(loops[:20])
