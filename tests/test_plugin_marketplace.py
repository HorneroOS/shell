"""Marketplace previews, changelogs, deprecation/replacement (shell#379).

Covers the additive optional `marketplace` manifest object
(validator + schema + runtime gates), the static no-execution
preview contract in the Extensions pane, permission explanations
and the settings/replacement shortcuts, and that rollback stays on
the existing verified-provenance gate only. No compositor or AT-SPI
claim is made here; pane checks are static source contracts in the
repo style.
"""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = (ROOT / "schemas/plugin-manifest.schema.json").read_text()
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text()
SERVICE = (ROOT / "services/Plugins.qml").read_text()
PANE = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()
COMMUNITY = (ROOT / "modules/controlcenter/extensions/CommunityRegistrySection.qml").read_text()
DOCS = (ROOT / "docs/PLUGINS.md").read_text()

_spec = importlib.util.spec_from_file_location(
    "validate_plugin", ROOT / "scripts/validate_plugin.py")
VALIDATOR = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(VALIDATOR)

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32

MARKETPLACE = {
    "screenshots": [{"path": "previews/main.png", "alt": "Main view"}],
    "compatibility": {"minShellVersion": "1.0.0", "maxShellVersion": "2.0.0"},
    "changelog": [
        {"version": "1.1.0", "notes": "Newest entry first."},
        {"version": "1.0.0", "notes": "Initial release."},
    ],
}


