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
