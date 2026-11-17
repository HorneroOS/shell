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
                   "radius: Appearance.rounding.normal", "Signal.tPalette.panel",
                   "settle", 'section: "end"', "fallbackSections",
                   # structural copy of Tray.qml: Column/Row with scale-in add and
                   # animated move, bar-driven expansion, the tray chevron
                   "add: Transition", "move: Transition", "property bool expanded",
                   "readonly property real nonAnimHeight", "id: expandIcon", "centerChildren: true"):
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


def test_extensions_config_mirrors_tray_keys_and_defaults():
    cfg = read("config/BarConfig.qml")
    tray = cfg.split("component Tray: JsonObject {")[1].split("}")[0]
    ext = cfg.split("component Extensions: JsonObject {")[1].split("}")[0]
    for key in ("background", "recolour", "compact", "iconSubs", "hiddenIcons"):
        assert key in tray and key in ext, key
    assert "property bool background: false" in ext
    persisted = read("config/Config.qml")
    for key in ("background", "recolour", "compact", "iconSubs", "hiddenIcons"):
        assert f"bar.extensions.{key}" in persisted, key
    import json as _json
    factory = _json.loads(read("config/shell.default.json"))
    assert factory["bar"]["extensions"] == factory["bar"]["tray"]


def test_control_center_extensions_settings_match_tray():
    pane = read("modules/controlcenter/taskbar/TaskbarPane.qml")
    for name in ("extensionsBackground", "extensionsCompact", "extensionsRecolour"):
        assert f"property bool {name}" in pane, name
        assert f"Config.bar.extensions.{name.removeprefix('extensions').lower()} = root.{name}" in pane, name
    assert pane.count('label: qsTr("Recolour")') == 2  # tray and extensions


def test_fallback_layouts_render_the_island_not_a_bare_stack():
    bar = read("modules/bar/Bar.qml")
    end_block = bar.split("render the same island here")[0].rsplit("ExtensionsIsland {", 1)
    assert len(end_block) == 2 and 'group.name === "end"' in end_block[1][:400]
    island = read("modules/bar/components/ExtensionsIsland.qml")
    assert "surfaceActive" in island
    assert "Config.bar.extensions.hiddenIcons" in island
    assert "Config.bar.extensions.recolour" in island
    widgets = read("modules/plugins/PluginBarWidgets.qml")
    assert "hiddenIds" in widgets
