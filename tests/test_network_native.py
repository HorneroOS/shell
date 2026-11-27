"""Native Quickshell.Networking integration with Nmcli fallback (shell#735)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NETWORK = (ROOT / "services" / "Network.qml").read_text(encoding="utf-8")
STATUS_ICONS = (ROOT / "modules" / "bar" / "components" / "StatusIcons.qml").read_text(encoding="utf-8")


def test_network_service_wires_quickshell_networking():
    assert "import Quickshell.Networking" in NETWORK
    assert "Networking.backend !== NetworkBackendType.None" in NETWORK
    assert "Networking.wifiEnabled" in NETWORK
    assert "Networking.devices.values" in NETWORK
    assert "DeviceType.Wifi" in NETWORK
    assert "DeviceType.Wired" in NETWORK
    assert "scannerEnabled" in NETWORK
    assert "WifiSecurityType" in NETWORK
    assert "ConnectionState" in NETWORK


def test_network_service_eliminates_duplicate_nmcli_monitor_and_gates_polling():
    assert 'command: ["nmcli", "m"]' not in NETWORK
    for fn in ("enableWifi", "toggleWifi", "rescanWifi", "disconnectFromNetwork", "getWifiStatus", "getEthernetDevices"):
        idx = NETWORK.index(f"function {fn}(")
        body = NETWORK[idx:idx + 450]
        assert "root.nativeAvailable" in body, fn


def test_network_service_retains_nmcli_fallback_for_profiles_passwords_and_details():
    assert "Nmcli.connectToNetwork(" in NETWORK
    assert "Nmcli.connectToNetworkWithPasswordCheck(" in NETWORK
    assert "Nmcli.hasSavedProfile(" in NETWORK
    assert "Nmcli.getEthernetDeviceDetails(" in NETWORK
    assert "Nmcli.getWirelessDeviceDetails(" in NETWORK
    assert "Nmcli.loadSavedConnections(" in NETWORK


def test_status_icons_consumes_reactive_network_service():
    assert "Network.activeEthernet" in STATUS_ICONS
    assert "Network.active" in STATUS_ICONS
    assert "Nmcli." not in STATUS_ICONS
