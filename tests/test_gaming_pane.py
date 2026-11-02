"""Gaming pane contract: ctl-backed profiles/power/diagnostics, no shell."""
from pathlib import Path

ROOT = Path(__file__).parent.parent
PANE = (ROOT / "modules/controlcenter/gaming/GamingPane.qml").read_text()
REGISTRY = (ROOT / "modules/controlcenter/PaneRegistry.qml").read_text()


def test_gaming_pane_registered():
    assert '"gaming/GamingPane.qml"' in REGISTRY
    assert 'readonly property string id: "gaming"' in REGISTRY


def test_gaming_pane_uses_only_allowlisted_ctl_leaves():
    assert '["horneroctl", "--json", "gaming", "doctor"]' in PANE
    assert '["horneroctl", "--json", "gaming", "selection", "show"]' in PANE
    assert '"gaming", "selection", "set"' in PANE
    assert '["horneroctl", "--json", "apps", "performance", "mode"]' in PANE
    assert '"apps", "performance", "mode", "set", profile, "--yes"' in PANE
    for forbidden in ("pacman", "paru", "sh -c", "bash -c", "pkexec",
                      "powerprofilesctl", "gamemoderun", "gamescope -", "systemctl"):
        assert forbidden not in PANE, forbidden


def test_gaming_selection_installs_nothing_and_steam_is_optin():
    assert "No packages were installed or removed by recording it" in PANE
    assert "Steam is proprietary and always an explicit opt-in" in PANE
    assert '"steam"' in PANE and '"desktop-gaming"' in PANE
    # Reference-only catalogue apps are visible but not toggleable.
    assert 'modelData.id !== "heroic-games-launcher"' in PANE
    assert 'modelData.id !== "steamvr"' in PANE
    assert "never deletes your files, settings, or games" in PANE


def test_gaming_performance_mode_is_two_step_and_reversible():
    assert "armedProfile" in PANE
    assert "Confirm %1" in PANE
    assert "pick another profile to change back" in PANE
    assert "no improvement is guaranteed" in PANE.lower()
    for profile in ("power-saver", "balanced", "performance"):
        assert f'"{profile}"' in PANE


def test_gaming_pane_separates_focus_session_and_feral():
    assert "Gaming Focus" in PANE
    assert "Feral GameMode" in PANE
    assert "GameMode.enabled" in PANE
    assert "Gaming session" in PANE
    assert "chosen at the greeter" in PANE
    assert "Gaming is Preview" in PANE
    assert "not hardware qualification" in PANE


def test_gaming_diagnostics_have_loading_error_and_empty_states():
    assert "Running diagnostics" in PANE
    assert "Gaming diagnostics returned no checks" in PANE
    assert "doctorLoading" in PANE
    assert "doctorError" in PANE
