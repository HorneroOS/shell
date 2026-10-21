"""Input layout set contract (shell#226 remainder): the Input pane
must expose layout list/set through the real horneroctl backend,
prefill from the current layout readback, and show the available
layout count from `layout --list`."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANE = ROOT / "modules" / "controlcenter" / "input" / "InputPane.qml"


def pane_text() -> str:
    return PANE.read_text(encoding="utf-8")


def test_layout_set_wired() -> None:
    text = pane_text()
    assert '"layout", "--set", root.layoutsField' in text
    assert '"--yes", "--json"' in text
    assert "root.curLayout" in text
    assert "root.curVariant" in text


def test_layout_list_count() -> None:
    text = pane_text()
    assert '"horneroctl", "hardware", "keyboard", "layout", "--list", "--json"' in text
    assert "d.count" in text


def test_variant_optional() -> None:
    text = pane_text()
    # --variant is only passed when the field is non-empty.
    assert 'if (root.variantField.trim() !== "")' in text
