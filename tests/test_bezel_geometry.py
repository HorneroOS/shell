"""Signal Bezel geometry: bar chrome and the frame cutout use small radii
(RFC 0001 s5.1, signal-visual-language), never pills."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def test_bar_modules_have_no_pill_radius():
    offenders = [str(p.relative_to(ROOT)) for p in (ROOT / "modules/bar").rglob("*.qml")
                 if "Appearance.rounding.full" in p.read_text(encoding="utf-8")]
    assert offenders == []


def test_floating_bar_surface_uses_normal_radius():
    src = (ROOT / "modules/bar/Bar.qml").read_text(encoding="utf-8")
    assert "radius: root.floating ? Appearance.rounding.normal : 0" in src


def test_frame_cutout_radius_is_a_bezel_token():
    src = (ROOT / "config/BorderConfig.qml").read_text(encoding="utf-8")
    m = re.search(r"property int rounding: Appearance\.rounding\.(\w+)", src)
    assert m and m.group(1) in ("small", "normal")


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


def test_appearance_themes_open_by_default_and_legacy_key_ignored():
    cfg = (ROOT / "config/ControlCenterConfig.qml").read_text(encoding="utf-8")
    assert 'property var appearanceOpenSections: ["themes"]' in cfg
    for p in ROOT.rglob("*"):
        if p.suffix in (".qml", ".json", ".py") and ".git" not in p.parts and p.name != "test_bezel_geometry.py":
            assert "appearanceExpandedSections" not in p.read_text(encoding="utf-8"), p


def test_log_noise_guards():
    osd = (ROOT / "modules/osd/Wrapper.qml").read_text(encoding="utf-8")
    assert "Qt.binding(() => root.shouldBeActive || root.visible)" not in osd
    tray = (ROOT / "modules/bar/popouts/Content.qml").read_text(encoding="utf-8")
    assert "trayMenu.modelData?.menu ?? null" in tray
    assert "trayMenu.modelData.menu" not in tray


def test_bottom_strip_resources_are_segmented_real_meters():
    src = (ROOT / "modules/bar/components/Resources.qml").read_text(encoding="utf-8")
    assert "Instruments.SegmentMeter" in src and "count: 8" in src
    assert "SystemUsage.cpuTempAvailable" in src  # no sensor, no temperature
    assert '"tnum": 1' in src
    assert "readonly property bool available: metrics.length > 0" in src
    bar = (ROOT / "modules/bar/Bar.qml").read_text(encoding="utf-8")
    assert "compact: root.compact" in bar


def test_idle_media_transport_leaves_no_segment():
    media = (ROOT / "modules/bar/components/Media.qml").read_text(encoding="utf-8")
    assert "readonly property bool available: active" in media


def test_bar_clock_uses_plex_sans_condensed():
    clock = (ROOT / "modules/bar/components/Clock.qml").read_text(encoding="utf-8")
    assert "font.family: Appearance.font.family.display" in clock
    assert "font.weight: Font.Medium" in clock and "font.pointSize: Appearance.font.size.large" in clock
    assert "toUpperCase()" in clock
