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
    # respects the bars' zones (a right/bottom bar never covers it) and
    # reserves nothing itself
    assert "ExclusionMode.Normal" in nest and "exclusiveZone: 0" in nest
    assert "ExclusionMode.Ignore" not in nest
    assert "Habitat.layout(root.settings, win.modelData.width, win.modelData.height, win.insets)" in nest
    assert "Visibilities.bars.get(win.modelData)" in nest
    # one monitor, never the focused output
    assert "Habitat.resolveScreen(" in nest and "focusedOutputName" not in nest
    assert "model: root.wanted ? Quickshell.screens : []" in nest
    assert "mask: Region" in nest
    # no ambient polling beyond the two gated timers
    assert nest.count("Timer {") == 2
    assert "running: root.wanted" in nest
    assert "triggeredOnStart: true" in nest
    # blinking and the status probe only while the LEDs are drawn
    assert "running: root.ledsShown && root.anyBlink" in nest
    assert "if (root.ledsShown)\n                root.bridge.refreshStatus();" in nest
    assert "Habitat.linkState(" in nest
    # no literal user-facing strings: the accessible name is catalogued
    assert "qsTr(" not in nest and 'JaviVoice.line("nest.accessible"' in nest
    # lights come from the pure policy, never painted literal colours
    assert "Habitat.lights(" in nest and "Signal.palette[" in nest
    assert "#" not in "".join(l for l in nest.splitlines() if "Color" in l or "color:" in l and "Signal" not in l)
    # host: input mask covers only visible parts; habitat is a child
    assert "mask: Region" in host
    for part in ("item: spriteRow", "bubble.visible ? bubble : null", "chatPanel.visible ? chatPanel : null", "menu.visible ? menu : null"):
        assert part in host, part
    assert "NestHabitat {" in host and "Habitat.homeFraction" in host
    # home flight only on the nest's screen, with the bars' insets
    assert "nestHabitat.screenName === win.modelData.name" in host
    assert "readonly property var habitat: nestHabitat" in host
    # the radio click falls back to the chat only when Javi Radio does not
    # claim it
    assert 'action === "radio" && root.radioHandlesNest === true' in host
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
    assert 'defaultValue: "none"' in section
    # the stage-skip button is a developer aid only
    btn = section.split('qsTr("Build the next stage now")')[0].rsplit("TextButton {", 1)[1]
    assert 'Quickshell.env("HORNERO_COMPANION_DEV") === "1"' in btn
    assert "placeholder" in section.lower()


def test_manifest_lights_are_parsed_for_the_runtime():
    comp = (COMP / "Companion.qml").read_text()
    assert "nestLights" in comp and "nestScreen" in comp
