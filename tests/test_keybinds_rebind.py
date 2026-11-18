"""Keybinds rebind editor contract (shell#236, COMPETITIVE gap #5): the
pane and the overlay drive the real `horneroctl hardware keyboard
rebind` backend through services/Keybinds.qml, offer editing only when
the backend reports a managed config (Lua overlay or hyprlang
overrides), apply with explicit --yes, and offer Undo after applying."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANE = ROOT / "modules" / "controlcenter" / "keybinds" / "KeybindsPane.qml"
SERVICE = ROOT / "services" / "Keybinds.qml"


def pane_text() -> str:
    return PANE.read_text(encoding="utf-8")


def service_text() -> str:
    return SERVICE.read_text(encoding="utf-8")


def test_service_uses_rebind_backend() -> None:
    text = service_text()
    assert '"horneroctl", "hardware", "keyboard", "rebind", "status", "--json"' in text
    assert '"horneroctl", "hardware", "keyboard", "rebind", "list", "--json"' in text
    assert '"rebind", "set", "--old", oldCombo, "--new", newCombo, "--yes", "--json"' in text
    assert '"--swap"' in text
    assert '"rebind", "reset", "--yes", "--json"' in text
    assert '"rebind", "undo", "--yes", "--json"' in text


def test_editor_gated_on_managed_backend() -> None:
    pane = pane_text()
    assert "Keybinds.managed" in pane
    assert "d.managed" in service_text()
    assert "d.format" in service_text()
    # Unmanaged sessions keep the honest read-only note.
    assert "read-only" in pane


def test_status_readback_fields() -> None:
    text = service_text()
    for field in ("d.managed", "d.overrides", "d.undo", "d.file"):
        assert field in text, field


def test_rebind_applies_on_enter_and_offers_undo() -> None:
    pane = pane_text()
    assert "onAccepted" in pane and "root.apply(false)" in pane
    assert 'Undo.offerCommand("keybind"' in pane
    assert "root.undoArgv" in service_text()
    assert 'qsTr("Apply")' not in pane
    # A recorded free combo applies at once; a taken one waits for Swap.
    rec = pane[pane.index("id: recorder"):pane.index("id: editCol")]
    assert "if (!root.conflict)" in rec and "root.apply(false)" in rec


def test_conflicts_named_before_saving_with_swap() -> None:
    pane = pane_text()
    assert "Keybinds.conflictFor(root.newCombo, root.editTarget.combo)" in pane
    assert "root.apply(true)" in pane


def test_capture_parks_hyprland_in_capture_submap() -> None:
    text = service_text()
    assert 'hl.dsp.submap(\\"hornero_capture\\")' in text
    assert 'hl.dsp.submap(\\"reset\\")' in text
    assert "Keybinds.endCapture()" in pane_text()
