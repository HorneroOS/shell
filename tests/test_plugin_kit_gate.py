"""PluginKit version gate: a stale Hornero.PluginKit must be refused plainly.

The shell resolves Hornero.PluginKit from the QML import path; a partial
package upgrade can leave the previous kit there. The host probes the
PluginKitInfo marker and refuses to host extensions instead of failing each
one with raw QML type errors.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

import pytest

from tests.pluginkit_harness import KIT, ROOT, qmltestrunner

PROBE = """import QtQuick
import QtTest
import Fake.Kit as Kit
TestCase {
  name: "gate"
  function test_level() {
    compare(Kit.PluginKitInfo ? Kit.PluginKitInfo.apiLevel : 0, %d)
  }
}
"""


def _kit(tmp_path: Path, name: str, with_info: bool) -> Path:
    module = tmp_path / name / "Fake" / "Kit"
    module.mkdir(parents=True)
    # The previous kit still exported its other singletons.
    (module / "Theme.qml").write_text("pragma Singleton\nimport QtQuick\nQtObject {}\n", encoding="utf-8")
    lines = ["module Fake.Kit", "singleton Theme 1.0 Theme.qml"]
    if with_info:
        (module / "PluginKitInfo.qml").write_text((KIT / "PluginKitInfo.qml").read_text(encoding="utf-8"), encoding="utf-8")
        lines.append("singleton PluginKitInfo 1.0 PluginKitInfo.qml")
    (module / "qmldir").write_text("\n".join(lines) + "\n", encoding="utf-8")
    return tmp_path / name


def _run(import_path: Path, expected: int, tmp_path: Path) -> subprocess.CompletedProcess[str]:
    runner = qmltestrunner()
    assert runner is not None
    test = tmp_path / f"tst_gate_{expected}.qml"
    test.write_text(PROBE % expected, encoding="utf-8")
    return subprocess.run(
        [str(runner), "-import", str(import_path), "-input", str(test), "-o", "-,txt"],
        capture_output=True, text=True, timeout=60, env={"QT_QPA_PLATFORM": "offscreen", "PATH": "/usr/bin"})


def _level() -> int:
    source = (KIT / "PluginKitInfo.qml").read_text(encoding="utf-8")
    return int(re.search(r"apiLevel:\s*(\d+)", source).group(1))


def test_marker_is_registered_and_matches_validator():
    assert "singleton PluginKitInfo 1.0 PluginKitInfo.qml" in (KIT / "qmldir").read_text(encoding="utf-8")
    out = subprocess.run([sys.executable, str(ROOT / "scripts/validate_plugin.py"), "--info"],
                         capture_output=True, text=True, check=True).stdout
    info = json.loads(out)
    assert info["pluginKit"] == _level()
    assert info["schemaVersions"] == [3]


def test_host_and_service_wire_the_gate():
    host = (ROOT / "modules/plugins/PluginHost.qml").read_text(encoding="utf-8")
    service = (ROOT / "services/Plugins.qml").read_text(encoding="utf-8")
    pane = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text(encoding="utf-8")
    assert "Plugins.kitLevel = Kit.PluginKitInfo ? Kit.PluginKitInfo.apiLevel : 0" in host
    assert "Plugins.hostingBlocked ? []" in host
    assert "readonly property bool kitBlocked" in service
    assert service.count("root.hostingBlocked") >= 4
    assert "Plugins.kitBlocked" in pane


@pytest.mark.skipif(qmltestrunner() is None, reason="qmltestrunner not installed")
def test_probe_reads_zero_on_a_kit_without_the_marker(tmp_path):
    result = _run(_kit(tmp_path, "old", with_info=False), 0, tmp_path)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "FAIL" not in result.stdout


@pytest.mark.skipif(qmltestrunner() is None, reason="qmltestrunner not installed")
def test_probe_reads_the_api_level_on_a_current_kit(tmp_path):
    result = _run(_kit(tmp_path, "new", with_info=True), _level(), tmp_path)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "FAIL" not in result.stdout
