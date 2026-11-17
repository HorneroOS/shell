"""Experience pane contract (RFC 0001 §5a, Visual Language §13).

#479 shipped the Experience service, profiles, IPC and shell hooks, and
its toast already pointed at "Settings › Experience" — but no pane
existed. This pins the Control Center pane: registered and imported,
switching/customising only through the service (never writing config
or state itself), every customisable field reachable, locked guardrail
fields disabled, unavailable hooks reported, and the per-mode
density/glow/cadence/motion actually consumed by the shell.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CC = ROOT / "modules" / "controlcenter"
PANE = CC / "experience" / "ExperiencePane.qml"
SRC = PANE.read_text()
FIELDS = [
    "motion", "density", "glow", "scanlines", "telemetry.rateHz",
    "telemetry.pauseWhenHidden", "desktopWidgets", "notifications.hold",
    "notifications.suppressFullscreen", "layout.preset", "layout.apply",
    "idle.inhibitFullscreen", "power.suggest", "hooks.hyprlandTuning",
    "hooks.studioAudio",
]


def test_pane_registered_and_imported():
    reg = (CC / "PaneRegistry.qml").read_text()
    assert 'readonly property string id: "experience"' in reg
    assert '"experience/ExperiencePane.qml"' in reg
    assert PANE.is_file()
    assert 'import "experience"' in (CC / "Panes.qml").read_text()
    # Settings search reaches the pane too.
    assert 'property string pane: "experience"' in reg


def test_pane_opens_with_registry_header_and_session():
    assert "PaneHeader {" in SRC
    assert 'paneId: "experience"' in SRC
    assert "required property Session session" in SRC
    assert "SettingsHeader" not in SRC


def test_pane_lists_and_switches_modes_through_the_service():
    assert "Experience.summary" in SRC
    assert 'Experience.set(id, "user")' in SRC
    assert "Experience.revert()" in SRC
    assert "Experience.reset()" in SRC
    assert "Experience.setAuto(checked)" in SRC


def test_every_customisable_field_is_reachable_and_persisted_by_service():
    for field in FIELDS:
        assert f'"{field}"' in SRC, field
    assert "Experience.customise(root.selectedMode, key, value)" in SRC
    assert "Experience.resetCustomisations(root.selectedMode)" in SRC
    # The pane never writes the state file or shell.json itself; the
    # only direct Config write is the toasts preference, through save().
    assert "FileView" not in SRC and "writeProc" not in SRC
    assert "Config.experience.modes =" not in SRC
    assert re.findall(r"Config\.(?!experience\.modes\b)[\w.]+ =", SRC) == [
        "Config.experience.toasts ="
    ]


def test_locked_guardrail_fields_are_disabled_not_silently_ignored():
    assert "Experience.isLocked(root.selectedMode, key)" in SRC
    assert 'enabled: !root.locked("glow")' in SRC
    assert 'enabled: !root.locked("scanlines")' in SRC
    assert 'rowLocked: root.locked("motion")' in SRC


def test_unavailable_hooks_are_reported_not_faked():
    assert "!Experience.hyprlandTuningAvailable" in SRC
    assert "Experience.probeStudioAudio()" in SRC
    assert "Experience.studioAudioAvailable" in SRC
    assert "Experience.studioAudioMessage" in SRC


def test_service_errors_reach_the_user():
    # customise/set/revert/reset all surface their "error: ..." result.
    assert SRC.count('res.startsWith("error")') >= 4
    assert "Experience.lastError" in SRC


def test_preview_consumes_density_glow_scanlines_and_cadence():
    assert 'root.field("density")' in SRC
    assert 'root.field("glow")' in SRC and "Experience.glow" in SRC
    assert 'root.field("scanlines")' in SRC and "Experience.scanlines" in SRC
    assert 'root.field("telemetry.rateHz")' in SRC
    assert 'root.field("motion")' in SRC


def test_modes_are_actually_applied_by_the_shell():
    """Density, motion, cadence, popup policy and the desktop layer are
    consumed outside the pane (shipped in #479; pinned here so the pane
    never advertises a knob nothing reads)."""
    bar = (ROOT / "modules" / "bar" / "Bar.qml").read_text()
    assert "Experience.barDensity(" in bar
    svc = (ROOT / "services" / "Experience.qml").read_text()
    assert "Appearance.anim.level = Qt.binding(() => root.motionLevel)" in svc
    usage = (ROOT / "services" / "SystemUsage.qml").read_text()
    assert "Experience.telemetryIntervalMs" in usage
    assert "Experience.telemetryPaused" in usage
    notifs = (ROOT / "services" / "Notifs.qml").read_text()
    assert "Experience.holdPopups" in notifs
    background = (ROOT / "modules" / "background" / "Background.qml").read_text()
    assert "Experience.desktopWidgetsVisible" in background
    bridge = (ROOT / "plugin" / "qml" / "Hornero" / "PluginKit" / "ExperienceBridge.qml").read_text()
    assert "Experience.glow" in bridge and "Experience.scanlines" in bridge


def test_no_material_remnants_or_retired_wrappers():
    for dead in ("Material", "m3", "dots-"):
        assert dead not in SRC, dead
