"""Control Center channel kit: eyebrow-titled, rule-framed panels with
hairline rows replace raised tonal cards on the daily panes, and every
readout is a real value or says "unavailable"."""
from pathlib import Path

ROOT = Path(__file__).parent.parent
CC = ROOT / "modules/controlcenter"
KIT = CC / "components"


def _src(path: Path) -> str:
    return path.read_text()


def test_channel_panel_is_a_ruled_frame_not_a_tonal_card():
    panel = _src(KIT / "ChannelPanel.qml")
    assert "Eyebrow {" in panel
    assert 'color: "transparent"' in panel and "Signal.palette.rule" in panel
    assert "Signal.layer(Signal.palette.panel" not in panel
    assert 'qsTr("unavailable")' in panel
    assert "Accessible.Heading" in panel


def test_stream_level_binds_a_real_meter_and_says_unavailable():
    level = _src(KIT / "StreamLevel.qml")
    assert "SegmentMeter {" in level and "available: root.available" in level
    assert 'qsTr("unavailable")' in level
    assert "StyledSwitch {" in level  # rocker, not a tonal toggle tile
    assert "Accessible.name: root.muteName" in level


def test_device_row_marks_default_with_text_bar_and_well():
    row = _src(KIT / "DeviceRow.qml")
    assert "OnAirBar {" in row and "signalWell" in row
    assert "currentWord" in row  # DEFAULT is a word, never colour alone


def test_daily_panes_use_the_channel_kit_without_raised_cards():
    for rel in ("audio/AudioPane.qml", "displays/DisplaysPane.qml", "input/InputPane.qml"):
        src = _src(CC / rel)
        assert "ChannelPanel {" in src, rel
        assert "Signal.layer(Signal.palette.panel" not in src, rel
        assert "SectionContainer" not in src and "ToggleRow" not in src, rel
        assert "🖥" not in src, rel


def test_displays_readouts_come_from_screens_and_hypr_not_guesses():
    src = _src(CC / "displays/DisplaysPane.qml")
    assert "Quickshell.screens.map" in src and "Hypr.monitorFor(s)" in src
    assert "NaN" in src and "isNaN(outputRow.modelData.hz)" in src
    assert "brightnessAvailable" in src


def test_row_kit_is_framed_not_tonal_and_text_never_uses_rule_strong():
    section = _src(ROOT / "components/SectionContainer.qml")
    assert 'color: "transparent"' in section and "border.color: Signal.palette.rule" in section
    for rel in ("components/controls/SwitchRow.qml", "components/controls/SpinBoxRow.qml",
                "components/controls/SplitButtonRow.qml", "modules/controlcenter/components/CtlCard.qml",
                "modules/controlcenter/components/ConnectedButtonGroup.qml"):
        assert "Signal.layer(Signal.palette.panel" not in _src(ROOT / rel), rel
    for path in CC.rglob("*.qml"):
        if path.name == "AppearancePreviewPane.qml":
            continue
        assert "\n            color: Signal.palette.ruleStrong\n" not in _src(path) or "Glyph" in _src(path), path


def test_property_row_prints_unavailable_for_missing_values():
    row = _src(ROOT / "components/PropertyRow.qml")
    assert 'qsTr("unavailable")' in row and "mono: true" in row
    for path in (CC / "network").glob("*.qml"):
        assert 'qsTr("N/A")' not in _src(path), path


def test_power_and_system_use_channel_panels_and_meters():
    assert _src(CC / "power/PowerPane.qml").count("ChannelPanel {") == 2
    system = _src(CC / "system/SystemPane.qml")
    assert "SegmentMeter {" in system and "ChannelPanel {" in system
    assert "Signal.palette.lifted" not in system  # no filled progress track
    updates = _src(CC / "updates/UpdatesPane.qml")
    assert "ChannelPanel {" in updates and 'qsTr("Dependencies & recovery")' in updates


def test_settings_panes_use_channel_panels_instead_of_tonal_cards():
    for rel in ("notifications/NotificationsPane.qml", "osd/OsdPane.qml", "windows/WindowsPane.qml",
                "nightlight/NightLightPane.qml", "accessibility/AccessibilityPane.qml",
                "capture/CapturePane.qml", "session/SessionPane.qml", "lockscreen/LockScreenPane.qml"):
        src = _src(CC / rel)
        assert "ChannelPanel {" in src, rel
        assert "Signal.layer(Signal.palette.panel" not in src, rel


def test_kit_rows_go_flat_inside_a_channel_panel():
    assert "isChannelPanel: true" in _src(KIT / "ChannelPanel.qml")
    for rel in ("components/controls/SwitchRow.qml", "components/controls/SpinBoxRow.qml",
                "components/controls/SplitButtonRow.qml", "modules/controlcenter/components/ConnectedButtonGroup.qml"):
        src = _src(ROOT / rel)
        assert "p.isChannelPanel === true" in src and "border.width: root.flat ? 0 : 1" in src, rel


def test_network_bluetooth_lists_use_selected_well_and_signal_meter():
    for rel in ("network/WirelessList.qml", "network/EthernetList.qml", "network/VpnList.qml", "bluetooth/DeviceList.qml"):
        src = _src(CC / rel)
        assert "OnAirBar {" in src and "Signal.palette.signalWell" in src, rel
        assert "tPalette.panel" not in src and "ruleStrong" not in src, rel
    assert "SegmentMeter {" in _src(CC / "network/WirelessList.qml")


def test_detail_headers_are_compact_left_aligned_with_heading_role():
    for rel in ("components/SettingsHeader.qml",):
        src = _src(CC / rel)
        assert "RowLayout {" in src and "Accessible.Heading" in src and "AlignHCenter" not in src
    assert "AlignHCenter" not in _src(ROOT / "components/ConnectionHeader.qml")
