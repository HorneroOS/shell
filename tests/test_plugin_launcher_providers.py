"""Plugin-defined launcher providers (shell#250 follow-up, #373).

surfaces.launcher was a validated declaration with no host.
PluginLauncherHost now loads each enabled plugin's launcher
entrypoint hidden, registers it into the Providers registry after
the built-ins, bridges the established query/result contract,
and copies the result on activation (wl-copy, calc convention).
Structural/offscreen evidence only — no live shell is launched;
the pure prefix/row helpers execute under node.
"""
import importlib.util
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HOST = (ROOT / "modules/plugins/PluginLauncherHost.qml").read_text()
PROVIDERS = (ROOT / "modules/launcher/services/Providers.qml").read_text()
JS = ROOT / "modules/launcher/services/launcherplugin.js"
APPLIST = (ROOT / "modules/launcher/AppList.qml").read_text()
SERVICE = (ROOT / "services/Plugins.qml").read_text()
SHELL = (ROOT / "shell.qml").read_text()
DOCS_PLUGINS = (ROOT / "docs/PLUGINS.md").read_text()
DOCS_LAUNCHER = (ROOT / "docs/LAUNCHER.md").read_text()

_spec = importlib.util.spec_from_file_location(
    "hornero_plugin_validator_launcher", ROOT / "scripts/validate_plugin.py"
)
assert _spec and _spec.loader
VALIDATOR = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(VALIDATOR)


def _run_js(driver: str):
    node = shutil.which("node")
    assert node, "node is required to execute launcherplugin.js"
    src = JS.read_text().replace(".pragma library", "", 1)
    proc = subprocess.run([node, "-e", src + "\n" + driver],
                          capture_output=True, text=True, timeout=30)
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


# --- Hosting -------------------------------------------------------------

def test_host_wired_and_models_enabled_launcher_plugins_only():
    assert "PluginLauncherHost {}" in SHELL
    assert "Plugins.launcherPlugins()" in HOST
    assert 'return root.pluginsForSurface("launcher")' in SERVICE
    # pluginsForSurface gates: safe mode, enabled, installed,
    # surface-enabled — so disable/safe-mode unload falls out of
    # the Repeater model destroying the delegate.
    assert "if (root.safeMode)\n            return []" in SERVICE
    assert "if (!entry.enabled || !entry.installed)" in SERVICE


def test_host_loads_hidden_per_plugin_loader():
    assert "visible: false" in HOST
    assert "Repeater" in HOST and "Loader {" in HOST
    assert "asynchronous: true" in HOST
    assert "`file://${Plugins.pluginsDir}/${slot.pluginId}/${slot.modelData.entrypoint}`" in HOST


def test_disable_unloads_and_unregisters():
    assert "Component.onDestruction: slot.unregister()" in HOST
    assert "Providers.unregisterProvider(slot.pluginId)" in HOST
    assert "function unregisterProvider(id: string): bool" in PROVIDERS
    assert "providers.filter(p => p.id !== id)" in PROVIDERS


# --- Contract ------------------------------------------------------------

def test_contract_is_the_established_query_result_shape():
    assert "launcherContractOk" in HOST and "launcherContractOk" in PROVIDERS
    assert '"query" in item' in JS.read_text() and '"result" in item' in JS.read_text()
    for needle in ("query", "result", "{ ok: bool, text: string }", "hornero-calculator"):
        assert needle in DOCS_LAUNCHER, needle


def test_contract_missing_skipped_with_diagnostic_not_failed():
    assert "launcher-contract-missing" in HOST
    assert "Plugins.logDiagnostic(slot.pluginId, \"launcher-contract-missing\"" in HOST
    # Skip path must not markFailed (that would fail other surfaces).
    body = HOST[HOST.index("if (!Providers.launcherContractOk(item))"):]
    assert "markFailed" not in body[: body.index("registerProvider")]


def test_contract_check_executes():
    out = _run_js("""
console.log(JSON.stringify([
  launcherContractOk(null),
  launcherContractOk({}),
  launcherContractOk({query: "", result: {ok: true, text: "5"}}),
  launcherContractOk({query: "", result: {ok: "yes", text: "5"}}),
  launcherContractOk({query: "", result: {ok: true}}),
  launcherContractOk({query: "", result: {ok: false, text: "Error"}})
]));""")
    assert out == [False, False, True, False, False, True]


# --- Registration --------------------------------------------------------

def test_registration_after_builtins_and_prefix_derivation():
    assert "builtinsRegistered" in PROVIDERS and "builtinsRegistered" in HOST
    assert "root.builtinsRegistered = true" in PROVIDERS
    assert "if (!Providers.builtinsRegistered)" in HOST
    assert "Providers.registerProvider({" in HOST
    assert '"id": slot.pluginId' in HOST and '"prefix": slot.prefix' in HOST
    assert "Providers.launcherPrefixFor(modelData.id)" in HOST
    # Registry still rejects duplicate id/prefix: first (built-in)
    # registration wins; host logs the rejection.
    assert "p.id === spec.id" in PROVIDERS and "p.prefix === spec.prefix" in PROVIDERS
    assert "launcher-registration-rejected" in HOST


def test_prefix_derivation_executes():
    out = _run_js("""
console.log(JSON.stringify([
  "hornero-calculator", "hornero-unit-converter", "hornero-text-tools",
  "example-multi-surface", "calc", ""
].map(launcherPrefixFor)));""")
    assert out == ["calculator", "unit-converter", "text-tools",
                   "example-multi-surface", "calc", ""]


