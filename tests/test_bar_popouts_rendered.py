"""Real bar popouts rendered offscreen on all four bar edges (shell#537, #512, #513, #582).

The placement solver has its own exhaustive tests; this renders the real popout
surface (modules/bar/popouts/Wrapper.qml: AnchoredSurface, SurfaceFrame,
Content and the native pages) opened from a trigger on a bar slab at the top,
bottom, left and right, attached and floating, and measures what the screen
would show: the frame against the bar and the screen, the notch against its
trigger, text that is elided or painted past the surface, and what a closed
popout leaves behind. Skipped, never faked, without quickshell.
"""
import json
import os
import re
import shutil
import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest

from chromatic_ui_harness import QS, ROOT, _strip_panel_windows, requires_qs

SW, SH = 1280, 800
THICKNESS = 40
FLOATING_GAP = 8  # the bar's own margin from the screen edge
SURFACE_GAP = 4  # visual language 7: popout to bar
EDGES = ("top", "bottom", "left", "right")
STYLES = ("attached", "floating")
POPOUTS = ("audio", "battery")
EXTRA = [("top", "attached", "network"), ("top", "attached", "bluetooth"),
         ("bottom", "floating", "kblayout"), ("top", "floating", "lockstatus")]
CASES = [(e, s, n) for e in EDGES for s in STYLES for n in POPOUTS] + EXTRA


def render(tmp: Path, edge: str, style: str, name: str, out: Path | None = None, closed: Path | None = None) -> dict:
    root = tmp / "root"

    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__", "assets"}]

    shutil.copytree(ROOT, root, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    os.symlink(ROOT / "assets", root / "assets")
    _strip_panel_windows(root)
    shutil.copy(ROOT / "tests" / "qml" / "popouts" / "harness.qml", root / "shell.qml")
    xdg = tmp / "xdg"
    for sub in ("config/hornero", "state/hornero", "data/hornero", "cache", "home", "rt"):
        (xdg / sub).mkdir(parents=True)
    (xdg / "rt").chmod(0o700)
    (xdg / "config" / "hornero" / "shell.json").write_text((ROOT / "config" / "shell.default.json").read_text())
    env = {
        "PATH": os.environ["PATH"],
        "XDG_CONFIG_HOME": str(xdg / "config"), "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"), "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": str(xdg / "rt"), "HOME": str(xdg / "home"),
        "QML2_IMPORT_PATH": os.pathsep.join(filter(None, [str(root / "plugin" / "qml"), os.environ.get("HORNERO_PLUGIN_QML", "")])),
        "QT_QPA_PLATFORM": "offscreen", "LIBGL_ALWAYS_SOFTWARE": "1",
        "PO_EDGE": edge, "PO_STYLE": style, "PO_NAME": name, "PO_W": str(SW), "PO_H": str(SH),
    }
    if out:
        env["PO_OUT"] = str(out)
    if closed:
        env["PO_CLOSED"] = str(closed)
    proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
                          capture_output=True, text=True, timeout=120, env=env, cwd=tmp)
    log = re.sub(r"\x1b\[[0-9;]*m", "", proc.stdout + proc.stderr)
    shutil.rmtree(root, ignore_errors=True)
    lines = [ln for ln in log.splitlines() if "POPO " in ln]
    assert lines, f"harness never reported:\n{log[-2500:]}"
    return json.loads(lines[-1].split("POPO ", 1)[1])


@pytest.fixture(scope="module")
def reports(tmp_path_factory):
    if not QS:
        pytest.skip("NOT RUN: quickshell (qs) is not installed")
    base = tmp_path_factory.mktemp("popouts")

    def one(case):
        edge, style, name = case
        tmp = base / f"{edge}-{style}-{name}"
        tmp.mkdir()
        shot = Path(os.environ["POPOUT_SHOTS"]) / f"{edge}-{style}-{name}" if os.environ.get("POPOUT_SHOTS") else None
        return case, render(tmp, edge, style, name,
                            Path(f"{shot}.png") if shot else None,
                            Path(f"{shot}-closed.png") if shot else None)

    with ThreadPoolExecutor(4) as pool:
        return dict(pool.map(one, CASES))


