"""Extensions bar island (shell#441): extension indicators get their own
island that looks and behaves like the system tray island, configurable in
Control Center the same way, in the default layout and the presets next to
the tray; layouts without it keep the historic end placement.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_island_mirrors_the_tray_island():
    island = read("modules/bar/components/ExtensionsIsland.qml")
    for needle in ("Config.bar.extensions.background", "Config.bar.extensions.compact",
                   "radius: Appearance.rounding.full", "Colours.tPalette.m3surfaceContainer",
                   "expressiveDefaultSpatial", "HoverHandler", 'section: "end"', "fallbackSections"):
        assert needle in island, needle


def test_bar_renders_the_island_and_gates_the_legacy_block():
    bar = read("modules/bar/Bar.qml")
    assert 'roleValue: "extensions"' in bar and "ExtensionsIsland {" in bar
    assert '"extensions": "end"' in bar
    assert 'surfaceActive: group.name === "end" && !root.presentSections.includes("end")' in bar


def test_island_is_configurable_and_persisted():
    cfg = read("config/BarConfig.qml")
    assert "property Extensions extensions: Extensions {}" in cfg
    assert '{id: "extensions", enabled: true}' in cfg
    assert "extensions: {" in read("config/Config.qml")
    pane = read("modules/controlcenter/taskbar/TaskbarPane.qml")
    assert 'qsTr("Extensions Settings")' in pane
    assert "Config.bar.extensions.compact = root.extensionsCompact" in pane


def test_presets_with_a_tray_also_get_the_island():
    for path in sorted((ROOT / "presets").glob("*.json")):
        text = path.read_text(encoding="utf-8")
        if '"tray"' in text:
            assert '"extensions"' in text, path.name
            json.loads(text)