def _plugin(tmp_path: Path, plugin_id: str, marketplace=None, extra_files=True) -> Path:
    root = tmp_path / plugin_id
    root.mkdir(parents=True)
    files = ["Main.qml", "README.md", "LICENSE"]
    if extra_files:
        (root / "previews").mkdir()
        (root / "previews" / "main.png").write_bytes(PNG)
        files.append("previews/main.png")
    manifest = {
        "schemaVersion": 1,
        "id": plugin_id,
        "name": f"Marketplace {plugin_id}",
        "version": "1.1.0",
        "description": "Marketplace metadata fixture.",
        "author": "Hornero QA",
        "license": "MIT",
        "entrypoint": "Main.qml",
        "placement": "bar",
        "files": files,
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
    }
    if marketplace is not None:
        manifest["marketplace"] = marketplace
    (root / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    (root / "Main.qml").write_text("import QtQuick\nItem {}\n", encoding="utf-8")
    (root / "README.md").write_text(f"# {plugin_id}\nFixture.\n", encoding="utf-8")
    (root / "LICENSE").write_text("MIT\n", encoding="utf-8")
    return root


def _rejects(root: Path, needle: str) -> None:
    try:
        VALIDATOR.validate_plugin(root)
    except VALIDATOR.ValidationError as error:
        assert needle in str(error), (needle, str(error))
    else:
        raise AssertionError(f"{root} must be rejected ({needle})")


def test_marketplace_accepted_and_carried(tmp_path):
    root = _plugin(tmp_path, "marketplace-ok", MARKETPLACE)
    VALIDATOR.validate_plugin(root)  # must not raise (schemaVersion 1 too)
    manifest = json.loads((root / "manifest.json").read_text())
    effective = VALIDATOR.effective_marketplace(manifest)
    assert effective["screenshots"] == [{"path": "previews/main.png", "alt": "Main view"}]
    assert effective["compatibility"]["maxShellVersion"] == "2.0.0"
    assert [e["version"] for e in effective["changelog"]] == ["1.1.0", "1.0.0"]
    assert "deprecation" not in effective


def test_no_marketplace_and_deprecation_only(tmp_path):
    plain = _plugin(tmp_path, "marketplace-absent", None, extra_files=False)
    VALIDATOR.validate_plugin(plain)  # pre-#379 shape stays valid
    manifest = json.loads((plain / "manifest.json").read_text())
    assert VALIDATOR.effective_marketplace(manifest) is None

    deprecated = _plugin(tmp_path, "marketplace-deprecated", {
        "deprecation": {"message": "Unmaintained.", "replacedBy": "marketplace-ok"},
    }, extra_files=False)
    VALIDATOR.validate_plugin(deprecated)
    manifest = json.loads((deprecated / "manifest.json").read_text())
    effective = VALIDATOR.effective_marketplace(manifest)
    assert effective == {"deprecation": {
        "message": "Unmaintained.", "replacedBy": "marketplace-ok"}}


def test_marketplace_rejects(tmp_path):
    cases = [
        ({}, "at least one of screenshots"),
        ({"rating": 5}, "unknown fields"),
        ({"screenshots": []}, "1 to 6"),
        ({"screenshots": [{"alt": "no path"}]}, ".path is required"),
        # Executable/interpreted preview formats are the core negative
        # case: a preview must never run plugin code.
        ({"screenshots": [{"path": "Main.qml"}]}, "static image"),
        ({"screenshots": [{"path": "previews/main.svg"}]}, "static image"),
        ({"screenshots": [{"path": "previews/main.gif"}]}, "static image"),
        ({"screenshots": [{"path": "../escape.png"}]}, "safe relative path"),
        ({"screenshots": [{"path": "/abs.png"}]}, "safe relative path"),
        ({"screenshots": [{"path": "previews/missing.png"}]}, "must be listed in files"),
        ({"screenshots": [{"path": "previews/main.png", "url": "https://x"}]}, "unknown fields"),
        ({"screenshots": [{"path": "previews/main.png", "alt": ""}]}, "alt"),
        ({"screenshots": [{"path": "previews/main.png"}, {"path": "previews/main.png"}]},
         "must not repeat a path"),
        ({"compatibility": {}}, "minShellVersion"),
        ({"compatibility": {"shell": ">=1.0.0"}}, "unknown fields"),
        ({"compatibility": {"minShellVersion": "1.0"}}, "semantic versioning"),
        ({"compatibility": {"minShellVersion": "2.0.0", "maxShellVersion": "1.0.0"}},
         "must not exceed"),
        ({"compatibility": {"minShellVersion": "1.0.0", "maxShellVersion": "1.0.0-rc.1"}},
         "must not exceed"),
        ({"changelog": []}, "1 to 20"),
        ({"changelog": [{"version": "1.0.0"}]}, "must contain version and notes"),
        ({"changelog": [{"version": "v1", "notes": "x"}]}, "semantic versioning"),
        ({"changelog": [{"version": "1.0.0", "notes": ""}]}, "notes"),
        ({"changelog": [{"version": "1.0.0", "notes": "a"},
                        {"version": "1.0.0", "notes": "b"}]}, "must not repeat a version"),
        ({"deprecation": {"replacedBy": "Bad Id"}}, "plugin id"),
        ({"deprecation": {"since": "1.0.0"}}, "unknown fields"),
        ({"deprecation": {"message": "x" * 281}}, "message"),
    ]
    for i, (marketplace, needle) in enumerate(cases):
        _rejects(_plugin(tmp_path, f"marketplace-bad-{i}", marketplace), needle)


def test_deprecation_replaced_by_self_rejects(tmp_path):
    root = _plugin(tmp_path, "marketplace-self", {
        "deprecation": {"replacedBy": "marketplace-self"}}, extra_files=False)
    _rejects(root, "must not name the plugin itself")


def test_shipped_example_carries_marketplace():
    example = ROOT / "examples/plugins/example-clock"
    VALIDATOR.validate_plugin(example)
    manifest = json.loads((example / "manifest.json").read_text())
    effective = VALIDATOR.effective_marketplace(manifest)
    assert effective["screenshots"][0]["path"] == "previews/clock.png"
    assert (example / "previews/clock.png").is_file()


def test_schema_host_service_mirrors():
    for token in ('"marketplace"', '"screenshots"', '"compatibility"',
                  '"changelog"', '"deprecation"', '"replacedBy"',
                  "minShellVersion", "maxShellVersion"):
        assert token in SCHEMA, token
    assert "png|jpg|jpeg|webp" in SCHEMA and "png|jpg|jpeg|webp" in SERVICE
    assert "function normalizeMarketplace" in SERVICE
    assert "function markMarketplace" in SERVICE
    assert "function marketplaceFor" in SERVICE
    assert "manifest marketplace" in HOST and "markMarketplace" in HOST
    assert "must be listed in files" in HOST


def test_preview_never_executes_plugin_code():
    # The disabled-plugin reader is manifest-text only: its block has
    # a FileView and no Loader, and the pane renders plain Images.
    reader = HOST.split("installed-but-disabled", 1)[1].split("IpcHandler", 1)[0]
    assert "FileView {" in reader and "Loader {" not in reader
    assert "markFailed" not in reader  # a bad preview never fails a disabled plugin
    assert "delegate: Image {" in PANE
    assert "AnimatedImage" not in PANE
    assert "screenshotSources" in PANE and "Plugins.pluginsDir" in PANE
    # The pane gains no new process/write path for previews.
    assert PANE.count("catalogInstallProc.command =") == 1
    assert PANE.count("lifecycleProc.command =") == 1
    assert PANE.count("catalogProc.command =") == 1


def test_pane_marketplace_ux_contract():
    for needle in ("function pluginMarketplace", "function isDeprecated",
                   "function deprecationText", "function compatibilityText",
                   "function changelogText", "function permissionExplanations",
                   "function openReplacement", "View replacement: %1",
                   "New installs of a deprecated extension are disabled.",
                   "Shell compatibility:", "Version history:",
                   "not enforced permissions"):
        assert needle in PANE, needle
    # Deprecated catalogue entries lose both install affordances.
    assert '!root.isDeprecated(catRow.modelData)' in PANE
    install = PANE.split('qsTr("Install…")', 1)[0].rsplit("visible:", 1)[1]
    assert "isDeprecated" in install
    confirm = PANE.split('qsTr("Confirm install")', 1)[0].rsplit("visible:", 1)[1]
    assert "isDeprecated" in confirm
    # Settings shortcut from a catalogue row drives the installed row.
    assert "root.settingsPluginId = catRow.modelData.id" in PANE
    # Community registry stays read-only text (shell#251).
    assert "function marketplaceText" in COMMUNITY
    assert "Process" in COMMUNITY and COMMUNITY.count(".command =") == 1


def test_rollback_stays_on_verified_provenance_only():
    # Marketplace/deprecation adds no rollback path: the only
    # rollback affordances remain the rollback_available-gated
    # catalogue action, which takes no --revision bypass.
    assert "rollback_available" in PANE
    assert 'runCatalogAction("rollback", catRow.modelData.id)' in PANE
    runner = PANE.split("function runCatalogAction", 1)[1].split("function runLifecycle", 1)[0]
    assert 'action === "install" || action === "update"' in runner
    assert "marketplace" not in runner and "deprecat" not in runner


def test_docs_describe_marketplace():
    docs_flat = " ".join(DOCS.split())
    for needle in ("marketplace", "screenshots", "compatibility",
                   "changelog", "deprecation", "replacedBy",
                   "without executing", "rollback"):
        assert needle.lower() in docs_flat.lower(), needle
