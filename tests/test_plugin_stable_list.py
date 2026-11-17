"""StableList: host models must not be rebuilt by load-state updates.

Root cause of dashboard entrypoints stuck `pending` ("Object or context
destroyed during incubation"): every state report republished all host
models, so every Repeater destroyed every other plugin's async Loader.
"""

from __future__ import annotations

import subprocess

import pytest

from tests.pluginkit_harness import ROOT, qmltestrunner

HOSTS = ["PluginHost.qml", "PluginBarWidgets.qml", "PluginDesktopWidgets.qml",
         "PluginDashboardCards.qml", "PluginLauncherHost.qml"]

TEST = """import QtQuick
import QtTest
import "file://%(dir)s" as Host

TestCase {
  name: "StableList"
  Host.StableList { id: stable }
  function entry(id, state, attempts) {
    return { id: id, entrypoint: id + ".qml", state: state, detail: "", loadMs: 0, attempts: attempts,
             attemptTimesMs: [attempts], diagnostics: [], marketplace: null, description: "d" };
  }
  function test_state_changes_keep_the_same_array() {
    stable.source = [entry("a", "pending", 1), entry("b", "pending", 1)];
    const first = stable.list;
    compare(first.length, 2);
    stable.source = [entry("a", "loaded", 1), entry("b", "pending", 1)];
    verify(stable.list === first, "state report must not republish the model");
    stable.source = [entry("a", "loaded", 1), entry("b", "failed", 1)];
    verify(stable.list === first);
  }
  function test_structure_and_reload_republish() {
    stable.source = [entry("a", "loaded", 1)];
    const first = stable.list;
    stable.source = [entry("a", "loaded", 1), entry("c", "pending", 1)];
    verify(stable.list !== first, "a new plugin changes the structure");
    const second = stable.list;
    stable.source = [entry("a", "pending", 2), entry("c", "pending", 1)];
    verify(stable.list !== second, "reload bumps attempts and re-creates the Loader");
  }
  function test_nested_sections() {
    stable.source = [{ key: "", plugins: [entry("a", "pending", 1)] }];
    const first = stable.list;
    stable.source = [{ key: "", plugins: [entry("a", "loaded", 1)] }];
    verify(stable.list === first);
  }
}
"""


@pytest.mark.skipif(qmltestrunner() is None, reason="qmltestrunner not installed")
def test_stable_list_republishes_only_on_structural_change(tmp_path):
    test = tmp_path / "tst_stable.qml"
    test.write_text(TEST % {"dir": ROOT / "modules/plugins"}, encoding="utf-8")
    result = subprocess.run(
        [str(qmltestrunner()), "-input", str(test), "-o", "-,txt"],
        capture_output=True, text=True, timeout=60, env={"QT_QPA_PLATFORM": "offscreen", "PATH": "/usr/bin"})
    assert result.returncode == 0, result.stdout + result.stderr
    assert "FAIL" not in result.stdout


@pytest.mark.parametrize("host", HOSTS)
def test_every_host_builds_delegates_from_a_stable_list(host):
    source = (ROOT / "modules/plugins" / host).read_text(encoding="utf-8")
    assert "StableList {" in source, host
