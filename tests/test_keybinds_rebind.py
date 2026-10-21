"""Keybinds rebind editor contract (shell#236 slice 2): the pane must
drive the real `horneroctl hardware keyboard rebind` backend, only
offer editing when the backend reports managed (hyprlang) config,
apply with explicit --yes, and surface reset + status readback."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANE = ROOT / "modules" / "controlcenter" / "keybinds" / "KeybindsPane.qml"


def pane_text() -> str:
    return PANE.read_text(encoding="utf-8")


def test_pane_uses_rebind_backend() -> None:
    text = pane_text()
    assert '"horneroctl", "hardware", "keyboard", "rebind", "status", "--json"' in text
    assert '"rebind", "set", "--old", root.editOld, "--new", root.newCombo' in text
    assert '"rebind", "reset", "--yes", "--json"' in text


def test_editor_gated_on_managed_backend() -> None:
    text = pane_text()
    assert "root.managed" in text
    assert 'd.managed' in text
    # Lua / unmanaged sessions keep the honest read-only note.
    assert "read-only" in text


def test_status_readback_fields() -> None:
    text = pane_text()
    for field in ("d.managed", "d.overrides"):
        assert field in text, field


def test_reset_needs_two_steps() -> None:
    text = pane_text()
    assert "resetArmed" in text


def test_combo_extraction_present() -> None:
    text = pane_text()
    assert "function comboOf" in text
    assert '" -> "' in text
