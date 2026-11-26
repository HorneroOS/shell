"""Signal Bezel section 4 bar Segment anatomy and the mode indicator."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BAR = (ROOT / "modules" / "bar" / "Bar.qml").read_text()
MODE = (ROOT / "modules" / "bar" / "components" / "ModeIndicator.qml").read_text()


def test_segment_padding_and_rule_inset_follow_the_spec():
    assert "segmentPadding: vertical ? Density.segmentPadRail : Density.segmentPad" in BAR
    assert "segmentInset: 6" in BAR
    # Groups carry no spacing of their own: segments own their padding.
    assert BAR.count("rowSpacing: 0") >= 1 and "columnSpacing: 0" in BAR
    assert "Layout.leftMargin: root.vertical ? 0 : wrapped.leadPad" in BAR


def test_icon_clusters_share_one_segment_without_a_rule():
    m = re.search(r"clusterIds: \[([^\]]*)\]", BAR)
    ids = [x.strip().strip('"') for x in m.group(1).split(",")]
    assert ids == ["quickActions", "statusIcons", "tray", "extensions"]
    # half padding on each side gives the 12 px gap inside a cluster
    assert "root.segmentPadding / 2" in BAR
    assert "!joinPrev" in BAR


def test_rules_are_one_pixel_rule_and_absent_on_clear_bars():
    block = BAR[BAR.index("model: group.separators"):]
    block = block[: block.index("z: -1")]
    assert "height: root.vertical ? 1 : group.height - inset * 2" in block
    assert "color: Signal.palette.rule" in block
    assert "visible: !root.clear" in block


def test_mode_indicator_is_registered_and_quiet_in_everyday():
    assert 'roleValue: "modeIndicator"' in BAR
    assert 'shown: always || Experience.mode !== "everyday"' in MODE
    assert "Experience.label" in MODE and "Experience.glyph" in MODE
    assert "Accessible.name" in MODE
    # at most four characters per eyebrow (section 4.1)
    codes = re.findall(r'"(?:focus|everyday|signal|gaming|studio)": "([A-Z]+)"', MODE)
    assert len(codes) == 5 and all(len(c) <= 4 for c in codes)
    assert "modeIndicator" in (ROOT / "modules/controlcenter/taskbar/barorder.js").read_text()


def test_cockpit_layouts_carry_the_mode_indicator_first_in_the_top_end():
    for path in ("presets/cockpit.json", "presets/cockpit-clear.json"):
        data = json.loads((ROOT / path).read_text())
        bars = data["bar"]["bars"] if "bar" in data else data["bars"]
        assert bars[0]["groups"]["end"][0]["id"] == "modeIndicator", path