@requires_qs
@pytest.mark.parametrize("case", CASES, ids=lambda c: "-".join(c))
def test_no_popout_text_is_truncated_or_painted_past_its_surface(reports, case):
    assert reports[case]["open"]["issues"] == []


@requires_qs
@pytest.mark.parametrize("case", CASES, ids=lambda c: "-".join(c))
def test_frame_sits_against_its_bar_inside_the_screen(reports, case):
    edge, style, _ = case
    o = reports[case]["open"]
    x, y, w, h = o["target"]
    assert o["phase"] in ("open", "opening") and w > 0 and h > 0
    assert x >= 0 and y >= 0 and x + w <= SW and y + h <= SH, o["target"]
    inset = THICKNESS + (FLOATING_GAP if style == "floating" else 0)
    gap = 0 if style == "attached" else SURFACE_GAP
    # Distance from the bar's inner edge to the frame, along the bar's axis.
    distance = {"top": y - inset, "bottom": (SH - inset) - (y + h),
                "left": x - inset, "right": (SW - inset) - (x + w)}[edge]
    assert abs(distance - gap) < 0.5, (distance, gap, o["target"])
    assert o["attached"] is (style == "attached")


@requires_qs
@pytest.mark.parametrize("case", CASES, ids=lambda c: "-".join(c))
def test_notch_is_exactly_as_wide_as_its_trigger_and_aligned_with_it(reports, case):
    edge = case[0]
    o = reports[case]["open"]
    visible, start, length = o["notch"]
    tx, ty, tw, th = o["trigger"]
    fx, fy, fw, fh = o["target"]
    along_start = (tx - fx) if edge in ("top", "bottom") else (ty - fy)
    along_len = tw if edge in ("top", "bottom") else th
    assert visible
    assert abs(start - along_start) < 0.5 and abs(length - along_len) < 0.5, (o["notch"], along_start, along_len)


@requires_qs
@pytest.mark.parametrize("case", CASES, ids=lambda c: "-".join(c))
def test_a_closed_popout_leaves_nothing_behind(reports, case):
    closed = reports[case]["closed"]
    assert closed["visible"] is False and closed["frameVisible"] is False and closed["notchVisible"] is False
    assert closed["rect"][2] == 0 and closed["rect"][3] == 0, closed["rect"]


@requires_qs
def test_closed_popout_paints_no_amber_pixel_anywhere(tmp_path):
    Image = pytest.importorskip("PIL.Image")
    shot = tmp_path / "closed.png"
    render(tmp_path, "left", "attached", "audio", None, shot)
    im = Image.open(shot).convert("RGB")
    amber = [(x, y) for y in range(im.size[1]) for x in range(im.size[0])
             if (lambda p: p[0] > 180 and p[1] > 100 and p[2] < 120)(im.getpixel((x, y)))]
    assert amber == [], amber[:8]


# --- Contracts -----------------------------------------------------------------

def test_popout_headers_set_the_surface_minimum_width():
    page = (ROOT / "components/placement/SurfacePage.qml").read_text()
    assert "Math.max(contentWidth, headerWidth) + hPadding * 2" in page
    assert "id: contextText" in page


def test_power_and_audio_popouts_wrap_and_have_empty_states():
    battery = (ROOT / "modules/bar/popouts/Battery.qml").read_text()
    assert battery.count("wrapMode: Text.Wrap") >= 2 and "Power profile: %1" in battery
    audio = (ROOT / "modules/bar/popouts/Audio.qml").read_text()
    assert 'qsTr("No output device")' in audio and 'qsTr("No input device")' in audio
    assert "node.description || node.nickname || node.name" in audio
