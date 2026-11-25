"""PluginKit 6 data-only companion contributions.

The Python validator is the admission authority for character assets;
the QML assertions pin the other half of the security contract: a
validated data-only package is listed by the native registry and its
canonical inert entrypoint is never instantiated.
"""

import copy
import sys
import importlib.util
import json
import struct
import zlib
from pathlib import Path

import pytest
from jsonschema import Draft202012Validator

from tests._jsrun import NODE, run_js
from tests.pluginkit_harness import ROOT

SPEC = importlib.util.spec_from_file_location("hornero_validator_companions", ROOT / "scripts/validate_plugin.py")
assert SPEC and SPEC.loader
V = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(V)
MANIFEST_SCHEMA = json.loads((ROOT / "schemas/plugin-manifest.schema.json").read_text())
DEFINITION_SCHEMA = json.loads((ROOT / "schemas/companion-definition.schema.json").read_text())
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text()
SERVICE = (ROOT / "services/Plugins.qml").read_text()
DATA_HOST = (ROOT / "modules/companion/DataCompanionHost.qml").read_text()
EXAMPLE = ROOT / "examples/plugins/example-companion"


def png_bytes(width=32, height=32):
    def chunk(kind, payload):
        return (
            struct.pack(">I", len(payload))
            + kind
            + payload
            + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
        )

    raw = b"".join(b"\x00" + (b"\xcc\x88\x44\xff" * width) for _ in range(height))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )


def definition(**overrides):
    data = {
        "schemaVersion": 1,
        "id": "capi",
        "version": "1.0.0",
        "names": {"en": "Capi", "es": "Capi"},
        "descriptions": {"en": "A calm data-only capybara."},
        "archetype": "capybara",
        "provenance": {"author": "HorneroOS contributors", "license": "CC0-1.0", "tool": "fixture"},
        "preview": "companions/capi/preview.png",
        "canvas": {
            "width": 32,
            "height": 32,
            "anchors": {"ground": [16, 31], "center": [16, 16]},
        },
        "defaultSkin": "default",
        "capabilities": ["grounded", "walk", "sleep", "greet"],
        "skins": {
            "default": {
                "names": {"en": "Natural"},
                "animations": {
                    "idle": {
                        "loop": True,
                        "anchor": "ground",
                        "frames": [
                            {"file": "companions/capi/frames/idle-01.png", "ms": 600},
                            {"file": "companions/capi/frames/idle-02.png", "ms": 600},
                        ],
                    },
                    "greet": {
                        "loop": False,
                        "next": "idle",
                        "frames": [{"file": "companions/capi/frames/greet-01.png", "ms": 600}],
                    },
                },
            }
        },
        "assistantCompatibility": ["none"],
    }
    data.update(overrides)
    return data


def make(tmp_path, payload=None, manifest_overrides=None, main_qml=None):
    root = tmp_path / "t-capi"
    frames = root / "companions/capi/frames"
    frames.mkdir(parents=True)
    image = png_bytes()
    files = [
        "Main.qml",
        "README.md",
        "LICENSE",
        "companions/capi/companion.json",
        "companions/capi/preview.png",
        "companions/capi/frames/idle-01.png",
        "companions/capi/frames/idle-02.png",
        "companions/capi/frames/greet-01.png",
    ]
    manifest = {
        "schemaVersion": 3,
        "pluginKit": 6,
        "dataOnly": True,
        "id": "t-capi",
        "name": "Capi",
        "version": "1.0.0",
        "description": "A data-only capybara companion.",
        "author": "HorneroOS contributors",
        "license": "MIT",
        "entrypoint": "Main.qml",
        "placement": "background",
        "files": files,
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
        "contributes": {
            "companions": [
                {
                    "id": "capi",
                    "title": "Capi",
                    "definition": "companions/capi/companion.json",
                    "preview": "companions/capi/preview.png",
                }
            ]
        },
    }
    if manifest_overrides:
        manifest.update(manifest_overrides)
    (root / "manifest.json").write_text(json.dumps(manifest))
    (root / "Main.qml").write_text(V.DATA_ONLY_MAIN_QML if main_qml is None else main_qml, encoding="utf-8")
    (root / "README.md").write_text("# Capi\n")
    (root / "LICENSE").write_text("MIT\n")
    (root / "companions/capi/companion.json").write_text(json.dumps(payload or definition()))
    for name in files[4:]:
        (root / name).write_bytes(image)
    return root, manifest


