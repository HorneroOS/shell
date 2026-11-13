"""Extension compatibility: RC1-RC6 structural/runtime-contract tests.

Honestly labelled: these are structural QML tests (no live Quickshell
instantiation in CI); they pin the guards that prevent delegate
recreation, the runtime compat gate, sizing/clip, and discovery
error-vs-empty distinction from the extensions design.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICE = (ROOT / "services/Plugins.qml").read_text()
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text()
THEME = (ROOT / "plugin/qml/Hornero/PluginKit/Theme.qml").read_text()

def test_mark_operations_guard_unchanged_values():
    # RC1: unchanged markPlacement/setState must not reassign entries,
    # or every Repeater recreates delegates and plugin Timer state resets.
    assert "current.placement === placement && current.entrypoint === entrypoint" in SERVICE
    assert "current.state === state" in SERVICE
    assert SERVICE.count("root.entries = next") >= 2

def test_reload_guarded_and_discovery_errors_distinct_from_empty():
    assert "if (listProcess.running)" in SERVICE
    assert "discoveryError" in SERVICE
    assert "exitCode !== 0" in SERVICE
    assert "malformed JSON" in SERVICE
    pane = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()
    assert "Plugins.discoveryError" in pane
    assert "Plugins.discoveryError.length === 0" in pane  # error != empty state

def test_loader_errors_surface_error_string():
    for rel in ("modules/plugins/PluginHost.qml", "modules/plugins/PluginBarWidgets.qml",
                "modules/plugins/PluginDashboardCards.qml", "modules/plugins/PluginDesktopWidgets.qml"):
        assert "errorString" in (ROOT / rel).read_text(), rel

def test_runtime_compat_gate():
    # RC5: schemaVersion (1 or 2 since shell#373; needle stays the
    # shared substring of the host's rejection message), semver,
    # strict entrypoint, files[] listing.
    for needle in ("schemaVersion must be 1", "semantic versioning",
                   "files must list the entrypoint", 'includes("\\\\")'):
        assert needle in HOST, needle

def test_sizing_clip_and_desktop_palette():
    bar = (ROOT / "modules/plugins/PluginBarWidgets.qml").read_text()
    dash = (ROOT / "modules/plugins/PluginDashboardCards.qml").read_text()
    desk = (ROOT / "modules/plugins/PluginDesktopWidgets.qml").read_text()
    assert "Layout.maximumWidth" in bar and "clip: true" in bar
    assert "Layout.maximumWidth" in dash and "clip: true" in dash
    assert "palette.windowText: Colours.palette.m3onSurface" in desk
    assert "Layout.maximumWidth" in desk and "clip: true" in desk

def test_theme_full_token_set():
    for token in ("surfaceContainerHigh", "primaryContainer", "secondaryContainer",
                  "tertiaryContainer", "errorContainer", "outlineVariant",
                  "fontFamily", "fontSize", "spacing", "rounding"):
        assert token in THEME, token

def test_every_first_party_example_validates_and_uses_theme():
    import importlib.util
    spec = importlib.util.spec_from_file_location("v", ROOT / "scripts/validate_plugin.py")
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    examples = sorted((ROOT / "examples/plugins").iterdir())
    assert examples, "no first-party examples"
    for ex in examples:
        mod.validate_plugin(ex)
        main = (ex / "Main.qml").read_text()
        assert "Theme." in main, ex.name
        manifest = json.loads((ex / "manifest.json").read_text())
        assert manifest["schemaVersion"] in (1, 2) and manifest["entrypoint"] in manifest["files"]
