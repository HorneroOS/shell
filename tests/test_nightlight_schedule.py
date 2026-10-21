"""Night Light schedule contract (shell#225 remainder): the pane's
schedule controls must drive the real horneroctl schedule verbs,
read the enforced state back from status, and stay hidden when no
backend can honour them."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANE = ROOT / "modules" / "controlcenter" / "nightlight" / "NightLightPane.qml"


def pane_text() -> str:
    return PANE.read_text(encoding="utf-8")


def test_schedule_uses_backend_verbs() -> None:
    text = pane_text()
    assert '"night-mode", "schedule", "set", "--from"' in text
    assert '"night-mode", "schedule", "clear", "--yes", "--json"' in text
    assert '"--to"' in text


def test_schedule_read_from_status() -> None:
    text = pane_text()
    assert "d.schedule" in text
    assert "d.scheduleEnforced" in text


def test_schedule_controls_backend_gated() -> None:
    text = pane_text()
    assert text.count("SpinBoxRow") >= 4
    assert 'visible: root.available !== ""' in text


def test_schedule_defaults_are_night_window() -> None:
    text = pane_text()
    assert "property int onHour: 22" in text
    assert "property int offHour: 7" in text
