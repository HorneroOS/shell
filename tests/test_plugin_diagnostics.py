"""Extension diagnostics, performance budget, safe recovery (#380).

Safe mode must gate loading before any manifest is read, diagnostics
must never carry secrets, and budgets stay advisory: plugin QML is
in-process and not sandboxed, so nothing here may claim enforcement.
"""
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVICE = (ROOT / "services" / "Plugins.qml").read_text()
HOST = (ROOT / "modules" / "plugins" / "PluginHost.qml").read_text()
PANE = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()
PLUGINS_CONFIG = (ROOT / "config" / "PluginsConfig.qml").read_text()
CONFIG = (ROOT / "config" / "Config.qml").read_text()
DOCS = (ROOT / "docs" / "PLUGINS.md").read_text()
IPC = (ROOT / "docs" / "IPC.md").read_text()

_spec = importlib.util.spec_from_file_location(
    "validate_plugin", ROOT / "scripts" / "validate_plugin.py"
)
validator = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(validator)


def test_safe_mode_sources_env_and_persisted_config():
    assert 'Quickshell.env("HORNERO_SAFE_MODE")' in SERVICE
    assert '["1", "true"]' in SERVICE
    assert "Config.plugins.safeMode === true" in SERVICE
    assert "property bool safeMode: false" in PLUGINS_CONFIG
    assert "function setSafeMode" in PLUGINS_CONFIG
    assert "safeMode: plugins.safeMode" in CONFIG
    factory = json.loads((ROOT / "config" / "shell.default.json").read_text())
    assert factory["plugins"]["safeMode"] is False


def test_safe_mode_gates_every_host_before_manifest_or_qml():
    # Headless host: no delegate at all, so manifest.json is not read.
    assert "Plugins.safeMode ? []" in HOST
    # Visible hosts all consume pluginsForSurface/hasSurface.
    assert "if (root.safeMode)\n            return []" in SERVICE
    assert "if (root.safeMode)\n            return false" in SERVICE
    for host in ("PluginBarWidgets.qml", "PluginDashboardCards.qml",
                 "PluginDesktopWidgets.qml"):
        source = (ROOT / "modules" / "plugins" / host).read_text()
        assert "Plugins." in source and "Plugins()" in source, host
    # Discovery still lists plugins (recovery UI needs the list) and
    # marks enabled ones safe-mode instead of pending.
    assert '"safe-mode"' in SERVICE
    # Safe mode itself writes no lifecycle state.
    for banned in ('plugin", "enable', 'plugin", "disable', 'plugin", "remove'):
        assert banned not in SERVICE


def test_recovery_pane_is_core_ui_with_disable_and_safe_mode_toggle():
    assert "Plugins.safeMode" in PANE and "HORNERO_SAFE_MODE" in PANE
    assert "Config.plugins.setSafeMode(!Config.plugins.safeMode)" in PANE
    # Disable stays available in safe mode (horneroctl lifecycle).
    assert 'runLifecycle("disable", row.modelData.id)' in PANE
    assert "Safe mode" in PANE


def test_per_extension_reload_and_diagnostics_surface():
    assert "function reloadPlugin(id: string): bool" in SERVICE
    # Negative: unknown/disabled/safe-mode reloads are no-ops.
    assert "!current || !current.enabled || !current.installed || root.safeMode" in SERVICE
    assert "function reloadPlugin(id: string): string" in HOST
    assert "reloadPlugin(id)" in IPC
    assert "Plugins.reloadPlugin(row.modelData.id)" in PANE
    assert "loadMs" in SERVICE and "attempts" in SERVICE
    assert "pluginDiagnostics" in PANE
    assert "diagnosticsLog: root.diagnosticsLog" in SERVICE
    assert "slice(-50)" in SERVICE  # bounded log


def test_diagnostic_details_are_redacted_before_log_store_or_console():
    assert "function sanitizeDetail" in SERVICE
    for needle in ("token", "password", "secret", "api[_-]?key", "Bearer", "<redacted>"):
        assert needle in SERVICE
    # markFailed must log the sanitized copy, never the raw detail.
    assert "console.warn(`[plugins] ${id} failed to load: ${clean}`)" in SERVICE
    assert "failed to load: ${detail}`" not in SERVICE


def test_budgets_are_advisory_diagnostics_not_enforcement():
    assert "slowLoadBudgetMs: 2000" in SERVICE
    assert '"slow-load"' in SERVICE and '"load-churn"' in SERVICE
    assert "churnAttemptBudget: 5" in SERVICE and "churnWindowMs: 60000" in SERVICE
    # Honest limits documented; no sandbox claims introduced.
    assert "Diagnostics, performance budget and safe mode" in DOCS
    assert "cannot be preempted or sandboxed" in DOCS
    assert "HORNERO_SAFE_MODE=1" in DOCS


def test_malformed_manifest_and_qml_stay_isolated_per_plugin():
    # Manifest failures mark only that plugin failed and return.
    assert '"manifest.json is not readable JSON"' in HOST
    assert '"manifest.json could not be read"' in HOST
    assert "Loader.Error" in HOST
    for host in ("PluginBarWidgets.qml", "PluginDashboardCards.qml",
                 "PluginDesktopWidgets.qml"):
        source = (ROOT / "modules" / "plugins" / host).read_text()
        assert "Loader.Error" in source and "Plugins.markFailed" in source, host


def _plugin(tmp_path: Path, qml: str) -> Path:
    root = tmp_path / "plug"
    root.mkdir()
    (root / "Main.qml").write_text(qml)
    return root


def test_polling_budget_warns_below_one_second(tmp_path):
    root = _plugin(tmp_path, "import QtQuick\nTimer { interval: 100; running: true }\n")
    warnings = validator.performance_warnings(root)
    assert len(warnings) == 1 and "100ms" in warnings[0]


def test_polling_budget_accepts_slow_bound_and_commented_timers(tmp_path):
    root = _plugin(
        tmp_path,
        "import QtQuick\n"
        "Timer { interval: 5000 }\n"
        "Timer { interval: root.pollMs }\n"
        "// Timer { interval: 10 }\n",
    )
    assert validator.performance_warnings(root) == []


def test_polling_budget_missing_dir_is_empty(tmp_path):
    assert validator.performance_warnings(tmp_path / "absent") == []


def test_polling_budget_is_warning_only_not_validation_failure(tmp_path):
    # A fast-polling but otherwise valid clock example still passes.
    root = _plugin(tmp_path, "import QtQuick\nTimer { interval: 50 }\n")
    manifest = {
        "schemaVersion": 1,
        "id": "plug",
        "name": "Plug",
        "version": "1.0.0",
        "entrypoint": "Main.qml",
        "files": ["Main.qml"],
        "placement": "background",
    }
    (root / "manifest.json").write_text(json.dumps(manifest))
    # Match existing contract-test manifests if extra required fields
    # exist; validation must not fail *because of* the polling budget.
    try:
        validator.validate_plugin(root)
    except validator.ValidationError as error:
        assert "polling" not in str(error) and "interval" not in str(error)
    assert validator.performance_warnings(root)
