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
