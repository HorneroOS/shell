"""Composable dashboard extension layout (shell#378).

Covers the manifest dashboard card hints (validator + schema +
runtime gates), the persisted user layout, the responsive/sectioned
scrolling cards host, keyboard configuration, and the 33-plugin
stress fixture (validator-functional plus an offscreen QML probe of
the layout math). Offscreen evidence is labelled as such: no
compositor or AT-SPI claim is made here.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = (ROOT / "schemas/plugin-manifest.schema.json").read_text()
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text()
SERVICE = (ROOT / "services/Plugins.qml").read_text()
CARDS = (ROOT / "modules/plugins/PluginDashboardCards.qml").read_text()
LAYOUT = (ROOT / "modules/plugins/DashboardLayout.qml").read_text()
PLUGIN_CONFIG = (ROOT / "config/PluginsConfig.qml").read_text()
CONFIG = (ROOT / "config/Config.qml").read_text()
DOCS = (ROOT / "docs/PLUGINS.md").read_text()

_spec = importlib.util.spec_from_file_location(
    "validate_plugin", ROOT / "scripts/validate_plugin.py")
VALIDATOR = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(VALIDATOR)


def _plugin(tmp_path: Path, plugin_id: str, dashboard_surface=None,
            surface_name="dashboard") -> Path:
    root = tmp_path / plugin_id
    root.mkdir(parents=True)
    surface = {"entrypoint": "Dash.qml"}
    if dashboard_surface:
        surface.update(dashboard_surface)
    manifest = {
        "schemaVersion": 2,
        "id": plugin_id,
        "name": f"Card {plugin_id}",
        "version": "1.0.0",
        "description": "Dashboard card layout fixture.",
        "author": "Hornero QA",
        "license": "MIT",
        "entrypoint": "Main.qml",
        "placement": "background",
        "surfaces": {surface_name: surface},
        "files": ["Main.qml", "Dash.qml", "README.md", "LICENSE"],
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
    }
    (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    for name in ("Main.qml", "Dash.qml"):
        (root / name).write_text("import QtQuick\nItem {}\n", encoding="utf-8")
    (root / "README.md").write_text(f"# {plugin_id}\nFixture.\n", encoding="utf-8")
    (root / "LICENSE").write_text("MIT\n", encoding="utf-8")
    return root


def test_dashboard_hints_accepted_and_carried(tmp_path):
    root = _plugin(tmp_path, "hinted-card",
                   {"size": "wide", "category": "System"})
    VALIDATOR.validate_plugin(root)  # must not raise
    manifest = json.loads((root / "manifest.json").read_text())
    effective = VALIDATOR.effective_surfaces(manifest)
    assert effective["dashboard"]["size"] == "wide"
    assert effective["dashboard"]["category"] == "System"


def test_unhinted_and_v1_effective_surfaces_unchanged(tmp_path):
    root = _plugin(tmp_path, "plain-card")
    manifest = json.loads((root / "manifest.json").read_text())
    assert "size" not in VALIDATOR.effective_surfaces(manifest)["dashboard"]
    v1 = {"schemaVersion": 1, "entrypoint": "Main.qml", "placement": "dashboard"}
    assert VALIDATOR.effective_surfaces(v1) == {
        "dashboard": {"entrypoint": "Main.qml", "enabled": True}}


def test_dashboard_hint_rejects(tmp_path):
    cases = [
        ({"size": "giant"}, "dashboard", "size must be one of"),
        ({"category": ""}, "dashboard", ".category must be"),
        ({"category": "Pinned"}, "dashboard", "reserved"),
        ({"category": "x" * 41}, "dashboard", ".category must be"),
        ({"size": "wide"}, "bar", "only"),
        ({"category": "System"}, "desktop", "only"),
    ]
    for i, (surface, name, needle) in enumerate(cases):
        root = _plugin(tmp_path, f"bad-hint-{i}", surface, surface_name=name)
        try:
            VALIDATOR.validate_plugin(root)
        except VALIDATOR.ValidationError as error:
            assert needle in str(error), (needle, str(error))
        else:
            raise AssertionError(f"{surface} on {name} must be rejected")


def test_stress_fixture_33_plugins_validate(tmp_path):
    sizes = ("compact", "standard", "wide")
    categories = ("System", "Media", "Network")
    for i in range(33):
        hints = {"size": sizes[i % 3]} if i % 4 else {"category": categories[i % 3]}
        root = _plugin(tmp_path, f"stress-{i:02d}", hints)
        VALIDATOR.validate_plugin(root)  # every one of the 33 must accept


def test_schema_host_service_hint_mirrors():
    for size in ("compact", "standard", "wide"):
        assert f'"{size}"' in SCHEMA and f'"{size}"' in SERVICE
    assert '"category"' in SCHEMA and "surface.category" in HOST
    assert "only allowed on the dashboard surface" in HOST
    # Host copies expose the hints so cards never re-read surfaces.
    assert "cardSize:" in SERVICE and "category:" in SERVICE


def test_persisted_user_layout_contract():
    assert "property var dashboardLayout" in PLUGIN_CONFIG
    for fn in ("setDashboardPinned", "setDashboardCardSize", "setDashboardOrder"):
        assert f"function {fn}" in PLUGIN_CONFIG
        assert "saveRequested()" in PLUGIN_CONFIG
    assert "dashboardLayout: plugins.dashboardLayout" in CONFIG
    assert '["compact", "standard", "wide"]' in PLUGIN_CONFIG


def test_cards_host_is_composable_not_fixed_grid():
    assert "columns: 2" not in CARDS, "the fixed 2-column grid must stay gone"
    assert "Flickable" in CARDS and "Flickable.VerticalFlick" in CARDS
    assert "columns: root.columns" in CARDS
    assert "columnsForWidth" in LAYOUT and "sectionsFor" in LAYOUT
    assert "sectionsFor(Plugins.dashboardPlugins(), Config.plugins.dashboardLayout)" in CARDS
    assert "Layout.columnSpan" in CARDS and "contentWidth(" in CARDS
    assert "asynchronous: true" in CARDS
    # Standard class keeps the historic 380px dashboard width contract.
    assert "standard: 380" in LAYOUT
    # Layout math is one computation, not per-card work.
    assert CARDS.count("layoutHelper.sectionsFor(Plugins.dashboardPlugins()") == 1


def test_keyboard_configuration_contract():
    assert "activeFocusOnTab: true" in CARDS
    assert "Keys.onPressed" in CARDS and "handleCardKey" in CARDS
    for needle in ("Qt.ControlModifier", "Qt.Key_P", "Qt.Key_S",
                   "Qt.Key_PageDown", "Config.plugins.setDashboardOrder",
                   "Config.plugins.setDashboardPinned",
                   "Config.plugins.setDashboardCardSize",
                   "movedOrder", "nextSize"):
        assert needle in CARDS + LAYOUT, needle
    assert "Accessible.name" in CARDS and "Accessible.description" in CARDS


def test_docs_describe_dashboard_layout():
    for needle in ("dashboardLayout", "Ctrl+arrows", "category",
                   "compact", "Pinned"):
        assert needle in DOCS, needle


def test_dashboard_layout_offscreen(tmp_path):
    """Runtime probe (#378): the layout math offscreen — columns,
    grouping/pinning/order, reorder math and the 33-plugin stress
    bound. QML-level (offscreen) evidence only; skips without Qt6
    qmltestrunner.
    """
    import os
    import shutil
    import subprocess

    import pytest

    runner = Path("/usr/lib/qt6/bin/qmltestrunner")
    if not runner.is_file():
        candidate = shutil.which("qmltestrunner6")
        if not candidate:
            pytest.skip("NOT RUN (offscreen): Qt6 qmltestrunner not available")
        runner = Path(candidate)
    test_dir = tmp_path / "qa"
    test_dir.mkdir()
    shutil.copy(ROOT / "modules/plugins/DashboardLayout.qml",
                test_dir / "DashboardLayout.qml")
    fixture = test_dir / "tst_dashboard_layout.qml"
    shutil.copy(ROOT / "tests/qa/tst_dashboard_layout.qml", fixture)
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen")
    result = subprocess.run(
        [str(runner), "-input", str(fixture)],
        capture_output=True, text=True, env=env, timeout=120)
    out = result.stdout + result.stderr
    assert "DashboardLayout" in out, out
    assert "0 failed" in out, out
    assert result.returncode == 0, out
