"""Bar item style (Cockpit Clear text and icons): one typographic voice,
one glyph size, one ink, with every value an end-user control."""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
BAR = ROOT / "modules" / "bar" / "components"


def run_js(file: str, expr: str):
    node = shutil.which("node")
    assert node
    src = (ROOT / file).read_text().replace(".pragma library", "", 1)
    out = subprocess.run([node, "-e", src + "\nconsole.log(JSON.stringify((() => {" + expr + "})()));"],
                         capture_output=True, text=True, timeout=30)
    assert out.returncode == 0, out.stderr
    return json.loads(out.stdout)


def test_item_scales_multiply_the_density_values_and_default_to_one():
    base = run_js("services/density.js", "return [icon(1,1), text(1,1), clock(1,1), segmentPadding(1,false)]")
    scaled = run_js("services/density.js", "return [icon(1,1,0.5), text(1,1,1.5), clock(1,1,1.5), segmentPadding(1,false,1.5)]")
    assert base == [16, 12, 16, 12]
    assert scaled[0] == 10 or scaled[0] == 9  # 60 % floor on the icon scale: 16 * 0.6
    assert scaled[1] == 18 and scaled[3] == 18


def test_item_scales_are_clamped_and_weights_snap():
    assert run_js("services/density.js", "return [iconScale(0.1), iconScale(9), itemSpacing(0), textWeight(433, 0), textWeight(900, 0), textWeight(400, 100)]") == [0.6, 1.5, 1, 450, 600, 500]


def test_every_item_control_is_configured_serialised_and_in_the_pane():
    cfg = (ROOT / "config/BarConfig.qml").read_text()
    for needle in ("property real iconScale: 1", "property real textScale: 1", "property real itemSpacing: 1",
                   "property int textWeight: 400", 'property string typeface: "mono"', "ClearInkKnobs"):
        assert needle in cfg, needle
    ser = (ROOT / "config/Config.qml").read_text()
    for needle in ("iconScale: bar.sizes.iconScale", "textScale: bar.sizes.textScale", "itemSpacing: bar.sizes.itemSpacing",
                   "textWeight: bar.sizes.textWeight", "typeface: bar.typeface", "strength: bar.clearInk.strength"):
        assert needle in ser, needle
    default = json.loads((ROOT / "config/shell.default.json").read_text())["bar"]
    assert default["typeface"] == "mono" and default["sizes"]["iconScale"] == 1
    assert default["clearInk"] == {"strength": 1, "outline": 1, "polarity": "auto"}
    pane = (ROOT / "modules/controlcenter/taskbar/BarGeometryEditor.qml").read_text()
    for needle in ("Config.bar.sizes.iconScale", "Config.bar.sizes.textScale", "Config.bar.sizes.textWeight",
                   "Config.bar.sizes.itemSpacing", "Config.bar.typeface"):
        assert needle in pane, needle
    row = (ROOT / "modules/layoutpicker/ClearStyleRow.qml").read_text()
    assert "clearInk.strength" in row and "clearInk.outline" in row and "polarities" in row


def test_geometry_reset_returns_the_presets_item_style():
    out = run_js("modules/controlcenter/taskbar/bargeometry.js",
                 "return presetGlobals({bar:{typeface:'sans',sizes:{innerWidth:24,iconScale:0.9,textScale:1.1,itemSpacing:2,textWeight:400}}})")
    assert (out["iconScale"], out["textScale"], out["itemSpacing"], out["typeface"]) == (0.9, 1.1, 2, "sans")


def test_cockpit_clear_ships_the_quiet_item_style():
    bar = json.loads((ROOT / "presets/cockpit-clear.json").read_text())["bar"]
    assert bar["typeface"] == "sans"
    assert 0.8 <= bar["sizes"]["iconScale"] < 1 and bar["sizes"]["itemSpacing"] >= 1.4


def test_bar_items_share_one_text_component_and_no_hard_coded_mono():
    assert "Density.dataFamily" in (ROOT / "components/BarText.qml").read_text()
    for name in ("Resources", "KbLayout", "WeatherChip", "Battery", "ModeIndicator", "Media", "InlineSlider", "Clock"):
        src = (BAR / f"{name}.qml").read_text()
        assert "BarText" in src, name
        assert "family.mono" not in src, name
    assert "mono: true" not in (BAR / "Resources.qml").read_text()


def test_clear_item_ink_follows_the_region_tone_everywhere():
    for name in ("Tray", "TrayItem", "ExtensionsIsland"):
        src = (BAR / f"{name}.qml").read_text()
        assert "property var tone: ClearInk.neutral" in src, name
        assert "Signal.palette.inkMuted" not in src, name
    assert "Calendar" not in (BAR / "Clock.qml").read_text() and 'name: "clock"' in (BAR / "Clock.qml").read_text()


def test_slider_rule_track_is_a_thin_line_with_a_tick():
    sl = (ROOT / "components/controls/StyledSlider.qml").read_text()
    assert "property color trackColour" in sl and "root.trackColour" in sl
    assert "radius: root.ruleTrack ? 0" in sl


def test_tray_icons_match_bar_icon_size_by_default():
    tray_item = (BAR / "TrayItem.qml").read_text()
    assert "implicitWidth: Density.iconPx\n" in tray_item
    assert "implicitHeight: Density.iconPx\n" in tray_item
    assert "implicitSize: Density.iconPx\n" in tray_item
    assert "Density.iconPx + 4" not in tray_item
