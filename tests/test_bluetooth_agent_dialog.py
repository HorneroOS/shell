"""Pairing dialog contracts: explicit user confirmation, never auto-accept."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BT = ROOT / "modules/controlcenter/bluetooth"
STATE = (ROOT / "modules/controlcenter/state/BluetoothState.qml").read_text()
DIALOG = (BT / "PairingDialog.qml").read_text()
PANE = (BT / "BtPane.qml").read_text()


def test_dialog_is_wired_into_pane_overlay():
    assert "overlayComponent" in PANE
    assert "PairingDialog" in PANE
    assert (BT / "PairingDialog.qml").exists()


def test_confirmation_requires_explicit_user_action():
    assert "pairingConfirmed" in STATE
    assert "confirmPairing()" in DIALOG
    assert 'qsTr("Confirm")' in DIALOG
    assert 'qsTr("Only confirm if this code matches' in DIALOG
    # No timer or auto-confirm path anywhere in the dialog/state.
    assert "Timer" not in DIALOG
    assert "onCompleted" not in DIALOG


def test_reject_is_the_dismissal_path():
    assert "pairingRejected" in STATE
    assert "rejectPairing()" in DIALOG
    assert "Keys.onEscapePressed: session.bt.rejectPairing()" in DIALOG
    assert "cancelPairingRequest()" in STATE


def test_pin_and_passkey_entry_kinds_exist():
    assert "requestPinEntry" in STATE
    assert "requestPasskeyEntry" in STATE
    assert "pairingPinSubmitted" in STATE
    assert "submitPairingPin" in DIALOG


def test_no_auto_accept_agent_capability_in_shell():
    combined = STATE + DIALOG + PANE
    assert "NoInputNoOutput" not in combined
    assert "JustWorks" not in combined


def test_agent_bridge_is_file_backed_and_backend_answered():
    # The dialog endpoint is driven by the agent's request file and
    # answered only through the horneroctl agent-respond contract.
    assert "request-current.json" in STATE
    assert "pairingRequestView" in STATE
    assert '"agent-respond", pairingRequestId, action' in STATE
    assert "respondToAgent(\"confirm\"" in STATE
    assert "respondToAgent(\"pin\"" in STATE
    assert "respondToAgent(\"reject\"" in STATE
