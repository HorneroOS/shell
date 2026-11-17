"""Nest habitat runtime: QML wiring contract (no compositor needed)."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMP = ROOT / "modules" / "companion"


def test_qml_wiring_contract():
    nest = (COMP / "NestHabitat.qml").read_text()
    host = (COMP / "CompanionHost.qml").read_text()
    store = (COMP / "CompanionStore.qml").read_text()
    # surface hygiene
    assert "WlrLayer.Bottom" in nest and "WlrKeyboardFocus.None" in nest
    assert "ExclusionMode.Ignore" in nest
    assert "model: root.wanted ? Quickshell.screens : []" in nest
    assert "mask: Region" in nest
    # no ambient polling beyond the two gated timers
    assert nest.count("Timer {") == 2
    assert "running: root.wanted" in nest
    # lights come from the pure policy, never painted literal colours
    assert "Habitat.lights(" in nest and "Signal.palette[" in nest
    assert "#" not in "".join(l for l in nest.splitlines() if "Color" in l or "color:" in l and "Signal" not in l)
    # host: input mask covers only visible parts; habitat is a child
    assert "mask: Region" in host
    for part in ("item: spriteRow", "bubble.visible ? bubble : null", "chatPanel.visible ? chatPanel : null", "menu.visible ? menu : null"):
        assert part in host, part
    assert "NestHabitat {" in host and "Habitat.homeFraction" in host
    assert 'placement === "withJavi"' in host
    # store: persisted and re-validated
    assert "prefs: persist.prefs" in store and "o.prefs" in store
    assert "Habitat.sanitize" in store


def test_habitat_section_is_in_the_pane_and_covers_the_settings():
    cc = ROOT / "modules" / "controlcenter" / "companion"
    pane = (cc / "CompanionPane.qml").read_text()
    section = (cc / "HabitatSection.qml").read_text()
    assert "HabitatSection {}" in pane
    for key in ("placement", "anchor", "marginX", "marginY", "scale", "monitor",
                "lighting", "intensity", "indicators", "phosphor",
                "dimInQuietHours", "clickAction", "modeLevel."):
        assert f'"{key}' in section, key
    assert 'resetPref("habitat")' in section
    assert "placeholder" in section.lower()


def test_manifest_lights_are_parsed_for_the_runtime():
    comp = (COMP / "Companion.qml").read_text()
    assert "nestLights" in comp and "nestScreen" in comp
