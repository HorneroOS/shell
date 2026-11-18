"""Signal Bezel section 5: workspace cell states (static QML contracts)."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WS = ROOT / "modules" / "bar" / "components" / "workspaces"
CELL = (WS / "Workspace.qml").read_text()
ACTIVE = (WS / "ActiveIndicator.qml").read_text()
STRIP = (WS / "Workspaces.qml").read_text()
BAR = (ROOT / "modules" / "bar" / "Bar.qml").read_text()


def test_cells_are_rectangular_never_pills():
    for src in (ACTIVE, STRIP):
        assert "Appearance.rounding.full" not in src


def test_active_cell_is_raised_with_signal_tick_inside_the_cell():
    assert "Signal.palette.raised" in ACTIVE
    assert "root.tone.signal" in ACTIVE  # 2 px tick inset in the cell
    assert "tickInset" in ACTIVE and "Colouriser" not in ACTIVE
    assert "onSignal" not in ACTIVE  # no signal-filled slab


def test_urgent_and_visible_elsewhere_states():
    assert "isUrgent" in CELL and "root.tone.alert" in CELL
    assert "isVisibleElsewhere" in CELL and "Signal.palette.ruleStrong" in CELL
    assert "visibleElsewhere" in STRIP and "urgent" in STRIP


def test_occupied_tick_is_4_by_2_and_muted_on_unplated_cells():
    assert "width: root.vertical ? 2 : 4" in CELL
    assert "!root.plated" in CELL
    assert "root.tone.inkMuted" in CELL


def test_every_state_has_a_non_colour_cue():
    # accessible names carry every state, so colour is never the only signal
    for state in ("current", "urgent", "visible on another monitor", "occupied", "empty"):
        assert f'qsTr("{state}")' in CELL


def test_bar_passes_its_edge_to_the_strip():
    assert "edge: root.edge" in BAR


PLATES = (WS / "CellPlates.qml").read_text()


def test_cells_have_no_negative_margins_and_one_rhythm():
    assert "leftMargin: -" not in CELL and "topMargin: -" not in CELL
    assert "GridLayout" not in CELL  # explicit fixed-step positions
    for name in ("numeralBox", "groupStart", "glyphPx", "glyphGap", "mainSize"):
        assert name in CELL
    assert "Config.bar.workspaces.glyphScale" in CELL
    assert "overflowCount" in CELL and '"+" + root.overflowCount' in CELL


def test_plates_share_one_shape_and_use_signal_tokens():
    assert "Appearance.rounding.small" in PLATES
    assert "Signal.palette.rule" in PLATES and "Signal.palette.ruleStrong" in PLATES
    assert "root.tone.alert" in PLATES
    for src in (CELL, ACTIVE, PLATES, STRIP):
        assert '"#' not in src and "Material" not in src


def test_clear_and_labels_draw_no_plates():
    assert "!labels && !clear" in STRIP
    assert "active: root.plated" in STRIP


def test_glyph_controls_are_wired_end_to_end():
    cfg = (ROOT / "config" / "BarConfig.qml").read_text()
    assert "property int glyphScale: 85" in cfg and "property int maxWindowIcons: 3" in cfg
    assert "glyphScale: bar.workspaces.glyphScale" in (ROOT / "config" / "Config.qml").read_text()
    geo = (ROOT / "modules/controlcenter/taskbar/bargeometry.js").read_text()
    assert "glyphScale: { min: 60, max: 120" in geo and "maxWindowIcons: { min: 0, max: 8" in geo
    editor = (ROOT / "modules/controlcenter/taskbar/BarGeometryEditor.qml").read_text()
    for needle in ("Config.bar.workspaces.glyphScale = g.glyphScale", "Config.bar.workspaces.maxWindowIcons = g.maxWindowIcons",
                   'setWorkspaceField("glyphScale"', 'setWorkspaceField("maxWindowIcons"'):
        assert needle in editor
