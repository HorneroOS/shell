"""Dashboard glanceability (shell#462): resource bars show their value and
announce it; quick toggles look like buttons when inactive."""
from pathlib import Path

DASH = Path(__file__).resolve().parents[1] / "modules/dashboard/dash"


def test_resource_bars_show_and_announce_their_value():
    src = (DASH / "Resources.qml").read_text(encoding="utf-8")
    assert 'text: Math.round(res.value * 100) + "%"' in src
    assert "Accessible.role: Accessible.ProgressBar" in src
    for label in ("CPU", "Memory", "Storage"):
        assert f'label: qsTr("{label}")' in src


def test_inactive_quick_toggles_have_a_visible_container():
    src = (DASH / "QuickToggles.qml").read_text(encoding="utf-8")
    assert ": Signal.palette.lifted" in src
    assert "Accessible.name: chip.description" in src
