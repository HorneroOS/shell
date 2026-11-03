"""Control Center parity surfaces: ctl-backed cards wired into the
Appearance, Displays, Input, Updates and System panes.

Every surface must go through the shared CtlCard / horneroctl argv
contract (never a shell string), carry loading/error states, and gate
mutations behind the two-step armed confirm.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CC = ROOT / "modules" / "controlcenter"


def _read(path):
    return path.read_text()


def test_ctl_card_is_allowlisted_argv_only_with_states_and_confirm():
    card = _read(CC / "components" / "CtlCard.qml")
    assert 'required property var probeArgv' in card
    assert "probeProc.command = root.probeArgv" in card
    assert "StdioCollector" in card
    assert "JSON.parse" in card
    # Loading, error, empty/not-run states are all rendered.
    assert 'qsTr("Working…")' in card
    assert "Colours.palette.m3error" in card
    assert 'qsTr("Not run yet.")' in card
    assert 'qsTr("No data reported.")' in card
    # Mutations are two-step armed and refresh the probe afterwards.
    assert "root.armed = true" in card
    assert 'qsTr("Click again to confirm")' in card
    assert "root.runProbe()" in card
    # No shell-string execution in the shared card.
    assert "sh -c" not in card and "execDetached" not in card


def test_system_pane_diagnostics_are_read_only_probes():
    pane = _read(CC / "system" / "SystemPane.qml")
    for leaf in ('"doctor"', '"config", "validate"', '"system", "info"',
                 '"shell", "status"', '"shell", "logs", "--lines", "20"'):
        assert leaf in pane, f"missing diagnostics leaf {leaf}"
    diagnostics = pane.split('qsTr("Diagnostics")', 1)[1]
    assert "CtlCard" in diagnostics
    assert "--yes" not in diagnostics, "diagnostics must stay read-only"
    assert "--fix" not in diagnostics


def test_updates_dependencies_and_recovery_section():
    pane = _read(CC / "updates" / "UpdatesPane.qml")
    assert 'qsTr("Dependencies & recovery")' in pane
    assert '"package", "deps"' in pane
    assert '"package", "deps", "--install", "--yes"' in pane
    assert '"config", "snapshot", "list"' in pane
    assert '"config", "snapshot", "create", "--yes"' in pane
    assert '"config", "snapshot", "restore", root.snapshotIdField.trim(), "--yes"' in pane
    assert '"backup", "schedule"' in pane
    # Honest rollback note keyed to the CLI's machine-readable
    # snapshot_backend field, never to the human snapshot_status prose
    # (the prose comparison made the warning dead code: the backend
    # emits 'unavailable: ...', never the bare word).
    assert 'root.snapshotBackend === "none"' in pane
    assert 'env.data.snapshot_backend' in pane
    assert 'root.snapshotStatus === "unavailable"' not in pane
    assert "Update rollback is unavailable" in pane


def test_appearance_health_section_registered_and_searchable():
    pane = _read(CC / "appearance" / "AppearancePane.qml")
    assert '"health"' in pane.split("_sectionKeys", 1)[1].split("]", 1)[0]
    assert "health: healthSection" in pane
    assert "HealthSection" in pane
    section = _read(CC / "appearance" / "sections" / "HealthSection.qml")
    assert '"appearance", "status"' in section
    assert '"appearance", "doctor"' in section
    assert '"appearance", "sync", "--yes"' in section
    assert "colors\", \"m3\", \"--\"" not in section  # unsafe argv passthrough stays out


def test_input_restore_defaults_are_armed_ctl_calls():
    pane = _read(CC / "input" / "InputPane.qml")
    assert 'qsTr("Restore defaults")' in pane
    assert '"hardware", "keyboard", "layout", "--restore", "--yes", "--json"' in pane
    assert '"hypr", "input", "restore", "--yes", "--json"' in pane
    assert '"hypr", "cursor", "restore", "--yes", "--json"' in pane
    assert "root.armedRestore" in pane  # second click confirms


def test_displays_brightness_and_compositor_controls():
    pane = _read(CC / "displays" / "DisplaysPane.qml")
    assert '"hardware", "brightness", "status"' in pane
    assert '"hardware", "brightness", "set"' in pane
    assert "brightnessTimer.restart()" in pane  # slider debounces to the ctl
    assert '"hypr", "layout", "current"' in pane
    assert '"hypr", "layout", "set", layout, "--yes"' in pane
    assert '"hypr", "layout", "restore", "--yes"' in pane
    assert '"hypr", "animations", "list"' in pane
    assert '"hypr", "animations", "set", profile, "--yes"' in pane
    assert '"hypr", "animations", "restore", "--yes"' in pane
    # Honest unavailable state off-Hyprland, nothing faked.
    assert "Compositor controls are unavailable" in pane
    # No per-output resolution/scale editing (no ctl leaf exists yet).
    assert '"hypr", "monitors", "set"' in pane  # only existing arrangement modes
    assert "--resolution" not in pane and "scale\", \"" not in pane


def test_search_targets_cover_new_surfaces():
    registry = _read(CC / "PaneRegistry.qml")
    for target in ("appearance-health", "brightness", "compositor-layout",
                   "input-restore", "diagnostics", "dependencies-recovery"):
        assert f'"{target}"' in registry, f"missing search target {target}"
    for keyword in ("brightness", "restore", "doctor", "snapshots"):
        assert keyword in registry
