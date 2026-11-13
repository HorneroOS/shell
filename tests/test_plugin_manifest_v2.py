"""Manifest v2 multi-surface contract (shell#373).

Covers the three layers that must agree:
  * schemas/plugin-manifest.schema.json (structural),
  * scripts/validate_plugin.py (package validator incl. cross-field
    rules the schema cannot express), and its effective_surfaces()
    derivation shared in spirit with PluginHost.qml,
  * services/Plugins.qml + modules/plugins/PluginHost.qml structural
    runtime contract (no live Quickshell in CI).

v1 manifests must keep loading identically: one effective surface,
derived from placement/entrypoint, enabled, same entrypoint file.
Declaring a surface (or a capability) grants no privilege; docs must
keep saying declarations are not enforcement.
"""
import importlib.util
import json
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "hornero_plugin_validator_v2", ROOT / "scripts/validate_plugin.py"
)
assert SPEC and SPEC.loader
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)
SCHEMA = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())

QML = "import QtQuick\nimport Hornero.PluginKit\nItem { Text { text: Theme.surface } }"


def make_v2_plugin(tmp_path: Path, manifest_overrides=None, extra_files=("Dashboard.qml",)) -> Path:
    plugin = tmp_path / "example-two-surface"
    plugin.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schemaVersion": 2,
        "id": "example-two-surface",
        "name": "Example Two Surface",
        "version": "1.0.0",
        "description": "A sample two-surface package.",
        "author": "Example Author",
        "license": "MIT",
        "placement": "bar",
        "entrypoint": "Main.qml",
        "files": ["Main.qml", *extra_files, "README.md", "LICENSE"],
        "surfaces": {"dashboard": {"entrypoint": "Dashboard.qml"}},
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
    }
    if manifest_overrides:
        manifest.update(manifest_overrides)
    (plugin / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    for name in manifest["files"]:
        target = plugin / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if name.endswith(".qml"):
            target.write_text(QML, encoding="utf-8")
        elif name == "README.md":
            target.write_text("# Example\n", encoding="utf-8")
        elif name == "LICENSE":
            target.write_text("MIT\n", encoding="utf-8")
        else:
            target.write_text("x\n", encoding="utf-8")
    return plugin


def manifest_of(plugin: Path) -> dict:
    return json.loads((plugin / "manifest.json").read_text())


def rewrite(plugin: Path, manifest: dict) -> None:
    (plugin / "manifest.json").write_text(json.dumps(manifest))


# --- acceptance: valid v2 forms -------------------------------------------


def test_v2_multi_surface_package_passes_schema_and_validator(tmp_path):
    plugin = make_v2_plugin(tmp_path)
    Draft202012Validator(SCHEMA).validate(manifest_of(plugin))
    VALIDATOR.validate_plugin(plugin)


@pytest.mark.parametrize("surface", ["background", "bar", "dashboard", "desktop", "launcher", "settings"])
def test_every_known_surface_is_accepted(tmp_path, surface):
    overrides = {"surfaces": {surface: {"entrypoint": "Dashboard.qml"}}}
    if surface == "bar":  # primary placement: must reuse the primary file
        overrides = {"surfaces": {"bar": {"entrypoint": "Main.qml", "enabled": False}}}
    plugin = make_v2_plugin(tmp_path, overrides)
    Draft202012Validator(SCHEMA).validate(manifest_of(plugin))
    VALIDATOR.validate_plugin(plugin)


def test_v2_without_surfaces_passes(tmp_path):
    plugin = make_v2_plugin(tmp_path)
    manifest = manifest_of(plugin)
    del manifest["surfaces"]
    manifest["files"].remove("Dashboard.qml")
    rewrite(plugin, manifest)
    (plugin / "Dashboard.qml").unlink()
    Draft202012Validator(SCHEMA).validate(manifest)
    VALIDATOR.validate_plugin(plugin)


def test_shipped_multi_surface_example_passes():
    plugin = ROOT / "examples/plugins/example-multi-surface"
    manifest = manifest_of(plugin)
    assert manifest["schemaVersion"] == 2
    Draft202012Validator(SCHEMA).validate(manifest)
    VALIDATOR.validate_plugin(plugin)
    assert VALIDATOR.effective_surfaces(manifest) == {
        "bar": {"entrypoint": "Main.qml", "enabled": True},
        "dashboard": {"entrypoint": "Dashboard.qml", "enabled": True},
        "settings": {"entrypoint": "Settings.qml", "enabled": True},
        "launcher": {"entrypoint": "Launcher.qml", "enabled": True},
    }


# --- backward compatibility: v1 derivation is the pre-v2 behaviour --------


def test_effective_surfaces_v1_derives_single_primary_surface():
    v1 = {"schemaVersion": 1, "entrypoint": "Main.qml", "placement": "dashboard"}
    assert VALIDATOR.effective_surfaces(v1) == {
        "dashboard": {"entrypoint": "Main.qml", "enabled": True}
    }
    v1_default = {"schemaVersion": 1, "entrypoint": "Main.qml"}
    assert VALIDATOR.effective_surfaces(v1_default) == {
        "background": {"entrypoint": "Main.qml", "enabled": True}
    }


def test_effective_surfaces_v2_merges_and_honours_enabled():
    manifest = {
        "schemaVersion": 2,
        "entrypoint": "Main.qml",
        "placement": "bar",
        "surfaces": {
            "dashboard": {"entrypoint": "Card.qml"},
            "bar": {"entrypoint": "Main.qml", "enabled": False},
            "background": {"entrypoint": "Service.qml", "enabled": True},
        },
    }
    assert VALIDATOR.effective_surfaces(manifest) == {
        "bar": {"entrypoint": "Main.qml", "enabled": False},
        "dashboard": {"entrypoint": "Card.qml", "enabled": True},
        "background": {"entrypoint": "Service.qml", "enabled": True},
    }


def test_all_v1_shipped_examples_still_validate():
    for example in sorted((ROOT / "examples/plugins").iterdir()):
        manifest = manifest_of(example)
        if manifest["schemaVersion"] == 1:
            assert "surfaces" not in manifest
            VALIDATOR.validate_plugin(example)


# --- strict rejection: schema and validator agree --------------------------


@pytest.mark.parametrize(
    "overrides",
    [
        {"schemaVersion": 3},
        {"schemaVersion": 0},
        {"schemaVersion": "2"},
        {"schemaVersion": True},
        {"surfaces": {}},
        {"surfaces": []},
        {"surfaces": {"sidebar": {"entrypoint": "Dashboard.qml"}}},
        {"surfaces": {"dashboard": {}}},
        {"surfaces": {"dashboard": {"entrypoint": 42}}},
        {"surfaces": {"dashboard": {"entrypoint": "../escape.qml"}}},
        {"surfaces": {"dashboard": {"entrypoint": "/etc/passwd.qml"}}},
        {"surfaces": {"dashboard": {"entrypoint": "Dashboard.txt"}}},
        {"surfaces": {"dashboard": {"entrypoint": "Dashboard.qml", "enabled": "yes"}}},
        {"surfaces": {"dashboard": {"entrypoint": "Dashboard.qml", "window": "own"}}},
        {"surfaces": {"dashboard": "Dashboard.qml"}},
        {"surprise": True},
    ],
)
def test_schema_and_validator_reject_invalid_v2(tmp_path, overrides):
    plugin = make_v2_plugin(tmp_path, overrides)
    assert list(Draft202012Validator(SCHEMA).iter_errors(manifest_of(plugin))), overrides
    with pytest.raises(VALIDATOR.ValidationError):
        VALIDATOR.validate_plugin(plugin)


def test_surfaces_under_v1_is_rejected_by_schema_and_validator(tmp_path):
    plugin = make_v2_plugin(tmp_path, {"schemaVersion": 1})
    assert list(Draft202012Validator(SCHEMA).iter_errors(manifest_of(plugin)))
    with pytest.raises(VALIDATOR.ValidationError, match="surfaces requires schemaVersion 2"):
        VALIDATOR.validate_plugin(plugin)


def test_surface_entrypoint_must_be_listed_in_files(tmp_path):
    # Also cross-field (like the v1 entrypoint-in-files rule): the
    # schema is structural, the validator enforces membership.
    plugin = make_v2_plugin(
        tmp_path, {"surfaces": {"dashboard": {"entrypoint": "Missing.qml"}}}
    )
    with pytest.raises(VALIDATOR.ValidationError, match=r"surfaces\.dashboard\.entrypoint must be listed in files"):
        VALIDATOR.validate_plugin(plugin)


def test_primary_surface_conflict_is_rejected_by_validator(tmp_path):
    # Cross-field rule JSON Schema cannot express (documented in the
    # schema): redeclaring the primary placement with a different
    # entrypoint must fail in the validator, never silently override.
    plugin = make_v2_plugin(
        tmp_path, {"surfaces": {"bar": {"entrypoint": "Dashboard.qml"}}}
    )
    Draft202012Validator(SCHEMA).validate(manifest_of(plugin))  # structurally fine
    with pytest.raises(VALIDATOR.ValidationError, match="conflicts with the top-level entrypoint"):
        VALIDATOR.validate_plugin(plugin)


def test_unknown_version_error_is_actionable(tmp_path):
    plugin = make_v2_plugin(tmp_path, {"schemaVersion": 99})
    with pytest.raises(VALIDATOR.ValidationError, match="schemaVersion must be 1 or 2"):
        VALIDATOR.validate_plugin(plugin)


def test_schema_stays_strict_about_unknown_fields():
    Draft202012Validator.check_schema(SCHEMA)
    assert SCHEMA["additionalProperties"] is False
    assert SCHEMA["properties"]["surfaces"]["additionalProperties"] is False
    surface_def = SCHEMA["$defs"]["surface"]
    assert surface_def["additionalProperties"] is False
    # shell#378 adds the dashboard-only size/category card hints; the
    # set stays exact — anything else is still an unknown field.
    assert set(surface_def["properties"]) == {"entrypoint", "enabled", "size", "category"}
    assert set(SCHEMA["properties"]["surfaces"]["properties"]) == {
        "background", "bar", "dashboard", "desktop", "launcher", "settings"
    }


# --- runtime structural contract -------------------------------------------


HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text()
SERVICE = (ROOT / "services/Plugins.qml").read_text()
DOCS = (ROOT / "docs/PLUGINS.md").read_text()


def test_host_runtime_gate_mirrors_validator():
    for needle in (
        "manifest.schemaVersion !== 1 && manifest.schemaVersion !== 2",
        "schemaVersion must be 1 or 2",
        "manifest surfaces requires schemaVersion 2",
        '"background", "bar", "dashboard", "desktop", "launcher", "settings"',
        "contains unknown surface",
        "contains unknown fields",
        ".entrypoint is not a safe relative path",
        ".entrypoint must be listed in files",
        "conflicts with the top-level entrypoint",
        ".enabled must be a boolean",
        "manifest surfaces must be a non-empty object",
    ):
        assert needle in HOST, needle
    # Effective surfaces are recorded once, through the service.
    assert "Plugins.markPlacement(slot.modelData.id, placement, manifest.entrypoint, settings || ({}), effectiveSurfaces)" in HOST
    # The headless host loads only the effective background surface.
    assert 'active: slot.backgroundEntrypoint !== ""' in HOST
    assert "slot.backgroundEntrypoint" in HOST and "background.enabled !== false" in HOST


def test_service_serves_each_surface_independently():
    for needle in (
        "function normalizeSurfaces",
        "function surfaceFor",
        "function hasSurface",
        "function pluginsForSurface",
        "function backgroundPlugins()",
        'root.pluginsForSurface("bar")',
        'root.pluginsForSurface("dashboard")',
        'root.pluginsForSurface("desktop")',
        "declared.enabled === false",
        "entrypoint: declared.entrypoint",
    ):
        assert needle in SERVICE, needle
    # Delegate-recreation guard also covers the surfaces map.
    assert "JSON.stringify(current.surfaces || {})" in SERVICE
    # v1 entries without a surfaces map fall back to placement/entrypoint.
    assert "entry.placement === surface" in SERVICE


def test_visible_hosts_need_no_surface_changes():
    # Hosts keep loading modelData.entrypoint from the per-surface
    # lists; pluginsForSurface hands them copies with the surface's
    # file in that slot.
    for rel, call in (
        ("modules/plugins/PluginBarWidgets.qml", "Plugins.barPlugins()"),
        ("modules/plugins/PluginDashboardCards.qml", "Plugins.dashboardPlugins()"),
        ("modules/plugins/PluginDesktopWidgets.qml", "Plugins.desktopPlugins()"),
    ):
        src = (ROOT / rel).read_text()
        assert call in src, rel
        assert "modelData.entrypoint" in src, rel


def test_docs_state_v2_defaults_and_honest_limits():
    for needle in (
        "Manifest v2",
        '"schemaVersion": 2',
        "`surfaces`",
        "schemaVersion 1",
        "launcher",
        "settings",
        "not loaded",
        "no privilege",
        "not enforcement",
    ):
        assert needle.lower() in DOCS.lower(), needle