def test_icon_from_manifest_entry_else_generic():
    assert 'typeof modelData.icon === "string" && modelData.icon !== "" ? modelData.icon : "extension"' in HOST


# --- Query bridge / activation --------------------------------------------

def test_query_bridge_sets_query_reads_result_single_row():
    assert "hosted.query = text" in HOST
    assert "hosted.result" in HOST
    assert "return row ? [row] : []" in HOST
    # AppList serves plugin providers through the registry query.
    assert 'return "plugin";' in APPLIST
    assert 'name: "plugin"' in APPLIST
    assert "model.values: Providers.query(search.text)" in APPLIST
    assert "pluginItem" in APPLIST


def test_result_mapping_executes():
    out = _run_js("""
console.log(JSON.stringify([
  launcherRow("hornero-calculator", "Hornero Calculator", "extension", {ok: true, text: "5"}),
  launcherRow("hornero-calculator", "Hornero Calculator", "", {ok: true, text: "5"}),
  launcherRow("hornero-calculator", "", "extension", {ok: true, text: "5"}),
  launcherRow("p", "P", "extension", {ok: false, text: "Error"}),
  launcherRow("p", "P", "extension", {ok: true, text: ""}),
  launcherRow("p", "P", "extension", {ok: true, text: 5}),
  launcherRow("p", "P", "extension", null)
]));""")
    assert out[0] == {"providerId": "hornero-calculator",
                      "section": "hornero-calculator",
                      "icon": "extension", "title": "5",
                      "subtitle": "Hornero Calculator",
                      "payload": {"ok": True, "text": "5"}}
    assert out[1]["icon"] == "extension"  # generic fallback
    assert out[2]["subtitle"] == "hornero-calculator"
    # Not-ok (and malformed / empty) results produce no row.
    assert out[3:] == [None, None, None, None]


def test_activation_copies_result_text_wl_copy_like_calc():
    assert 'Quickshell.execDetached(["wl-copy", result.payload.text])' in HOST
    calc_item = (ROOT / "modules/launcher/items/CalcItem.qml").read_text()
    assert 'Quickshell.execDetached(["wl-copy", root.result.text])' in calc_item
    assert "list.visibilities.launcher = false" in HOST
    item = (ROOT / "modules/launcher/items/PluginItem.qml").read_text()
    assert "Providers.activate(root.modelData, root.list)" in item
    # No plugin activation hook is invented anywhere.
    assert "onActivate" not in HOST and "activate(" not in (
        ROOT / "examples/plugins/example-multi-surface/Launcher.qml").read_text()


# --- Fault isolation -------------------------------------------------------

def test_loader_error_marks_only_that_plugin_failed():
    assert "status === Loader.Error" in HOST
    assert "Plugins.markFailed(slot.pluginId, pluginLoader.errorString" in HOST
    assert "slot.unregister();" in HOST


def test_broken_launcher_fixture_is_valid_but_fails_to_load():
    fixture = ROOT / "examples/plugins/example-launcher-broken"
    VALIDATOR.validate_plugin(fixture)
    manifest = json.loads((fixture / "manifest.json").read_text())
    assert manifest["surfaces"]["launcher"] == {"entrypoint": "Launcher.qml"}
    source = (fixture / "Launcher.qml").read_text()
    assert "BrokenLauncherFixtureMissingType" in source
    assert not list(ROOT.rglob("BrokenLauncherFixtureMissingType.qml"))
    assert "example-launcher-broken" not in (ROOT / "config/shell.default.json").read_text()


# --- Example + docs ---------------------------------------------------------

def test_example_multi_surface_gains_launcher_surface_validator_green():
    example = ROOT / "examples/plugins/example-multi-surface"
    VALIDATOR.validate_plugin(example)
    manifest = json.loads((example / "manifest.json").read_text())
    assert manifest["surfaces"]["launcher"] == {"entrypoint": "Launcher.qml"}
    assert "Launcher.qml" in manifest["files"]
    launcher = (example / "Launcher.qml").read_text()
    assert 'property string query: ""' in launcher
    assert "readonly property var result" in launcher
    assert '"ok": true' in launcher and '"text":' in launcher


def test_docs_describe_hosted_launcher_contract():
    assert "| `launcher` | Launcher/search action entry point. | Yes" in DOCS_PLUGINS
    for needle in ("query/result", "hornero-", "copy-on-activate", "in-process"):
        assert needle.lower() in DOCS_PLUGINS.lower(), needle
    for needle in ("PluginLauncherHost", "{ ok: bool, text: string }",
                   "wl-copy", "no row", "builtinsRegistered"):
        assert needle in DOCS_LAUNCHER, needle
    assert "unsandboxed" in DOCS_LAUNCHER and "unsandboxed" in DOCS_PLUGINS


# --- Regressions -------------------------------------------------------------

def test_builtin_providers_and_default_apps_flow_unchanged():
    for pid in ('"id": "apps"', '"id": "calc"', '"id": "win"'):
        assert pid in PROVIDERS, pid
    assert "model.values: Apps.search(search.text)" in APPLIST
    for state in ('"apps"', '"actions"', '"calc"', '"win"', '"file"', '"ai"'):
        assert f"name: {state}" in APPLIST, state
    content = (ROOT / "modules/launcher/Content.qml").read_text()
    assert "Keys.onUpPressed: list.currentList?.decrementCurrentIndex()" in content
    assert "Keys.onDownPressed: list.currentList?.incrementCurrentIndex()" in content
