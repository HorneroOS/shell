"""Gaming pane contract: read-only doctor consumer, no writers, no shell."""
from pathlib import Path

ROOT = Path(__file__).parent.parent
PANE = (ROOT / "modules/controlcenter/gaming/GamingPane.qml").read_text()
REGISTRY = (ROOT / "modules/controlcenter/PaneRegistry.qml").read_text()


def test_gaming_pane_registered():
    assert '"gaming/GamingPane.qml"' in REGISTRY
    assert 'readonly property string id: "gaming"' in REGISTRY


def test_gaming_pane_only_reads_doctor():
    assert '["horneroctl", "--json", "gaming", "doctor"]' in PANE
    for forbidden in ("\"selection\"", "pacman", "sh -c", "pkexec", "gamemode\""):
        assert forbidden not in PANE, forbidden


def test_gaming_pane_separates_focus_from_feral():
    assert "Gaming Focus" in PANE
    assert "Feral GameMode" in PANE
    assert "GameMode.enabled" in PANE
    assert "Planned" in PANE
    assert "not hardware qualification" in PANE
