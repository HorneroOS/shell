"""Custom settings surface host (shell#373/#374 follow-up).

surfaces.settings was a validated declaration with no host. Control
Center › Extensions now loads it alongside the generated typed
settings UI, with the same Loader fault isolation as the other
plugin hosts. Plugins without the surface see zero change.
Structural/offscreen evidence only — no live shell is launched.
"""

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SERVICE = (ROOT / "services/Plugins.qml").read_text()
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text()
PANE = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()
HOST_CC = (ROOT / "modules/controlcenter/extensions/PluginSettingsHost.qml").read_text()
SECTION = (ROOT / "modules/controlcenter/extensions/PluginSettingsSection.qml").read_text()
DOCS = (ROOT / "docs/PLUGINS.md").read_text()

SPEC = importlib.util.spec_from_file_location(
    "hornero_plugin_validator_settings_host", ROOT / "scripts/validate_plugin.py"
)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


def test_service_exposes_settings_surface_only_for_enabled_installed():
    assert "function settingsPlugins(): var" in SERVICE
    assert 'return root.pluginsForSurface("settings")' in SERVICE
    # Copy semantics like other surfaces: the copy's entrypoint is
    # the settings surface's file (pluginsForSurface).
    assert "entrypoint: declared.entrypoint" in SERVICE
    assert "function settingsSurfaceFor(entry: var): var" in SERVICE
    assert "function hasSettingsSurface(entry: var): bool" in SERVICE
    body = SERVICE[SERVICE.index("function settingsSurfaceFor"):]
    body = body[: body.index("function hasSettingsSurface")]
    # Gate: safe mode, enabled and installed are all required.
    assert "root.safeMode" in body and "!entry.enabled" in body and "!entry.installed" in body
    assert 'root.surfaceFor(entry, "settings")' in body
    assert "declared.enabled === false" in body


def test_pane_offers_surface_alongside_generated_ui():
    assert "function settingsSurface(entry): var" in PANE
    assert "Plugins.settingsSurfaceFor(entry)" in PANE
    assert "function hasSettingsSurface(entry): bool" in PANE
    assert "function hasAnyPluginSettings(entry): bool" in PANE
    assert "root.hasPluginSettings(entry) || root.hasSettingsSurface(entry)" in PANE
    # Alongside, not replacing: both components render in the row,
    # each gated on its own declaration kind and the expanded row.
    assert "PluginSettingsSection {" in PANE and "PluginSettingsHost {" in PANE
    assert "visible: root.settingsPluginId === row.modelData.id && root.hasPluginSettings(row.modelData)" in PANE
    assert "visible: root.customSettingsPluginId === row.modelData.id && root.hasSettingsSurface(row.modelData)" in PANE
    assert "entrypoint: root.settingsSurfaceEntrypoint(row.modelData)" in PANE
    assert PANE.index("PluginSettingsSection {") < PANE.index("PluginSettingsHost {")


def test_surface_host_fault_isolation_like_other_hosts():
    # Own asynchronous Loader per plugin; failure marks diagnostics
    # through the service and shows inline text, never a crash path.
    assert "Loader {" in HOST_CC and "asynchronous: true" in HOST_CC
    assert "status === Loader.Error" in HOST_CC
    assert 'Plugins.markFailed(root.pluginId, pluginLoader.errorString || "settings entrypoint failed to load (see shell log)")' in HOST_CC
    assert "markFailed" in SERVICE and "logDiagnostic" in SERVICE and "sanitizeDetail" in SERVICE
    assert "This plugin's custom settings failed to load." in HOST_CC
    assert "pluginLoader.status === Loader.Error" in HOST_CC
    # No other plugin's Loader is shared or torn down on failure.
    assert "Repeater" not in HOST_CC


def test_disable_and_safe_mode_unload_surface():
    assert "Plugins.hasSurface(root.pluginId, \"settings\")" in HOST_CC
    assert "active: root.surfaceAvailable && root.visible" in HOST_CC
    assert 'source: active ? `file://${Plugins.pluginsDir}/${root.pluginId}/${root.entrypoint}` : ""' in HOST_CC
    # Service side: pluginsForSurface/hasSurface return nothing in
    # safe mode and skip disabled/uninstalled entries.
    assert "if (root.safeMode)\n            return []" in SERVICE
    assert "if (!entry.enabled || !entry.installed)" in SERVICE


def test_no_surface_means_no_change():
    # Generated section unchanged and still gated on typed settings.
    assert "visible: root.settingKeys().length > 0" in SECTION
    # The headless host still loads only background; the settings
    # surface is not double-loaded there.
    assert 'active: slot.backgroundEntrypoint !== ""' in HOST
    assert "PluginSettingsHost" in HOST  # only as a pointer comment
    # Pane affordance requires either kind; a plugin with neither
    # has no Settings button (hasAnyPluginSettings false path).
    assert "visible: root.hasSettingsSurface(row.modelData)" in PANE
    assert "qsTr(\"Custom settings\")" in PANE
    assert "root.customSettingsPluginId === row.modelData.id" in PANE


def test_honest_trust_note_in_ui_and_docs():
    assert "in-process" in HOST_CC and "without a sandbox" in HOST_CC
    assert "same trust as its other surfaces" in HOST_CC
    assert "Custom settings surface" in DOCS
    assert "alongside" in DOCS.lower()
    assert "In-process QML, same trust as other surfaces" in DOCS
    # Settings and launcher rows both claim their hosts now.
    assert "| `settings` | Custom Control Center settings entry point. | Yes" in DOCS
    assert "| `launcher` | Launcher/search action entry point. | Yes" in DOCS


def test_host_context_injected_for_settings_surface():
    for prop in ("hostOrientation", "hostEdge", "hostSurface", "hostAvailableWidth", "hostAvailableHeight", "hostCompact", "hostScreenName"):
        assert f'property: "{prop}"' in HOST_CC, prop
        assert f'"{prop}" in pluginLoader.item' in HOST_CC, prop
    assert 'value: "settings"' in HOST_CC


def test_example_multi_surface_declares_settings_surface():
    example = ROOT / "examples/plugins/example-multi-surface"
    VALIDATOR.validate_plugin(example)
    manifest = json.loads((example / "manifest.json").read_text())
    assert manifest["surfaces"]["settings"] == {"entrypoint": "Settings.qml"}
    assert "Settings.qml" in manifest["files"]
    surface = (example / "Settings.qml").read_text()
    assert "pluginSettings.value(\"label\"" in surface
    # Other surfaces untouched.
    assert manifest["surfaces"]["dashboard"] == {"entrypoint": "Dashboard.qml"}
    assert manifest["placement"] == "bar"
