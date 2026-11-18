"""Dashboard composition (Caelestia-recovery item 6, Hornero adaptation):
console (default) / classic / compact, selectable in Control Center."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DASH = (ROOT / "modules/dashboard/Dash.qml").read_text()


def test_default_and_serializer():
    assert json.loads((ROOT / "config/shell.default.json").read_text())["dashboard"]["composition"] == "console"
    assert 'property string composition: "console"' in (ROOT / "config/DashboardConfig.qml").read_text()
    assert "composition: dashboard.composition" in (ROOT / "config/Config.qml").read_text()


def test_unknown_values_fall_back_to_console():
    assert '["console", "classic", "compact"].includes(Config.dashboard.composition) ? Config.dashboard.composition : "console"' in DASH


def test_console_layout_shape():
    console = DASH.split("id: consoleLayout", 1)[1].split("id: gridLayout", 1)[0]
    deck = console.split('title: qsTr("Deck")', 1)[0].rsplit("Instruments.Frame {", 1)[1]
    assert "Layout.rowSpan: 3" in deck and "Layout.column: 2" in deck
    assert 'layout: "tower"' in console and "graduations: true" in console and "strip: true" in console
    assert "rowSpacing: root.gap" in console and "gap: Appearance.spacing.normal" in DASH
    # Reading order: clock, station, deck, calendar, resources, weather.
    order = [console.index(s) for s in ('qsTr("Clock")', 'qsTr("Station")', 'qsTr("Deck")', "Calendar {", "qsTr(\"Resources\")", 'label: qsTr("Weather")')]
    assert order == sorted(order)


def test_radii_stay_small_everywhere():
    assert "radius:" not in DASH and "rounding.full" not in DASH


def test_classic_keeps_the_grid_and_compact_drops_the_deck():
    grid = DASH.split("id: gridLayout", 1)[1]
    assert 'visible: root.composition !== "compact"' in grid and 'layout: "strip"' in grid


def test_control_center_choice_with_reset():
    text = (ROOT / "modules/controlcenter/dashboard/CompositionSection.qml").read_text()
    assert re.search(r'ChoiceRow \{[^}]*target: Config\.dashboard[^}]*key: "composition"[^}]*defaultValue: "console"', text, re.S)
    for opt in ("console", "classic", "compact"):
        assert f'"id": "{opt}"' in text
    assert "CompositionSection {}" in (ROOT / "modules/controlcenter/dashboard/DashboardPane.qml").read_text()
    assert 'id: "dashboard-composition"' in (ROOT / "modules/controlcenter/PaneRegistry.qml").read_text()


def test_seconds_ruler_steps_and_uses_signal():
    dt = (ROOT / "modules/dashboard/dash/DateTime.qml").read_text()
    assert "model: root.graduations ? 60 : 0" in dt
    assert "index <= Time.seconds ? Signal.palette.signal : Signal.palette.rule" in dt
    assert "Animation" not in dt
