"""Notification card physics (signal-visual-language §11.2, notifs.timeoutTick).

A swiped card is thrown on along its swipe; a timed-out card fades where it
is; siblings close the gap with `settle`; an expiring card shows a 2 px
`signal` timeout line that drains with its clock and freezes while held;
critical cards never expire and carry no line. Static wiring checks always
run; tests/qml/notifphysics/harness.qml drives the real popup stack
offscreen when quickshell is installed (skipped, never faked, otherwise).
NOTIF_SHOTS=<dir> keeps the frames.
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


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_timeout_line_is_a_customisable_default_on_setting():
    assert "property bool timeoutTick: true" in _read("config/NotifsConfig.qml")
    assert json.loads(_read("config/shell.default.json"))["notifs"]["timeoutTick"] is True
    assert "timeoutTick: notifs.timeoutTick" in _read("config/Config.qml")
    pane = _read("modules/controlcenter/notifications/NotificationsPane.qml")
    assert 'label: qsTr("Timeout line")' in pane and "Config.notifs.timeoutTick = true" in pane


def test_one_clock_per_notification_that_pauses_and_resumes():
    src = _read("services/Notifs.qml")
    assert "urgency !== NotificationUrgency.Critical" in src
    assert "function hold(item: Item)" in src and "function release(item: Item)" in src
    assert "running: !notif.held" in src
    card = _read("modules/notifications/Notification.qml")
    # The card never restarts the clock: it holds and releases it.
    assert "timer.start()" not in card and "timer.stop()" not in card
    assert "onHoldingChanged: holding ? root.modelData.hold(root) : root.modelData.release(root)" in card
    assert "color: Signal.palette.signal" in card and "height: 2" in card
    assert "Math.ceil(root.drain * 4) / 4" in card  # motion off: quarter steps


def test_exit_follows_the_swipe_and_respects_motion_levels():
    src = _read("modules/notifications/Content.qml")
    assert "wrapper.throwDir = notif.x > 0.5 ? 1 : notif.x < -0.5 ? -1 : 0" in src
    assert "Choreography.curves.exit" in src and "duration: Choreography.settle" in src
    assert 'Config.notifs.align === "left" ? -1 : 1' not in src  # the old inversion is gone


def _run(tmp: Path, shots: Path) -> dict:
    root = tmp / "root"

    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__", "assets"}]

    shutil.copytree(ROOT, root, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    os.symlink(ROOT / "assets", root / "assets")
    _strip_panel_windows(root)
    # Test copy only: let the harness build real Notifs.Notif objects.
    svc = root / "services" / "Notifs.qml"
    text = svc.read_text()
    anchor = "    Component {\n        id: notifComp\n"
    assert anchor in text, "Notifs notifComp changed; update the harness"
    svc.write_text(text.replace(anchor, "    readonly property Component harnessNotifComp: notifComp\n\n" + anchor, 1))
    # The rounded clipping wrappers are shader effects the offscreen software
    # renderer leaves blank; plain clipped rectangles keep the same geometry.
    content = root / "modules" / "notifications" / "Content.qml"
    ctext = content.read_text()
    for kind in ("ClippingWrapperRectangle {", "ClippingRectangle {"):
        assert kind in ctext, kind
        ctext = ctext.replace(kind, "Rectangle {\n        clip: true")
    content.write_text(ctext)
    shutil.copy(ROOT / "tests/qml/notifphysics/harness.qml", root / "shell.qml")
    xdg = tmp / "xdg"
    for sub in ("config/hornero", "state/hornero", "data/hornero", "cache", "home", "rt"):
        (xdg / sub).mkdir(parents=True)
    (xdg / "rt").chmod(0o700)
    (xdg / "config/hornero/shell.json").write_text(_read("config/shell.default.json"))
    shots.mkdir(parents=True, exist_ok=True)
    env = {
        "PATH": os.environ["PATH"],
        "XDG_CONFIG_HOME": str(xdg / "config"), "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"), "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": str(xdg / "rt"), "HOME": str(xdg / "home"),
        "QML2_IMPORT_PATH": os.pathsep.join(filter(None, [str(root / "plugin" / "qml"), os.environ.get("HORNERO_PLUGIN_QML", "")])),
        "QT_QPA_PLATFORM": "offscreen", "LIBGL_ALWAYS_SOFTWARE": "1", "NP_OUT": str(shots),
        "GIO_USE_VFS": "local", "GVFS_DISABLE_FUSE": "1",
    }
    try:
        proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
                              capture_output=True, text=True, timeout=int(os.environ.get("NOTIF_TIMEOUT", "120")), env=env, cwd=tmp)
        out = proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode(errors="replace") + (e.stderr or b"").decode(errors="replace")
    log = re.sub(r"\x1b\[[0-9;]*m", "", out)
    (shots / "harness.log").write_text(log)
    lines = [ln for ln in log.splitlines() if "NOTIF " in ln]
    assert lines, f"harness never reported:\n{log[-3000:]}"
    return json.loads(lines[-1].split("NOTIF ", 1)[1])


@pytest.fixture(scope="module")
def probes(tmp_path_factory):
    if not QS or shutil.which("dbus-run-session") is None:
        pytest.skip("NOT RUN: quickshell (qs) or dbus-run-session is not installed")
    base = tmp_path_factory.mktemp("notifphysics")
    shots = Path(os.environ["NOTIF_SHOTS"]) if os.environ.get("NOTIF_SHOTS") else base / "shots"
    return _run(base, shots)


def _cards(p, name):
    return {c["key"]: c for c in p[name]["cards"]}


requires_qs = pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")


@requires_qs
def test_line_drains_with_the_clock_and_critical_has_none(probes):
    mid = _cards(probes, "midway")
    # 3 s into a 6 s timeout: about half left (frame timing slack).
    assert 0.35 < mid["a"]["drain"] < 0.65, mid["a"]
    assert mid["a"]["tick"] and mid["b"]["tick"]
    assert mid["crit"]["tick"] is False
    after = _cards(probes, "afterTimeout")
    assert after["crit"]["popup"] is True  # critical never expires


@requires_qs
def test_line_freezes_while_held_and_resumes(probes):
    h0 = _cards(probes, "held0")["a"]
    h1 = _cards(probes, "held1")
    assert h1["a"]["held"] and abs(h1["a"]["drain"] - h0["drain"]) < 0.02, (h0, h1["a"])
    assert abs(h1["a"]["left"] - h0["left"]) < 1
    # The other card kept running meanwhile.
    assert h1["b"]["drain"] < h0["drain"] - 0.1
    rel = _cards(probes, "released")["a"]
    assert not rel["held"] and rel["drain"] < h1["a"]["drain"] - 0.05


def _xs(frames):
    return [f["a"]["x"] for f in frames if f["a"]["card"]]


@requires_qs
def test_thrown_cards_leave_in_the_swipe_direction(probes):
    right = _xs(probes["throwRight"])
    assert right and max(right) > 300, right  # travels about a card width on
    assert all(b >= a - 0.5 for a, b in zip(right, right[1:])), right
    left = _xs(probes["throwLeft"])
    assert left and min(left) < -300, left
    assert all(b <= a + 0.5 for a, b in zip(left, left[1:])), left


@requires_qs
def test_siblings_close_the_gap_with_settle(probes):
    ys = [f["s"]["y"] for f in probes["throwRight"] if f["s"] and f["s"]["card"]]
    # The card below the thrown one moves up, over several frames.
    assert ys[-1] < ys[0] - 20, ys
    assert len({round(y) for y in ys}) > 3, ys


@requires_qs
def test_timed_out_card_fades_in_place(probes):
    frames = [f for f in probes["timeout"] if f["a"]["card"]]
    assert frames, probes["timeout"]
    assert all(abs(f["a"]["x"]) < 0.5 for f in frames), frames
    assert _cards(probes, "afterTimeout")["short"]["card"] is False


@requires_qs
def test_reduced_and_off_motion(probes):
    red = _xs(probes["throwReduced"])
    assert red and max(red) <= 160 + 4.5, red  # 4 px of travel, no throw
    off = _xs(probes["throwOff"])
    assert not off or max(off) <= 160.5, off
    d = _cards(probes, "offDrain")["off"]["drain"]
    assert d > 0.5  # ~1 s into 4 s


@requires_qs
def test_line_can_be_turned_off(probes):
    c = _cards(probes, "noTick")
    assert c["notick"]["tick"] is False
