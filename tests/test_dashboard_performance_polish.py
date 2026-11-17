"""Dashboard Performance polish (VA-13): honest scopes, readable names,
level column bottoms, one-line idle Media."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _src(rel: str) -> str:
    return (ROOT / rel).read_text()


def test_scopes_say_collecting_until_the_window_is_full():
    scope = _src("modules/instruments/ScopeTrace.qml")
    assert "samples.length < window" in scope and "Collecting %1 / %2 s" in scope
    perf = _src("modules/dashboard/Performance.qml")
    assert perf.count("secondsPerSample: Experience.telemetryIntervalMs / 1000") == 2


def test_long_hardware_names_are_shortened_not_cut():
    perf = _src("modules/dashboard/Performance.qml")
    assert "function shortName(name: string)" in perf
    assert "root.shortName(SystemUsage.cpuName)" in perf and "root.shortName(SystemUsage.gpuName)" in perf


def test_columns_end_on_the_same_line():
    perf = _src("modules/dashboard/Performance.qml")
    assert "Layout.fillHeight: !root.anyGpu" in perf
    assert "Layout.fillHeight: !root.anyBattery" in perf
    assert perf.count("Layout.alignment: Qt.AlignTop\n            visible: root.has") == 0


def test_idle_media_is_one_line():
    media = _src("modules/dashboard/Media.qml")
    assert "visible: !root.hasPlayer" in media and "visible: root.hasPlayer" in media
    assert "root.hasPlayer ? deck.implicitHeight : idle.implicitHeight" in media
