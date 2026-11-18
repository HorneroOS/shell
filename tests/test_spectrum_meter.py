"""SpectrumMeter (item 7 of the Caelestia recovery): one scene-graph item
per spectrum with VU ballistics that sleeps once it settles.

Static checks always run. The offscreen probe needs a build of this
branch's plugin: set HORNERO_PLUGIN_QML to the build's `qml` directory
(e.g. `<build>/qml`) and have the Qt 6 `qml` runtime on PATH; it is skipped
otherwise. The ballistics maths has its own QtTest suite (ctest:
spectrum-unit, tests/spectrum/unit/test_spectrum.cpp).
"""

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
INTERNAL = ROOT / "plugin/src/Hornero/Internal"
USERS = [ROOT / "modules/background/Visualiser.qml", ROOT / "modules/dashboard/Media.qml"]


def test_meter_is_registered_with_the_internal_module_and_ctest():
    cmake = (INTERNAL / "CMakeLists.txt").read_text()
    assert "spectrummeter.hpp spectrummeter.cpp" in cmake
    assert "spectrumballistics.hpp spectrumballistics.cpp" in cmake
    unit = (ROOT / "tests/spectrum/CMakeLists.txt").read_text()
    assert "add_test(NAME spectrum-unit" in unit
    ci = (ROOT / ".github/workflows/ci.yml").read_text()
    assert re.search(r"ctest .*-R \"?[^\n]*spectrum", ci), "CI must run the spectrum-unit ctest"


def test_ballistics_use_attack_decay_and_peak_hold():
    src = (INTERNAL / "spectrumballistics.cpp").read_text()
    hdr = (INTERNAL / "spectrumballistics.hpp").read_text()
    assert "1.0 - std::exp(-dtMs / tauMs)" in src
    assert "attackMs = 30.0" in hdr and "decayMs = 300.0" in hdr and "peakHoldMs = 600.0" in hdr


def test_meter_sleeps_when_settled():
    src = (INTERNAL / "spectrummeter.cpp").read_text()
    tick = src.split("void SpectrumMeter::tick(int timeMs)", 1)[1].split("\n}\n", 1)[0]
    assert "if (!moving)" in tick and "sleep();" in tick
    # The frame clock is an animation on the driver that only runs while awake.
    assert "m_clock.start()" in src and "m_clock.stop()" in src


def test_users_draw_one_item_not_a_repeater_per_band():
    for path in USERS:
        text = path.read_text()
        assert "Instruments.Spectrum" in text, path
        assert not re.search(r"Repeater\s*\{[^}]*visualiserBars", text, re.S), f"{path} still repeats per band"
        assert "SegmentMeter" not in text.split("Instruments.Spectrum", 1)[1].split("component ", 1)[0], path


def test_media_tab_samples_only_while_playing():
    text = (ROOT / "modules/dashboard/Media.qml").read_text()
    assert "service: root.playing && root.visibilities.dashboard ? Audio.cava : null" in text


def test_wrapper_respects_motion_and_has_an_accessible_name():
    text = (ROOT / "modules/instruments/Spectrum.qml").read_text()
    assert "animated: Choreography.animated" in text
    assert "Accessible.name: qsTr(" in text
    assert "Signal.palette.phosphor" in text and "Signal.palette.signal" in text


def test_cava_skips_the_fft_on_drained_silence():
    src = (ROOT / "plugin/src/Hornero/Services/cavaprovider.cpp").read_text()
    process = src.split("void CavaProcessor::process()", 1)[1]
    skip = process.index("if (silentIn && drained)")
    assert skip < process.index("cava_execute(")


def _plugin_qml():
    path = os.environ.get("HORNERO_PLUGIN_QML")
    if not path:
        return None
    types = Path(path, "Hornero/Internal/hornero-internal.qmltypes")
    return path if types.exists() and "SpectrumMeter" in types.read_text() else None


@pytest.mark.skipif(_plugin_qml() is None or not (shutil.which("qml6") or shutil.which("qml")),
                    reason="needs HORNERO_PLUGIN_QML (a build of this plugin) and the Qt 6 qml runtime")
def test_offscreen_meter_lights_segments_then_sleeps(tmp_path):
    Image = pytest.importorskip("PIL.Image")

    qml = shutil.which("qml6") or shutil.which("qml")
    out = tmp_path / "spectrum.png"
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_FORCE_STDERR_LOGGING="1", QML_IMPORT_PATH=_plugin_qml())
    proc = subprocess.run([qml, str(ROOT / "tests/render/spectrum-probe.qml"), "--", str(out)],
                          capture_output=True, text=True, env=env, timeout=60)
    m = re.search(r"SPECTRUMPROBE (\{.*\})", proc.stdout + proc.stderr)
    assert m, proc.stdout + proc.stderr
    r = json.loads(m.group(1))

    # Silence: the meter settles, then neither steps nor paints again.
    assert r["silentSettled"] is True
    assert r["framesLater"] == r["framesSettled"], r
    assert r["paintsLater"] == r["paintsSettled"], r
    # A steady spectrum settles too (nothing moves once levels arrive).
    assert r["playingSettled"] is True
    # Motion off: no frame clock at all.
    assert r["stillFrames"] == 0 and r["stillSettled"] is True

    img = Image.open(out).convert("RGB")
    band_w = (180 - 3 * 10) / 4

    def column(i):
        x = int(10 + i * (band_w + 10) + band_w / 2)
        return [img.getpixel((x, y)) for y in range(10, 110)]

    def count(px, colour):
        # Count segment runs of `colour` from the bottom up.
        runs, prev = 0, False
        for p in reversed(px):
            on = p == colour
            runs += on and not prev
            prev = on
        return runs

    segments = (100 + 2) // 5  # 20
    green, red, blue = (0, 255, 0), (255, 0, 0), (0, 0, 255)
    full, half, quiet, silent = (column(i) for i in range(4))
    hot = segments - int(segments * 0.85)  # segments above the threshold
    assert count(full, green) == segments - hot and count(full, red) == hot
    assert count(half, green) == round(0.5 * segments) and count(half, red) == 0
    assert count(quiet, green) == round(0.2 * segments)
    assert count(silent, green) == 0 and count(silent, red) == 0
    # Peak ticks sit above the lit stack (in the gap), one per lit band.
    assert count(half, blue) == 1 and count(silent, blue) == 0
