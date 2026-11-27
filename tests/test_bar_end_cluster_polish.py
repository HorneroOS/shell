"""Bar end cluster polish contracts (HorneroOS/shell#538): symmetric
alignment, baseline/vertical centering, tooltips across bar items, uniform
cluster padding without ghost width, and glyph-only vs labelled resources.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BAR_COMP = ROOT / "modules" / "bar" / "components"


def test_status_icons_symmetric_centering_and_tooltips():
    src = (BAR_COMP / "StatusIcons.qml").read_text(encoding="utf-8")
    assert "anchors.centerIn: parent" in src
    assert "anchors.rightMargin: root.vertical ? 0 : Appearance.padding.normal" not in src
    assert "verticalAlignment: Text.AlignVCenter" in src
    assert "property string tooltipText:" in src
    assert "Tooltip {" in src
    for needle in (
        'Audio: Muted',
        'Microphone: Muted',
        'Keyboard layout: %1',
        'Wi-Fi: %1',
        'Ethernet: Connected',
        'Bluetooth: Off',
        'Battery: %1%',
        'Caps Lock: %1',
    ):
        assert needle in src, f"missing tooltip in StatusIcons.qml: {needle}"


def test_tray_and_extensions_chevrons_have_symmetric_padding_and_no_ghost_width():
    tray = (BAR_COMP / "Tray.qml").read_text(encoding="utf-8")
    ext = (BAR_COMP / "ExtensionsIsland.qml").read_text(encoding="utf-8")
    assert "-Appearance.padding.small" not in tray
    assert "-Appearance.padding.small" not in ext
    assert "(items?.count ?? 0) > 0 ? layout.implicitWidth + padding * 2 : 0" in tray
    assert "(items?.count ?? 0) > 0 ? layout.implicitHeight + padding * 2 : 0" in tray


def test_resources_respects_glyphs_density_and_exposes_tooltips():
    res = (BAR_COMP / "Resources.qml").read_text(encoding="utf-8")
    assert 'density !== "icons" && density !== "glyphs"' in res
    assert "Tooltip {" in res
    assert "`${metric.modelData.full}: ${metric.modelData.text}`" in res
    assert "verticalAlignment: Text.AlignVCenter" in res


def test_every_bar_item_has_tooltip():
    for rel in (
        "OsIcon.qml",
        "Clock.qml",
        "Power.qml",
        "Battery.qml",
        "KbLayout.qml",
        "WeatherChip.qml",
        "ActiveWindow.qml",
        "TrayItem.qml",
        "Media.qml",
        "BarButton.qml",
        "InlineSlider.qml",
        "PinnedApps.qml",
    ):
        src = (BAR_COMP / rel).read_text(encoding="utf-8")
        assert "Tooltip {" in src, f"missing Tooltip in {rel}"
