"""Bar extension indicators join native islands (shell#439): a bar surface
may declare section status/actions/clock/end; each island embeds a host
filtered by section with the island's icon style; missing islands fall back
to the end host; the contract is enforced in schema, validator and runtime.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_contract_declares_bar_only_section():
    schema = json.loads(read("schemas/plugin-manifest.schema.json"))
    assert schema["$defs"]["surface"]["properties"]["section"]["enum"] == ["status", "actions", "clock", "end"]
    validator = read("scripts/validate_plugin.py")
    assert 'BAR_SECTIONS = ("status", "actions", "clock", "end")' in validator
    assert "section is a bar hint and is only allowed on the bar surface" in validator
    host = read("modules/plugins/PluginHost.qml")
    assert 'key !== "section"' in host and 'name !== "bar"' in host
    assert 'barSection: typeof declared.section === "string" ? declared.section : "end"' in read("services/Plugins.qml")


def test_islands_embed_section_hosts_with_their_style():
    for rel, section in (("modules/bar/components/StatusIcons.qml", "status"),
                         ("modules/bar/components/QuickActions.qml", "actions"),
                         ("modules/bar/components/Clock.qml", "clock")):
        src = read(rel)
        assert "import qs.modules.plugins" in src, rel
        assert f'section: "{section}"' in src, rel
        assert "iconColour:" in src and "iconSize:" in src, rel
    widgets = read("modules/plugins/PluginBarWidgets.qml")
    assert "readonly property int hostIconSize: root.iconSize" in widgets
    assert "root.fallbackSections.includes" in widgets
    assert "fallbackSections:" in read("modules/bar/Bar.qml")


def test_pluginkit_adopts_island_style():
    button = read("plugin/qml/Hornero/PluginKit/UiButton.qml")
    assert '"hostIconSize" in p' in button and "root.hostStyle.hostIconColor" in button
    assert "property int size: 0" in read("plugin/qml/Hornero/PluginKit/UiIcon.qml")
