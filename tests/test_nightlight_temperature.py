"""Night Light temperature contract (shell#225 slice 2): the pane's
slider must drive the real horneroctl temperature verb, stay inside
the backend's 1000-6500K window, read the stored temperature back
from status, and only appear when a backend can honour it."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANE = ROOT / "modules" / "controlcenter" / "nightlight" / "NightLightPane.qml"


def pane_text() -> str:
    return PANE.read_text(encoding="utf-8")


def test_temperature_uses_backend_set_verb() -> None:
    text = pane_text()
    assert '"night-mode", "set", "--temperature"' in text
    assert '"--yes", "--json"' in text


def test_temperature_window_matches_backend() -> None:
    text = pane_text()
    assert "from: 1000" in text
    assert "to: 6500" in text
    assert "bottom: 1000" in text
    assert "top: 6500" in text


def test_temperature_read_from_status() -> None:
    text = pane_text()
    assert 'd.temperature' in text
    assert "property int temperature: 4000" in text


def test_slider_only_when_backend_available() -> None:
    text = pane_text()
    assert 'visible: root.available !== ""' in text
    assert "SliderInput" in text


def test_no_retired_wrappers() -> None:
    text = pane_text()
    assert "dots-night-mode" not in text
    assert "horneroctl" in text
