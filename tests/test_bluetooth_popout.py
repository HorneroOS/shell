"""Bluetooth popout controls explain unavailable hardware and empty results."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_bluetooth_popout_reports_adapter_and_discovery_states():
    src = (ROOT / "modules/bar/popouts/Bluetooth.qml").read_text()
    assert "readonly property var adapter: Bluetooth.defaultAdapter ?? null" in src
    assert "readonly property bool hasAdapter: adapter !== null" in src
    assert 'qsTr("No Bluetooth adapter found")' in src
    assert 'qsTr("Turn on Bluetooth to find nearby devices")' in src
    assert 'qsTr("Looking for nearby devices…")' in src
    assert 'qsTr("No nearby devices. Turn on Discovering to search.")' in src
    assert src.index('if (!root.hasAdapter)') < src.index('const devices = Bluetooth.devices.values')
    assert src.index('if (!root.adapter.enabled)') < src.index('const devices = Bluetooth.devices.values')
    assert src.index('if (root.adapter.discovering)') < src.index('const devices = Bluetooth.devices.values')


def test_bluetooth_controls_are_hidden_without_an_adapter_and_status_wraps():
    src = (ROOT / "modules/bar/popouts/Bluetooth.qml").read_text()
    assert src.count("visible: root.hasAdapter") == 2
    assert "text: root.deviceStatus" in src
    assert "Layout.fillWidth: true" in src
    assert "wrapMode: Text.WordWrap" in src
