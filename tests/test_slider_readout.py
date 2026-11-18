"""Slider handle readout (signal-visual-language §6.2, appearance.sliders).

The segmented slider's handle cap shows a Hornero Glyph at rest and the
value in Plex Mono while it is dragged, scrolled or stepped; motion off swaps
instantly; the accessible value is unchanged. Static wiring always runs;
tests/qml/sliderreadout/harness.qml renders real SegmentSliders offscreen
when quickshell is installed (skipped, never faked, otherwise).
SLIDER_SHOTS=<dir> keeps the frames.
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


def test_readout_is_customisable_with_reset():
    cfg = _read("config/AppearanceConfig.qml")
    assert "property bool readout: true" in cfg and "property int readoutHold: 900" in cfg
    sliders = json.loads(_read("config/shell.default.json"))["appearance"]["sliders"]
    assert sliders == {"readout": True, "readoutHold": 900}
    assert "readoutHold: appearance.sliders.readoutHold" in _read("config/Config.qml")
    ranges = json.loads(_read("config/ranges.json"))["ranges"]
    assert ranges["appearance.sliders.readoutHold"] == {"min": 300, "max": 3000, "step": 100, "default": 900}
    pane = _read("modules/controlcenter/osd/OsdPane.qml")
    assert 'qsTr("Show the value on the handle")' in pane and "Config.appearance.sliders.readout = true" in pane


def test_handle_cap_contract():
    src = _read("modules/instruments/SegmentSlider.qml")
    assert "mono: true" in src and "Signal.palette.signal" in src and "Signal.palette.onSignal" in src
    assert "Glyph {" in src and 'property string glyph: vertical ? "grip-horizontal" : "grip-vertical"' in src
    assert "enabled: Choreography.animated" in src  # motion off: instant swap
    assert "Accessible.ignored: true" in src
    # The Slider role and its value text are unchanged.
    assert "Accessible.role: Accessible.Slider" in src
    assert "Accessible.description: `${Math.round(root.value * 100)} %`" in src
    osd = _read("modules/osd/Content.qml")
    assert osd.count("readoutOnChange: true") == 3
    media = _read("modules/dashboard/Media.qml")
    assert "valueText: root.timecode(" in media and "seek.nudge();" in media


@pytest.fixture(scope="module")
def probes(tmp_path_factory):
    if not QS or shutil.which("dbus-run-session") is None:
        pytest.skip("NOT RUN: quickshell (qs) or dbus-run-session is not installed")
    base = tmp_path_factory.mktemp("sliderreadout")
    shots = Path(os.environ["SLIDER_SHOTS"]) if os.environ.get("SLIDER_SHOTS") else base / "shots"
    root = base / "root"

    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__", "assets"}]

    shutil.copytree(ROOT, root, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    os.symlink(ROOT / "assets", root / "assets")
    _strip_panel_windows(root)
    shutil.copy(ROOT / "tests/qml/sliderreadout/harness.qml", root / "shell.qml")
    xdg = base / "xdg"
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
        "QT_QPA_PLATFORM": "offscreen", "LIBGL_ALWAYS_SOFTWARE": "1", "SR_OUT": str(shots),
        "GIO_USE_VFS": "local", "GVFS_DISABLE_FUSE": "1",
    }
    try:
        proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
                              capture_output=True, text=True, timeout=120, env=env, cwd=base)
        out = proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode(errors="replace") + (e.stderr or b"").decode(errors="replace")
    log = re.sub(r"\x1b\[[0-9;]*m", "", out)
    (shots / "harness.log").write_text(log)
    lines = [ln for ln in log.splitlines() if "SLIDER " in ln]
    assert lines, f"harness never reported:\n{log[-3000:]}"
    return json.loads(lines[-1].split("SLIDER ", 1)[1])


requires_qs = pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")


def _shown(cap, mono: bool):
    """The visible text on the cap: the readout (mono) or the glyph."""
    texts = [t for t in cap["texts"] if t["opacity"] > 0.95]
    assert len(texts) == 1, cap["texts"]
    return texts[0]


@requires_qs
def test_rest_shows_a_glyph_on_the_handle(probes):
    for key in ("vol", "seek"):
        s = probes["rest"][key]
        assert s["reading"] is False and s["cap"]["visible"]
        shown = _shown(s["cap"], False)
        assert "Mono" not in shown["family"], shown


@requires_qs
def test_adjusting_turns_the_handle_into_the_value(probes):
    vol = probes["reading"]["vol"]
    assert vol["reading"] and vol["valueText"] == "85"
    shown = _shown(vol["cap"], True)
    assert shown["text"] == "85" and "Mono" in shown["family"], shown
    seek = probes["reading"]["seek"]
    assert seek["reading"] and _shown(seek["cap"], True)["text"] == "1:23"
    # The cap rides the fill edge: 0.85 of 1.5 up the 98 px OSD meter
    # (20 segments of 3 px with 2 px gaps, the default 150 px OSD slot).
    edge = (1 - 0.85 / 1.5) * 98
    assert abs(vol["cap"]["y"] + vol["cap"]["h"] / 2 - edge) < 1, vol["cap"]
    # The accessible value is the same text as before.
    assert vol["a11yDescription"] == "85 %"


@requires_qs
def test_value_returns_to_the_glyph_after_the_hold(probes):
    for key in ("vol", "seek"):
        assert probes["afterHold"][key]["reading"] is False


@requires_qs
def test_motion_off_swaps_instantly(probes):
    vol = probes["offInstant"]["vol"]
    assert vol["reading"]
    assert _shown(vol["cap"], True)["text"] == "120"


@requires_qs
def test_readout_can_be_turned_off(probes):
    vol = probes["readoutDisabled"]["vol"]
    assert vol["reading"] is False
