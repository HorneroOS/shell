"""Plugin runtime loader: static QML contract tests.

The loader must stay horneroctl-mediated for lifecycle state, isolate
faults per plugin, and never claim sandboxing it does not provide.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICE = (ROOT / "services" / "Plugins.qml").read_text()
HOST = (ROOT / "modules" / "plugins" / "PluginHost.qml").read_text()
SHELL = (ROOT / "shell.qml").read_text()
DOCS = (ROOT / "docs" / "PLUGINS.md").read_text()
IPC = (ROOT / "docs" / "IPC.md").read_text()


def test_service_discovers_via_horneroctl_only():
    assert '"horneroctl", "plugin", "list", "--json"' in SERVICE
    # Lifecycle writes stay in horneroctl: the service never mutates
    # receipts or plugin payloads itself.
    for banned in ("plugin\", \"install", "plugin\", \"enable", "plugin\", \"remove",
                   "rmdir", "writeText"):
        assert banned not in SERVICE, f"service must stay read-only: {banned}"


def test_service_tracks_load_states():
    for state in ("pending", "loaded", "failed", "disabled"):
        assert f'"{state}"' in SERVICE


def test_host_fault_isolation_and_manifest_checks():
    # One Loader per plugin: a failing entrypoint cannot take down the
    # shell or its neighbours.
    assert "Loader" in HOST and "Loader.Error" in HOST
    assert "Plugins.markFailed" in HOST and "Plugins.markLoaded" in HOST
    # Entrypoint comes from the plugin's own manifest, id must match the
    # directory, and path traversal is rejected before loading.
    assert "manifest.json" in HOST
    assert "does not match its directory" in HOST
    assert 'includes("..")' in HOST


def test_host_wired_and_ipc_documented():
    assert "PluginHost {}" in SHELL
    assert 'target: "plugins"' in HOST
    for fn in ("status()", "reload()"):
        assert fn in HOST
    assert "`plugins`" in IPC and "reload()" in IPC


def test_trust_label_stays_honest():
    assert "NOT" in SERVICE and "sandboxed" in SERVICE
    assert "logged-in user's permissions" in DOCS
    assert "headless" in DOCS


BAR = (ROOT / "modules" / "bar" / "Bar.qml").read_text()
WIDGETS = (ROOT / "modules" / "plugins" / "PluginBarWidgets.qml").read_text()
SCHEMA = (ROOT / "schemas" / "plugin-manifest.schema.json").read_text()


def test_bar_placement_contract():
    assert '"placement"' in SCHEMA and '"bar"' in SCHEMA
    assert 'placement !== "background" && placement !== "bar"' in HOST
    # Bar plugins are not double-loaded by the headless host.
    assert 'slot.placement !== "bar"' in HOST
    assert "function barPlugins()" in SERVICE
    assert "Plugins.barPlugins()" in WIDGETS
    assert "PluginBarWidgets" in BAR and 'group.name === "end"' in BAR
    assert "Loader.Error" in WIDGETS and "Plugins.markFailed" in WIDGETS


CARDS = (ROOT / "modules" / "plugins" / "PluginDashboardCards.qml").read_text()
EXTENSIONS_PANE = (ROOT / "modules" / "dashboard" / "Extensions.qml").read_text()
DASH_CONTENT = (ROOT / "modules" / "dashboard" / "Content.qml").read_text()
DASH_TABS = (ROOT / "modules" / "dashboard" / "Tabs.qml").read_text()
VALIDATOR = (ROOT / "scripts" / "validate_plugin.py").read_text()


def test_dashboard_placement_contract():
    assert '"dashboard"' in SCHEMA
    assert '"dashboard"' in VALIDATOR
    assert 'placement !== "dashboard"' in HOST
    # Dashboard plugins are not double-loaded by the headless host.
    assert 'slot.placement !== "dashboard"' in HOST
    assert "function dashboardPlugins()" in SERVICE
    assert "Plugins.dashboardPlugins()" in CARDS
    # Per-plugin Loader isolation and honest failure marking, same
    # contract as the bar placement.
    assert "Loader.Error" in CARDS and "Plugins.markFailed" in CARDS
    assert "Plugins.markLoaded" in CARDS
    # The dashboard exposes the placement as its own tab (index 5).
    assert "PluginDashboardCards" in EXTENSIONS_PANE
    assert "sourceComponent: Extensions {}" in DASH_CONTENT
    assert 'text: qsTr("Extensions")' in DASH_TABS
    # The shipped example validates the placement end to end.
    example = ROOT / "examples" / "plugins" / "example-dashboard-note" / "manifest.json"
    assert '"placement": "dashboard"' in example.read_text()


WIDGETS_DESKTOP = (ROOT / "modules" / "plugins" / "PluginDesktopWidgets.qml").read_text()
BACKGROUND = (ROOT / "modules" / "background" / "Background.qml").read_text()


def test_desktop_placement_contract():
    assert '"desktop"' in SCHEMA
    assert '"desktop"' in VALIDATOR
    assert 'placement !== "desktop"' in HOST
    # Desktop plugins are not double-loaded by the headless host.
    assert 'slot.placement !== "desktop"' in HOST
    assert "function desktopPlugins()" in SERVICE
    assert "Plugins.desktopPlugins()" in WIDGETS_DESKTOP
    assert "Loader.Error" in WIDGETS_DESKTOP and "Plugins.markFailed" in WIDGETS_DESKTOP
    assert "Plugins.markLoaded" in WIDGETS_DESKTOP
    # Rendered on the desktop background layer, per screen.
    assert "PluginDesktopWidgets" in BACKGROUND
    example = ROOT / "examples" / "plugins" / "example-desktop-note" / "manifest.json"
    assert '"placement": "desktop"' in example.read_text()


def test_public_plugin_kit_is_installed_and_exposes_only_reviewed_types():
    kit = ROOT / "plugin" / "qml" / "Hornero" / "PluginKit"
    qmldir = (kit / "qmldir").read_text()
    assert "module Hornero.PluginKit" in qmldir
    for public_type in ("Theme", "Notifications", "Desktop", "Settings"):
        assert public_type in qmldir
        assert (kit / f"{public_type}.qml").is_file()
    assert "install(DIRECTORY qml/Hornero/PluginKit" in (ROOT / "plugin" / "CMakeLists.txt").read_text()
    assert "Hornero.PluginKit.Singletons" not in VALIDATOR


def test_plugin_settings_are_typed_namespaced_and_persisted_by_config():
    settings_api = (ROOT / "plugin/qml/Hornero/PluginKit/Settings.qml").read_text()
    plugin_config = (ROOT / "config/PluginsConfig.qml").read_text()
    config = (ROOT / "config/Config.qml").read_text()
    host = (ROOT / "modules/plugins/PluginHost.qml").read_text()
    service = (ROOT / "services/Plugins.qml").read_text()
    assert "Plugins.settingDeclaration(pluginId, key)" in settings_api
    assert "validValue(value, declaration.type)" in settings_api
    assert "next[pluginId][key] = value" in plugin_config
    assert "saveRequested()" in plugin_config and "root.save()" in config
    assert "serializePlugins()" in config
    assert "manifest.capabilities.settings" in host
    assert "function settingDeclaration" in service
    assert "Array.isArray(candidateValues)" in settings_api
    assert "Array.isArray(next[pluginId])" in plugin_config
    assert config.count("function onSaveRequested()") == 1
    notifications = (ROOT / "plugin/qml/Hornero/PluginKit/Notifications.qml").read_text()
    assert "import Hornero" in notifications


def test_desktop_widget_slots_persist_per_display_and_fallback_safely():
    plugin_config = (ROOT / "config/PluginsConfig.qml").read_text()
    desktop_api = (ROOT / "plugin/qml/Hornero/PluginKit/Desktop.qml").read_text()
    desktop_widgets = (ROOT / "modules/plugins/PluginDesktopWidgets.qml").read_text()
    extensions = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()
    position_picker = (ROOT / "modules/controlcenter/extensions/DesktopWidgetPosition.qml").read_text()
    assert '"top-left"' in plugin_config and '"bottom-right"' in plugin_config
    assert 'source[screenName || "default"]' in plugin_config
    assert '"bottom-right"' in plugin_config
    assert "Config.plugins.desktopWidgetSlot" in desktop_api
    assert "screenName" in desktop_widgets and "desktopWidgetSlot" in desktop_widgets
    assert "Quickshell.screens" in extensions and "DesktopWidgetPosition" in extensions
    assert "Config.plugins.setDesktopWidgetSlot" in position_picker
    assert "function setPosition" not in desktop_api
    assert "Users change placement in Control Center" in (ROOT / "docs/PLUGINS.md").read_text()
    assert "!Array.isArray(screenSlots)" in plugin_config
    assert "Array.isArray(next[screenId])" in plugin_config
    assert 'accessibleName: qsTr("%1 display, vertical widget position")' in position_picker
    assert 'accessibleName: qsTr("%1 display, horizontal widget position")' in position_picker
    assert "accessibleName: root.accessibleName" in (ROOT / "components/controls/SplitButtonRow.qml").read_text()


def test_all_placement_examples_use_only_public_plugin_api_and_qt():
    examples = {
        "bar": ROOT / "examples/plugins/example-clock/Main.qml",
        "dashboard": ROOT / "examples/plugins/example-dashboard-note/Main.qml",
        "desktop": ROOT / "examples/plugins/example-desktop-note/Main.qml",
    }
    for placement, path in examples.items():
        source = path.read_text()
        imports = [line.strip() for line in source.splitlines() if line.strip().startswith("import ")]
        assert "import Hornero.PluginKit" in imports, placement
        assert all(line == "import QtQuick" or line == "import Hornero.PluginKit" for line in imports), placement
