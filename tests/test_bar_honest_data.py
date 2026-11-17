"""Bar entries show real data or nothing (signal-visual-language s6.1) and the
bottom strip follows the s4.1 anatomy."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_brightness_hides_without_a_backend():
    svc = (ROOT / "services/Brightness.qml").read_text(encoding="utf-8")
    assert "property bool available: false" in svc
    assert "isFinite(value)" in svc
    assert '"-c", "backlight"' in svc
    slider = (ROOT / "modules/bar/components/InlineSlider.qml").read_text(encoding="utf-8")
    assert "readonly property bool available: isAudio || (monitor?.available ?? false)" in slider
    bar = (ROOT / "modules/bar/Bar.qml").read_text(encoding="utf-8")
    assert "visible: enabled && contentAvailable" in bar
    osd = (ROOT / "modules/osd/Content.qml").read_text(encoding="utf-8")
    assert "root.monitor?.available" in osd


def test_bottom_strip_resources_are_segmented_real_meters():
    src = (ROOT / "modules/bar/components/Resources.qml").read_text(encoding="utf-8")
    assert "Instruments.SegmentMeter" in src and "count: 8" in src
    assert "SystemUsage.cpuTempAvailable" in src  # no sensor, no temperature
    assert "BarText" in src  # values are BarText role "value": tabular figures
    assert 'tabular: root.role === "value"' in (ROOT / "components/BarText.qml").read_text(encoding="utf-8")
    assert "readonly property bool available: metrics.length > 0" in src
    bar = (ROOT / "modules/bar/Bar.qml").read_text(encoding="utf-8")
    assert "compact: root.compact" in bar


def test_idle_media_transport_leaves_no_segment():
    media = (ROOT / "modules/bar/components/Media.qml").read_text(encoding="utf-8")
    assert "readonly property bool available: active" in media


def test_bar_clock_uses_plex_sans_condensed():
    clock = (ROOT / "modules/bar/components/Clock.qml").read_text(encoding="utf-8")
    # Signal face: Plex Sans Condensed Medium; clean (Sans) type uses the plain
    # face at the item weight.
    assert "Appearance.font.family.display" in clock and "font.family: root.timeFamily" in clock
    assert "Font.Medium" in clock and "font.pointSize: Density.clockPt" in clock
    assert "toUpperCase()" in clock

