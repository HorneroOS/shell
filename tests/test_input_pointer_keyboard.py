"""Input pointer/keyboard contract (shell#226 slice 2): the pane's
pointer section must drive the real horneroctl hypr input backend,
read live values back from status, and hide its controls when the
compositor backend is unavailable."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANE = ROOT / "modules" / "controlcenter" / "input" / "InputPane.qml"


def pane_text() -> str:
    return PANE.read_text(encoding="utf-8")


def test_pointer_uses_hypr_input_backend() -> None:
    text = pane_text()
    assert '"horneroctl", "hypr", "input", "status", "--json"' in text
    assert '"horneroctl", "hypr", "input", "set", flag, value, "--yes", "--json"' in text


def test_all_six_settings_wired() -> None:
    text = pane_text()
    for flag in ("--sensitivity", "--accel-profile", "--repeat-rate",
                 "--repeat-delay", "--natural-scroll", "--tap-to-click"):
        assert flag in text, flag


def test_status_readback_fields() -> None:
    text = pane_text()
    for field in ("d.sensitivity", "d.accel_profile", "d.repeat_rate",
                  "d.repeat_delay", "d.natural_scroll", "d.tap_to_click",
                  "d.compositor"):
        assert field in text, field


def test_controls_gated_on_hyprland() -> None:
    text = pane_text()
    assert 'visible: root.compositor === "hyprland"' in text
    assert 'visible: root.compositor !== "hyprland"' in text


def test_layout_slice_kept() -> None:
    text = pane_text()
    assert '"hardware", "keyboard", "layout", "--toggle", "--yes", "--json"' in text
    assert "dots-keyboard" not in text