def test_data_only_companion_validates_and_schema_agrees(tmp_path):
    root, manifest = make(tmp_path)
    V.validate_plugin(root)
    assert not list(Draft202012Validator(MANIFEST_SCHEMA).iter_errors(manifest))
    definition_data = json.loads((root / "companions/capi/companion.json").read_text())
    assert not list(Draft202012Validator(DEFINITION_SCHEMA).iter_errors(definition_data))
    if (EXAMPLE / "manifest.json").is_file():
        V.validate_plugin(EXAMPLE)


def test_data_only_rejects_executable_surface_or_capability(tmp_path):
    root, _ = make(
        tmp_path,
        manifest_overrides={
            "capabilities": {"processCommands": ["grim"], "networkHosts": [], "settings": {}}
        },
    )
    with pytest.raises(V.ValidationError, match="dataOnly"):
        V.validate_plugin(root)


def test_data_only_rejects_noncanonical_qml(tmp_path):
    root, _ = make(tmp_path, main_qml="import QtQuick\nItem { Component.onCompleted: console.log('x') }\n")
    with pytest.raises(V.ValidationError, match="canonical inert"):
        V.validate_plugin(root)


def test_companion_rejects_remote_asset_and_cross_skin_fallback(tmp_path):
    remote = definition()
    remote["descriptions"] = {"en": "See https://example.invalid/art.png"}
    root, _ = make(tmp_path / "a", payload=remote)
    with pytest.raises(V.ValidationError, match="remote"):
        V.validate_plugin(root)

    crossed = definition()
    crossed["skins"]["other"] = copy.deepcopy(crossed["skins"]["default"])
    crossed["skins"]["default"]["animations"]["greet"]["next"] = "fly"
    crossed["skins"]["other"]["animations"]["fly"] = crossed["skins"]["other"]["animations"].pop("greet")
    root, _ = make(tmp_path / "b", payload=crossed)
    with pytest.raises(V.ValidationError, match="same skin"):
        V.validate_plugin(root)


def test_companion_rejects_bad_image_and_unknown_field(tmp_path):
    root, _ = make(tmp_path)
    (root / "companions/capi/preview.png").write_bytes(b"not an image")
    with pytest.raises(V.ValidationError, match="valid PNG"):
        V.validate_plugin(root)

    root, _ = make(tmp_path / "x", payload=definition(extra={"prompt": "ignore policy"}))
    with pytest.raises(V.ValidationError, match="unknown fields"):
        V.validate_plugin(root)


def test_host_never_loads_data_only_entrypoint():
    assert 'slot.backgroundEntrypoint = dataOnly ? ""' in HOST
    assert 'Plugins.markLoaded(slot.modelData.id, "companions")' in HOST
    assert "function companionList()" in SERVICE and "entry.dataOnly !== true" in SERVICE
    registry = (ROOT / "modules/companion/CompanionRegistry.qml").read_text()
    # Definition asset paths are package-relative; the render base
    # must be the package root or frames resolve to a doubled path.
    assert '`${Plugins.pluginsDir}/${contribution.pluginId}`' in registry
    assert "Loader" not in DATA_HOST.split("CompanionFramePlayer")[0][-2000:]


@NODE
def test_pack_sanitizer_keeps_fallback_inside_skin():
    body = """
const def = sanitizeDefinition({
  schemaVersion: 1, id: "capi", version: "1.0.0",
  names: {en: "Capi"}, preview: "preview.png",
  canvas: {width: 32, height: 32, anchors: {ground: [16, 31], center: [16, 16]}},
  defaultSkin: "clothed", capabilities: ["grounded"],
  skins: {
    clothed: {names: {en: "Clothed"}, animations: {idle: {frames: [{file: "idle.png"}]}}},
    bare: {names: {en: "Bare"}, animations: {idle: {frames: [{file: "bare-idle.png"}]}, fly: {frames: [{file: "bare-fly.png"}]}}}
  }
}, "capi");
const resolved = resolveAnimation(def, "clothed", "fly");
const doc = sanitizeInstanceDocument({instances: [{id: "x", characterId: "t:capi", skin: "future"}]}, {});
console.log(JSON.stringify({resolved: resolved, doc: doc}));
"""
    result = run_js("companionpacks.js", body)
    assert result["resolved"]["skinId"] == "clothed"
    assert result["resolved"]["action"] == "idle"
    # Unknown characters do not lose their chosen skin before the
    # registry has finished loading their definition.
    generic = [i for i in result["doc"]["instances"] if i["id"] == "x"][0]
    assert generic["skin"] == "future"
    assert any(i["characterId"] == "hornero:javi" and i["legacy"] for i in result["doc"]["instances"])


