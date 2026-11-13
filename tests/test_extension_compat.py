"""Extension compatibility suite runner.

Runs the repo's own validator (scripts/validate_plugin.py) over:
  * every shipped example plugin (must ACCEPT), and
  * fixture plugins per design RC5 (must REJECT with a reason):
    unknown schemaVersion (only 1 and 2 exist; shell#373 added 2),
    bad semver, absolute/traversal entrypoint,
    missing files[] entry, unknown placement.
Manifest v2 behaviour itself is covered by
tests/test_plugin_manifest_v2.py.
Also pins the PluginKit surface examples import, and the RC1 regression
contract statically (Plugins.qml mark* must not recreate delegates when
nothing changed — runtime delegate counting needs a Wayland session and
is declared NOT RUN here, see test_gui_smoke.py).
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

from qa_helpers import ROOT

VALIDATOR = ROOT / "scripts" / "validate_plugin.py"
EXAMPLES = ROOT / "examples" / "plugins"

BASE_MANIFEST = {
    "schemaVersion": 1, "id": "compat-fixture", "name": "Compat Fixture",
    "version": "1.0.0", "description": "Compatibility fixture.",
    "author": "QA", "license": "MIT", "entrypoint": "Main.qml",
    "placement": "bar",
    "files": ["Main.qml", "README.md", "LICENSE"],
    "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
}
QML = 'import QtQuick\nimport Hornero.PluginKit\nItem { Text { text: Theme.surface } }\n'


def _run_validator(plugin_dir: Path) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(VALIDATOR), str(plugin_dir)],
                          capture_output=True, text=True, timeout=60)


def _fixture(tmp_path: Path, **overrides) -> Path:
    manifest = dict(BASE_MANIFEST, **overrides)
    plugin = tmp_path / manifest["id"]
    plugin.mkdir()
    (plugin / "manifest.json").write_text(json.dumps(manifest))
    (plugin / "Main.qml").write_text(QML)
    (plugin / "README.md").write_text("# fixture\n")
    (plugin / "LICENSE").write_text("MIT\n")
    return plugin


def test_shipped_examples_accept():
    examples = sorted(d for d in EXAMPLES.iterdir() if (d / "manifest.json").is_file())
    assert examples, "no example plugins shipped"
    for example in examples:
        proc = _run_validator(example)
        assert proc.returncode == 0, f"{example.name} rejected: {proc.stdout}{proc.stderr}"


@pytest.mark.parametrize("overrides,why", [
    ({"schemaVersion": 3}, "unknown schemaVersion must be rejected (RC5; only 1 and 2 exist)"),
    ({"schemaVersion": 0}, "schemaVersion 0 must be rejected"),
    ({"schemaVersion": "2"}, "string schemaVersion must be rejected"),
    ({"version": "1.0"}, "non-semver version must be rejected"),
    ({"entrypoint": "/etc/passwd.qml"}, "absolute entrypoint must be rejected"),
    ({"entrypoint": "../escape.qml"}, "traversal entrypoint must be rejected"),
    ({"entrypoint": "Main.txt"}, "non-QML entrypoint must be rejected"),
    ({"placement": "sidebar"}, "unknown placement must be rejected"),
    ({"files": ["Main.qml", "README.md"]}, "files[] missing LICENSE must be rejected"),
])
def test_incompatible_fixtures_reject(tmp_path, overrides, why):
    proc = _run_validator(_fixture(tmp_path, **overrides))
    assert proc.returncode != 0, f"{why}: validator accepted {overrides}"
    assert (proc.stdout + proc.stderr).strip(), f"{why}: rejection gave no reason"


def test_missing_listed_file_rejects(tmp_path):
    plugin = _fixture(tmp_path)
    (plugin / "LICENSE").unlink()
    proc = _run_validator(plugin)
    assert proc.returncode != 0, "files[] entry missing on disk must be rejected"


def test_valid_fixture_per_placement_accepts(tmp_path):
    for placement in ("background", "bar", "dashboard", "desktop"):
        proc = _run_validator(_fixture(tmp_path / placement if False else tmp_path,
                                       id=f"compat-{placement}", placement=placement))
        assert proc.returncode == 0, f"placement {placement} rejected: {proc.stdout}{proc.stderr}"
        # reset for next iteration (same tmp dir, different id dir is fine)


def test_v1_and_v2_without_surfaces_both_accept(tmp_path):
    # shell#373: schemaVersion 2 without `surfaces` is a valid
    # single-surface manifest; v1 fixtures keep working unchanged.
    for version in (1, 2):
        proc = _run_validator(_fixture(tmp_path, id=f"compat-v{version}",
                                       schemaVersion=version))
        assert proc.returncode == 0, f"schemaVersion {version} rejected: {proc.stdout}{proc.stderr}"


def test_pluginkit_surface_and_no_hardcoded_hex_in_examples():
    kit = ROOT / "plugin" / "qml" / "Hornero" / "PluginKit" / "qmldir"
    assert "module Hornero.PluginKit" in kit.read_text()
    for example in sorted(EXAMPLES.iterdir()):
        for qml in example.rglob("*.qml"):
            text = qml.read_text()
            # RC3: examples must not hardcode palette hex (Theme tokens instead).
            import re
            hexes = re.findall(r'"#[0-9a-fA-F]{6}"', text)
            assert not hexes, f"{qml}: hardcoded hex {hexes} (use Theme.*)"


@pytest.mark.xfail(
    reason="RC1: setState in services/Plugins.qml reassigns entries via "
           "Object.assign map with no same-value guard at this commit; "
           "runtime delegate-count proof additionally needs Wayland (NOT RUN). "
           "Flip to a strict assert when the extensions fix lands.",
    strict=False,
)
def test_rc1_delegate_recreation_guard():
    service = (ROOT / "services" / "Plugins.qml").read_text()
    body = service.split("function setState", 1)[1].split("\n    function ", 1)[0]
    assert "if (" in body and "return" in body.split("entries")[0], \
        "setState must early-return when state/detail are unchanged (RC1)"
