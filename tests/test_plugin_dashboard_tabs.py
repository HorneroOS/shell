"""Dashboard page contributions (PluginKit 5, shell#709)."""

import importlib.util
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

from tests.pluginkit_harness import ROOT

SPEC = importlib.util.spec_from_file_location("hornero_validator_dash_tabs", ROOT / "scripts/validate_plugin.py")
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)
SCHEMA = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
SERVICE = (ROOT / "services/Plugins.qml").read_text()
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text()
TAB_HOST = (ROOT / "modules/plugins/PluginDashboardTab.qml").read_text()
CONTENT = (ROOT / "modules/dashboard/Content.qml").read_text()
TABS = (ROOT / "modules/dashboard/Tabs.qml").read_text()
SHORTCUTS = (ROOT / "modules/Shortcuts.qml").read_text()

PAGE_QML = "import QtQuick\nItem {}\n"
TABS_CONTRIB = {"dashboardTabs": [{"id": "agents", "title": "Agents", "glyph": "robot"}]}
SURF = {"dashboardTab": {"entrypoint": "Page.qml"}}


def make(tmp_path, contributes, surfaces, level=5):
    root = tmp_path / "t-pkg"
    root.mkdir()
    data = {
        "schemaVersion": 3, "pluginKit": level, "id": "t-pkg", "name": "T", "version": "1.0.0",
        "description": "d", "author": "a", "license": "MIT", "entrypoint": "Main.qml",
        "files": ["Main.qml", "Page.qml", "README.md", "LICENSE"],
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
        "contributes": contributes, "surfaces": surfaces,
    }
    (root / "manifest.json").write_text(json.dumps(data))
    for name in ("Main.qml", "Page.qml"):
        (root / name).write_text(PAGE_QML)
    (root / "README.md").write_text("# x\n")
    (root / "LICENSE").write_text("MIT\n")
    return root


def test_dashboard_tab_validates_and_schema_agrees(tmp_path):
    pkg = make(tmp_path, TABS_CONTRIB, SURF)
    V.validate_plugin(pkg)
    manifest = json.loads((pkg / "manifest.json").read_text())
    assert not list(Draft202012Validator(SCHEMA).iter_errors(manifest))


@pytest.mark.parametrize(("contributes", "surfaces", "level", "message"), [
    (TABS_CONTRIB, {"dashboardTab": {"entrypoint": "Page.qml"}}, 4, "PluginKit 5"),
    (TABS_CONTRIB, {"settings": {"entrypoint": "Page.qml"}}, 5, "needs surfaces.dashboardTab"),
    ({"commands": [{"id": "c", "title": "C"}]}, {**SURF, "commands": {"entrypoint": "Page.qml"}}, 5,
     "needs contributes.dashboardTabs"),
    ({"dashboardTabs": [{"id": "a", "title": "A"}, {"id": "b", "title": "B"}, {"id": "c", "title": "C"}]},
     SURF, 5, "1 to 2"),
    ({"dashboardTabs": [{"id": "a", "title": "A"}, {"id": "a", "title": "B"}]}, SURF, 5, "duplicates"),
    ({"dashboardTabs": [{"id": "media", "title": "Agents"}]}, SURF, 5, "reserved"),
    ({"dashboardTabs": [{"id": "agents", "title": "Extensions"}]}, SURF, 5, "must not reuse"),
    ({"dashboardTabs": [{"id": "agents", "title": "Agents", "order": 1}]}, SURF, 5, "unknown fields"),
])
def test_invalid(tmp_path, contributes, surfaces, level, message):
    with pytest.raises(V.ValidationError, match=message):
        V.validate_plugin(make(tmp_path, contributes, surfaces, level=level))


def test_runtime_contract_is_mirrored():
    # Service: manifest-only listing with stable identity + pending key.
    assert "function dashboardTabList()" in SERVICE
    assert "pluginsForSurface(\"dashboardTab\")" in SERVICE
    assert "key: `${entry.id}:${tab.id}`" in SERVICE
    assert "pendingDashboardTabKey" in SERVICE
    assert "dashboardTabs: 2" in SERVICE
    # Host runtime gate: known surface, PluginKit 5 required.
    assert '"dashboardTab"' in HOST
    assert "PluginKit 5 surface and requires pluginKit 5" in HOST
    # Page host: isolated async Loader, dashboardTab failure surface.
    assert 'hostSurface: "dashboardTab"' in TAB_HOST
    assert 'markFailed(root.tab.pluginId' in TAB_HOST and '"dashboardTab"' in TAB_HOST
    # Dashboard: keyed selection, extension pages before Extensions,
    # pending deep link consumed on load.
    assert "currentTabKey" in CONTENT
    assert "PluginDashboardTab" in CONTENT
    assert "consumePendingTab" in CONTENT
    assert CONTENT.index("ExtPane {}") < CONTENT.index("sourceComponent: Extensions")
    assert "tabItems" in TABS and "currentTabKey" in TABS
    # Deep link IPC lives with the other drawer verbs.
    assert "function dashboardTab(key: string)" in SHORTCUTS
    assert "Plugins.requestDashboardTab(key)" in SHORTCUTS