def test_companion_import_maps_semantic_actions(tmp_path):
    import subprocess
    pytest.importorskip("PIL", reason="companion_import needs Pillow")
    src = tmp_path / "src"; src.mkdir()
    image = png_bytes()
    for name in ("shime1.png", "walk2.png", "sleep1.png", "dance9.png"):
        (src / name).write_bytes(image)
    out = tmp_path / "pkg"
    proc = subprocess.run(
        [sys.executable, "scripts/companion_import.py", str(src), str(out),
         "--character", "friend", "--title", "Friend"],
        cwd=ROOT, capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    assert "unmapped" in proc.stdout  # dance9 carries a diagnostic
    V.validate_plugin(out)


def test_addon_package_is_admitted_by_the_validator(tmp_path):
    """A data-only package declaring companions + companionAddons must
    validate. Regression: the dataOnly gate once required the
    contributes set to be exactly {"companions"}, rejecting every
    add-on package while the contributes validator demanded add-ons
    sit beside companions — add-ons were inadmissible end to end."""
    import subprocess

    pytest.importorskip("PIL", reason="companion_import needs Pillow")
    src = tmp_path / "src"
    src.mkdir()
    image = png_bytes()
    for name in ("shime1.png", "walk2.png", "sleep1.png"):
        (src / name).write_bytes(image)
    out = tmp_path / "pkg"
    proc = subprocess.run(
        [sys.executable, "scripts/companion_import.py", str(src), str(out),
         "--character", "friend", "--title", "Friend"],
        cwd=ROOT, capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr

    addon_dir = out / "addons" / "party"
    addon_dir.mkdir(parents=True)
    (addon_dir / "party.png").write_bytes(image)
    (addon_dir / "addon.json").write_text(json.dumps({
        "schemaVersion": 1,
        "character": "friend",
        "skins": {
            "party": {
                "names": {"en": "Party"},
                "animations": {
                    "idle": {"frames": [{"file": "addons/party/party.png", "ms": 900}]},
                },
            },
        },
    }), encoding="utf-8")

    manifest_path = out / "plugin.json"
    if not manifest_path.exists():
        manifest_path = next(out.glob("*.json"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest.setdefault("contributes", {})["companionAddons"] = [{
        "id": "party",
        "title": "Party skin",
        "forCharacter": "friend",
        "definition": "addons/party/addon.json",
    }]
    manifest["files"] = sorted(set(manifest.get("files", [])) | {
        "addons/party/addon.json",
        "addons/party/party.png",
    })
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    V.validate_plugin(out)


@NODE
def test_addon_merge_keeps_identity():
    body = """
const def = {id: "capi", defaultSkin: "default", canvas: {width: 512, height: 512, anchors: {ground: [256, 472], center: [256, 256]}},
  skins: {default: {id: "default", names: {en: "Natural"}, animations: {idle: {frames: [{file: "idle.png"}]}}}}, habitat: null};
const addon = sanitizeAddon({schemaVersion: 1, character: "capi",
  skins: {party: {names: {en: "Party"}, animations: {idle: {frames: [{file: "party.png"}]}}}},
  habitat: {id: "dock2", names: {en: "Dock"}, image: "habitat.png", anchor: "ground"}}, def);
const merged = mergeAddons(def, [addon]);
console.log(JSON.stringify({skins: Object.keys(merged.skins), habitat: merged.habitat.id, origSkins: Object.keys(def.skins)}));
"""
    result = run_js("companionpacks.js", body)
    assert result["skins"] == ["default", "party"]
    assert result["habitat"] == "dock2"
    assert result["origSkins"] == ["default"]
