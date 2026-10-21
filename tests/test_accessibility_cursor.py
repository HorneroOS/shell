"""Accessibility cursor contract (shell#221): the pane must expose
cursor size through the real horneroctl hypr cursor backend and
read the effective size/source back from status."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANE = ROOT / "modules" / "controlcenter" / "accessibility" / "AccessibilityPane.qml"


def pane_text() -> str:
    return PANE.read_text(encoding="utf-8")


def test_cursor_backend_wired() -> None:
    text = pane_text()
    assert '"horneroctl", "hypr", "cursor", "status", "--json"' in text
    assert '"horneroctl", "hypr", "cursor", "set", "--size", Math.round(newValue).toString(), "--yes", "--json"' in text


def test_cursor_readback_fields() -> None:
    text = pane_text()
    for field in ("d.size", "d.theme", "d.size_source"):
        assert field in text, field


def test_cursor_section_labelled() -> None:
    text = pane_text()
    assert 'qsTr("Cursor")' in text
    assert 'qsTr("Cursor size")' in text
