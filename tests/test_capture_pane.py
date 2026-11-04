"""Capture pane contract: horneroctl capture status + existing leaves only.

The pane (shell#237) surfaces the read-only `capture status` report and
runs the already-existing screenshot/record leaves; it must never invent
settings the backend cannot honour, shell out through a shell string, or
show recording controls without the recorder backend.
"""
from pathlib import Path

ROOT = Path(__file__).parent.parent
PANE = (ROOT / "modules/controlcenter/capture/CapturePane.qml").read_text()
REGISTRY = (ROOT / "modules/controlcenter/PaneRegistry.qml").read_text()
PANES = (ROOT / "modules/controlcenter/Panes.qml").read_text()


def test_capture_pane_registered_and_imported():
    assert '"capture/CapturePane.qml"' in REGISTRY
    assert 'readonly property string id: "capture"' in REGISTRY
    assert 'import "capture"' in PANES


def test_capture_pane_binds_to_capture_status_fields():
    assert '["horneroctl", "capture", "status", "--json"]' in PANE
    for field in ("screenshot_backend_present", "recorder_backend_present",
                  "recorder_running", "recorder_paused",
                  "recorder_current_file", "pictures_dir", "recordings_dir"):
        assert field in PANE, field


def test_capture_actions_are_existing_leaves_with_yes():
    for argv in ('"capture", "screenshot", "--yes"',
                 '"capture", "screenshot", "--region", "--yes"',
                 '"capture", "record", "start", "--yes"',
                 '"capture", "record", "pause", "--yes"',
                 '"capture", "record", "stop", "--yes"'):
        assert argv in PANE, argv
    for forbidden in ("sh -c", "bash -c", "execDetached", "pkexec", "grim", "slurp"):
        assert forbidden not in PANE, forbidden


def test_capture_controls_gate_on_backend_presence():
    # No decorative controls: screenshot buttons need the screenshot
    # backend, recording buttons need gpu-screen-recorder and follow
    # the live recorder state.
    assert "enabled: root.screenshotPresent" in PANE
    assert "visible: root.recorderPresent && !root.recording" in PANE
    assert "visible: root.recorderPresent && root.recording" in PANE
    assert "never shows a control the backend cannot honour" in PANE
