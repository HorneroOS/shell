"""Signal mode bar instrumentation (shell#511): contracts for the bar scope."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODE = (ROOT / "modules/bar/components/ModeIndicator.qml").read_text()
SCOPE = (ROOT / "modules/bar/components/BarScope.qml").read_text()


def test_instrumentation_is_signal_only_and_horizontal():
    assert "readonly property bool instrumented: Experience.immersive && !root.vertical" in MODE
    assert "visible: root.instrumented" in MODE
    assert "model: root.instrumented ? 4 : 0" in MODE  # corner brackets


def test_scope_plots_real_samples_and_respects_the_glow_budget():
    assert "buffer.sample(SystemUsage.cpuPerc)" in SCOPE
    assert "Experience.acquireGlow(root, 1)" in SCOPE and "Experience.releaseGlow(root)" in SCOPE
    assert "Experience.glow" in SCOPE
    assert "layer.enabled" not in SCOPE  # no offscreen layer for a 2 px glow
    assert "Experience.telemetryPaused" in SCOPE  # pauses over fullscreen/gaming
    assert "Ref {" in SCOPE and "service: SystemUsage" in SCOPE


def test_scope_fits_thin_bars():
    assert "Density.inner" in SCOPE and "implicitWidth: 56" in SCOPE
