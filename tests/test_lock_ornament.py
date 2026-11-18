"""Lock screen: no stray diagonal line (host report on hornero-shell 1.3.0).

The Signal Bezel lock (shell#493) drew a 45° "La Plata" hairline that ran
from the exact bottom-left screen corner and was hard-clipped in mid-air at
the edge of the strip beside the centre column. On a real 1920x1080 output
it read as a rendering glitch (a stray line from the corner to the middle
left), not as an ornament. The ornament is now opt-in
(`lock.diagonalRule`, Control Center > Lock screen) and, when on, is a
fixed-length segment that fades out at both ends instead of touching the
screen corner or ending on a clip edge.

The real lock composition (modules/lock/Content.qml) is rendered offscreen
by tests/qml/lock_ornament/harness.qml when quickshell is installed
(skipped, never faked, otherwise). LOCK_ORNAMENT_SHOTS=<dir> keeps the
renders.
"""
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from chromatic_ui_harness import _strip_panel_windows

ROOT = Path(__file__).resolve().parent.parent
QS = shutil.which("qs")
W, H = 1920, 1080


def test_ornament_is_an_opt_in_setting():
    cfg = (ROOT / "config" / "LockConfig.qml").read_text()
    assert "property bool diagonalRule: false" in cfg
    assert json.loads((ROOT / "config" / "shell.default.json").read_text())["lock"]["diagonalRule"] is False
    assert "diagonalRule: lock.diagonalRule" in (ROOT / "config" / "Config.qml").read_text()
    pane = (ROOT / "modules/controlcenter/lockscreen/LockScreenPane.qml").read_text()
    assert "Config.lock.diagonalRule = checked" in pane
    content = (ROOT / "modules/lock/Content.qml").read_text()
    assert "active: Config.lock.diagonalRule" in content


# ---- offscreen renders ----

def _build(dest: Path) -> Path:
    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__", "assets"}]

    shutil.copytree(ROOT, dest, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    os.symlink(ROOT / "assets", dest / "assets")
    _strip_panel_windows(dest)
    shutil.copy(ROOT / "tests/atspi/lockstub/Pam.qml", dest / "modules/lock/Pam.qml")
    shutil.copy(ROOT / "tests/qml/lock_ornament/harness.qml", dest / "shell.qml")
    return dest


@pytest.fixture(scope="module")
def renders(tmp_path_factory):
    if not QS or shutil.which("dbus-run-session") is None:
        pytest.skip("NOT RUN: quickshell (qs) or dbus-run-session is not installed")
    pytest.importorskip("PIL.Image")
    base = tmp_path_factory.mktemp("lockorn")
    root = _build(base / "root")
    xdg = base / "xdg"
    for sub in ("config/hornero", "state/hornero", "data/hornero", "cache", "home", "rt"):
        (xdg / sub).mkdir(parents=True)
    (xdg / "rt").chmod(0o700)
    (xdg / "config/hornero/shell.json").write_text((ROOT / "config/shell.default.json").read_text())
    shots = Path(os.environ["LOCK_ORNAMENT_SHOTS"]) if os.environ.get("LOCK_ORNAMENT_SHOTS") else base / "shots"
    shots.mkdir(parents=True, exist_ok=True)
    env = {
        "PATH": os.environ["PATH"],
        "XDG_CONFIG_HOME": str(xdg / "config"), "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"), "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": str(xdg / "rt"), "HOME": str(xdg / "home"),
        "QML2_IMPORT_PATH": os.pathsep.join(filter(None, [str(root / "plugin" / "qml"), os.environ.get("HORNERO_PLUGIN_QML", "")])),
        "QT_QPA_PLATFORM": "offscreen", "LIBGL_ALWAYS_SOFTWARE": "1",
        "LO_OUT": str(shots), "LO_W": str(W), "LO_H": str(H),
        "GIO_USE_VFS": "local", "GVFS_DISABLE_FUSE": "1",
    }
    proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
                          capture_output=True, text=True, timeout=180, env=env, cwd=base)
    log = re.sub(r"\x1b\[[0-9;]*m", "", proc.stdout + proc.stderr)
    (shots / "harness.log").write_text(log)
    lines = [ln for ln in log.splitlines() if "LOCKORN {" in ln]
    assert lines, f"harness never reported:\n{log[-3000:]}"
    report = json.loads(lines[-1].split("LOCKORN ", 1)[1])
    return {s["name"]: s for s in report["scenes"]}, shots


def _lum(img):
    return img.convert("L").load()


def _diagonal_spike(path: Path, x0: int, x1: int) -> tuple[float, int]:
    """Strongest 45° (bottom-left to top-right) straight line in the empty
    band left of the centre column: the mean luminance along each line
    x + y = c against the lines 3 px either side. A 1 px hairline shows up
    as a spike; the flat ground, the lamp wash and the grain do not."""
    from PIL import Image

    img = Image.open(path)
    px = _lum(img)
    w, h = img.size

    def mean(c):
        vals = [px[x, c - x] for x in range(x0, x1) if 0 <= c - x < h]
        return sum(vals) / len(vals) if vals else 0.0

    best, where = 0.0, -1
    for c in range(x0 + 40, h + x1 - 40):
        spike = abs(mean(c) - (mean(c - 3) + mean(c + 3)) / 2)
        if spike > best:
            best, where = spike, c
    return best, where


@pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")
def test_default_lock_draws_no_stray_diagonal(renders):
    report, _ = renders
    # 0..560 is clear of the centre column on 1920 px (the column is at
    # least 520 px wide plus padding); the bottom-left footer cards are
    # absent offscreen (no weather, no player).
    spike, c = _diagonal_spike(Path(report["default"]["png"]), 0, 560)
    assert spike < 1.5, f"stray 45° line along x + y = {c} (spike {spike:.2f})"


@pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")
def test_opt_in_ornament_is_a_faded_segment_off_the_corner(renders):
    from PIL import Image

    report, _ = renders
    on = report["ornament-on"]
    assert on["hasSetting"], "tree has no lock.diagonalRule setting"
    spike, c = _diagonal_spike(Path(on["png"]), 0, 560)
    assert spike >= 1.5, f"opted-in ornament not drawn (spike {spike:.2f})"
    px = _lum(Image.open(on["png"]))

    def contrast(xs):
        # Mean contrast of the line pixel against pixels 4 px either side,
        # averaged over a run so the atmosphere grain (up to ~6 levels per
        # pixel) cannot pass for a line.
        vals = [abs(px[x, c - x] - (px[min(W - 1, x + 4), c - x] + px[max(0, x - 4), c - x]) / 2) for x in xs]
        return sum(vals) / len(vals)

    # The segment lies on x + y = H but starts well inside the screen and
    # fades in: nothing within 60 px of the corner, clearly drawn along
    # its middle.
    assert c in range(H - 3, H + 4), f"ornament moved off its diagonal (x + y = {c})"
    assert contrast(range(0, 60)) < 5, "ornament reaches the screen corner"
    assert contrast(range(250, 450)) >= 10, "ornament invisible along its middle"
