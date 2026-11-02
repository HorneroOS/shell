"""Bluetooth pane/state contracts: event-driven, single adapter, no polling."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BT = ROOT / "modules/controlcenter/bluetooth"
STATE = (ROOT / "modules/controlcenter/state/BluetoothState.qml").read_text()
PANE = (BT / "BtPane.qml").read_text()
DEVICES = (BT / "DeviceList.qml").read_text()
SETTINGS = (BT / "Settings.qml").read_text()
DETAILS = (BT / "Details.qml").read_text()
POPOUT = (ROOT / "modules/bar/popouts/Bluetooth.qml").read_text()


def test_no_polling_timers_in_bluetooth_ui():
    for src in (STATE, PANE, DEVICES, SETTINGS, DETAILS, POPOUT):
        assert "Timer {" not in src
        assert "Timer{" not in src


def test_single_current_adapter_everywhere():
    assert "Bluetooth.defaultAdapter" not in SETTINGS
    assert "Bluetooth.defaultAdapter" not in DEVICES
    assert SETTINGS.count("root.session.bt.currentAdapter") >= 5
    assert "effectiveAdapter" in STATE
    assert "currentAdapter ?? Bluetooth.defaultAdapter" in STATE


def test_no_adapter_and_powered_off_empty_states():
    for src in (DEVICES, SETTINGS):
        assert 'qsTr("No Bluetooth adapter found' in src
    assert 'qsTr("Bluetooth is off. Turn it on to find nearby devices.")' in DEVICES
    assert 'qsTr("Restart Bluetooth service")' in DEVICES
    assert "restartService()" in STATE
    assert '"horneroctl", "hardware", "bluetooth", "restart", "--yes"' in STATE


def test_explicit_power_direction_not_read_invert():
    # Explicit direction from the toggle; power persistence is owned by
    # the backend (rfkill), never a read-then-invert of BlueZ state and
    # never adapter.enabled alone (AutoEnable=true would revert it).
    assert "function setPowered(on: bool)" in STATE
    assert '"bluetooth", "power", on ? "on" : "off", "--yes"' in STATE
    assert "adapter.enabled = on" not in STATE
    assert "adapter.enabled = !adapter.enabled" not in DEVICES
    assert "adapter.enabled = !adapter.enabled" not in SETTINGS


def test_discoverable_pairable_only_while_pane_open():
    assert "adapter.discoverableTimeout = 120" in PANE
    assert "adapter.pairableTimeout = 120" in PANE
    assert "adapter.discoverable = false" in PANE
    assert "adapter.pairable = false" in PANE
    assert "stopDiscoveryIfOwned()" in PANE


def test_stale_active_device_is_pruned():
    assert "function pruneStaleActive()" in STATE
    assert "Bluetooth.devices.values.includes(active)" in STATE
    assert "pruneStaleActive()" in DEVICES


def test_operations_route_through_state_with_errors():
    for fn in ("pairDevice", "connectDevice", "disconnectDevice", "forgetDevice", "setTrusted"):
        assert f"function {fn}(" in STATE
    assert "root.session.bt.connectDevice(device.modelData)" in DEVICES
    assert "root.session.bt.disconnectDevice(device.modelData)" in DEVICES
    assert "lastError" in DEVICES
    # Blocked devices get a reason, trust is never a pairing side effect.
    assert "is blocked; unblock it before connecting" in STATE
    assert "device.pair()" in STATE


def test_popout_pairs_unbonded_instead_of_connecting():
    assert "device.modelData.pair();" in POPOUT
    assert "device.modelData.connected = !device.modelData.connected" not in POPOUT


def test_unnamed_devices_are_shown_by_address():
    assert 'a.name || a.address' in DEVICES
    assert 'a.name || a.address' in POPOUT


def test_details_guards_null_device():
    assert "if (!root.device)" in DETAILS
    assert "root.device.connected = checked" not in DETAILS
    assert "root.device.trusted = checked" not in DETAILS
