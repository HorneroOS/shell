"""Signal Bezel surface contracts (RFC 0001 amendments 1+2, W4c).

Static checks only: they pin the instrument kit's honesty rules and the
recomposed surfaces' geometry. Visual quality is judged from captures.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KIT = ROOT / "modules" / "instruments"


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_instrument_kit_pieces_exist():
    for name in ("Eyebrow", "Well", "Frame", "RegistrationTick", "OnAirChip", "SegmentMeter",
                 "SegmentSlider", "ScopeTrace", "TraceBuffer", "Partition", "Readout"):
        assert (KIT / f"{name}.qml").is_file(), name


def test_eyebrow_is_mono_uppercase_tracked_muted():
    src = (KIT / "Eyebrow.qml").read_text()
    assert "mono: true" in src
    assert "Font.AllUppercase" in src
    assert "0.08" in src
    assert "Signal.palette.inkMuted" in src


def test_meters_never_invent_values():
    meter = (KIT / "SegmentMeter.qml").read_text()
    # NaN or an unavailable source lights no segment.
    assert "available && !isNaN(value)" in meter
    assert "live ? " in meter
    buf = (KIT / "TraceBuffer.qml").read_text()
    assert "isNaN(v)" in buf and "return;" in buf
    readout = (KIT / "Readout.qml").read_text()
    assert '"—"' in readout


def test_scope_glow_is_rationed():
    src = (KIT / "ScopeTrace.qml").read_text()
    # Glow: opt-in, never in light or high-contrast themes, alpha <= 40 %.
    assert "glowWanted: glow && !Signal.light && !Config.appearance.highContrast" in src
    for alpha in re.findall(r"Qt\.alpha\(Signal\.palette\.glow,\s*([0-9.]+)\)", src):
        assert float(alpha) <= 0.4
    # Persistence is the previous real window at 22 %.
    assert "0.22" in src
    # Graticule: 10 x 4 divisions.
    assert "model: 9" in src and "/ 10" in src and "/ 4" in src


def test_redesigned_surfaces_drop_pills():
    for rel in ("modules/launcher/Content.qml", "modules/launcher/items/LauncherRow.qml",
                "modules/launcher/items/CalcItem.qml", "modules/notifications/Notification.qml",
                "modules/osd/Content.qml", "modules/session/Content.qml",
                "modules/utilities/toasts/ToastItem.qml"):
        src = _read(rel)
        assert "rounding.full" not in src, rel
        assert "rounding.large" not in src, rel


def test_attached_sheets_have_no_concave_wings():
    for rel in ("modules/launcher/Background.qml", "modules/osd/Background.qml",
                "modules/session/Background.qml"):
        src = _read(rel)
        assert "PathMove" in src, rel
        assert "Signal.palette.rule" in src, rel
        assert "Signal.palette.panel" in src, rel


def test_launcher_rows_share_one_instrument_row():
    items = ROOT / "modules" / "launcher" / "items"
    for name in ("AppItem", "ActionItem", "FileItem", "PluginItem", "WindowItem", "AppearanceItem"):
        assert re.search(r"^LauncherRow \{", (items / f"{name}.qml").read_text(), re.M), name
    row = (items / "LauncherRow.qml").read_text()
    # Current row: on-air bar + Enter cue, never colour alone.
    assert "Signal.palette.signal" in row and "ListView.isCurrentItem" in row and "⏎" in row


def test_notification_critical_is_named_not_only_coloured():
    src = _read("modules/notifications/Notification.qml")
    assert 'qsTr("Urgent")' in src
    assert "Signal.palette.alert" in src


def test_osd_channels_are_segmented_and_named():
    src = _read("modules/osd/Content.qml")
    assert src.count("Instruments.SegmentSlider") == 3
    slider = (KIT / "SegmentSlider.qml").read_text()
    assert "Accessible.role: Accessible.Slider" in slider
    assert "Keys.onPressed" in slider


def test_toasts_name_their_kind_in_words():
    src = _read("modules/utilities/toasts/ToastItem.qml")
    for word in ("Done", "Warning", "Error", "Note"):
        assert f'qsTr("{word}")' in src
