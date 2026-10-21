"""Control Center list rows must be named buttons.

Network, Bluetooth, audio and launcher-pane rows are StyledRect +
Interactive delegates; without Accessible declarations a screen
reader hears nothing for the row or its connect action. Each row
names itself after its visible label and states its connection
state, following the launcher-rows pattern.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CC = ROOT / "modules" / "controlcenter"


def _src(rel: str) -> str:
    return (CC / rel).read_text()


def test_ethernet_rows_named_with_state():
    src = _src("network/EthernetList.qml")
    assert "Accessible.name: (modelData.interface || qsTr(\"Unknown\"))" in src
    assert 'qsTr("Disconnect")' in src and 'qsTr("Connect")' in src


def test_wireless_rows_named_with_state():
    src = _src("network/WirelessList.qml")
    assert "Accessible.name: (modelData.ssid || qsTr(\"Unknown\"))" in src
    assert 'qsTr("Disconnect")' in src and 'qsTr("Connect")' in src


def test_vpn_rows_named():
    src = _src("network/VpnList.qml")
    assert "Accessible.name: (modelData.displayName || qsTr(\"Unknown\"))" in src


def test_bluetooth_device_rows_named():
    src = _src("bluetooth/DeviceList.qml")
    assert 'Accessible.name: (modelData ? modelData.name : qsTr("Unknown"))' in src


def test_audio_device_rows_named():
    src = _src("audio/AudioPane.qml")
    assert 'qsTr(", current output")' in src
    assert 'qsTr(", current input")' in src


def test_launcher_pane_rows_named():
    src = _src("launcher/LauncherPane.qml")
    assert "Accessible.name: modelData.name || modelData.entry?.name" in src
