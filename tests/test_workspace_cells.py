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


def test_active_cell_is_raised_with_on_air_bar():
    assert "Signal.palette.raised" in ACTIVE
    assert "root.tone.signal" in ACTIVE  # 2 px on-air bar
    assert "onSignal" not in ACTIVE  # no signal-filled slab


def test_urgent_and_visible_elsewhere_states():
    assert "isUrgent" in CELL and "root.tone.alert" in CELL
    assert "isVisibleElsewhere" in CELL and "Signal.palette.ruleStrong" in CELL
    assert "visibleElsewhere" in STRIP and "urgent" in STRIP


def test_occupied_tick_is_4_by_2_and_muted():
    assert "width: root.vertical ? 2 : 4" in CELL
    assert "root.tone.inkMuted" in CELL


def test_every_state_has_a_non_colour_cue():
    # accessible names carry every state, so colour is never the only signal
    for state in ("current", "urgent", "visible on another monitor", "occupied", "empty"):
        assert f'qsTr("{state}")' in CELL


def test_bar_passes_its_edge_to_the_strip():
    assert "edge: root.edge" in BAR
