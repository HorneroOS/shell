"""Persistence-across-restart tests (no hardware required).

A "restart" is simulated honestly: state is written by one horneroctl
process against an isolated HOME/XDG tree, then read back by a *separate*
horneroctl process (the exact boundary a shell restart crosses). QML-side
persistence (Config -> shell.json) is pinned statically against the
serializer contract in config/Config.qml. VM/hardware restart scenarios
(real reboot, compositor restart) are declared NOT RUN in tests/vm.
"""
from __future__ import annotations

import json

import pytest

from qa_helpers import CTL, ROOT, assert_envelope, isolated_env, run_ctl

pytestmark = pytest.mark.skipif(CTL is None, reason="NOT RUN: horneroctl not on PATH")


def test_gaming_selection_survives_restart(tmp_path):
    env = isolated_env(tmp_path)
    written = run_ctl(["gaming", "selection", "set", "--specialization",
                       "desktop-gaming", "--application", "steam"], env)
    assert written["ok"] is True
    selection_file = tmp_path / "config" / "hornero" / "gaming-selection.json"
    assert selection_file.is_file()
    on_disk = json.loads(selection_file.read_text())
    assert on_disk["specializations"] == ["desktop-gaming"]
    # Fresh process == restart boundary.
    read_back = run_ctl(["gaming", "selection", "show"], env)
    assert read_back["data"]["state"] == "recorded"
    assert read_back["data"]["applications"] == "steam"


def test_studio_selection_survives_restart(tmp_path):
    env = isolated_env(tmp_path)
    written = run_ctl(["studio", "selection", "set", "--specialization",
                       "video-editing-post-production"], env)
    assert written["ok"] is True
    read_back = run_ctl(["studio", "selection", "show"], env)
    assert_envelope(read_back, ["studio", "selection", "show"])
    assert "video-editing-post-production" in read_back["data"].get("specializations", "") \
        or "video-editing-post-production" in read_back["message"]


def test_empty_state_is_empty_not_error_after_restart(tmp_path):
    env = isolated_env(tmp_path)
    read_back = run_ctl(["gaming", "selection", "show"], env)
    assert read_back["ok"] is True
    assert read_back["data"]["state"] == "not-selected"


def test_shell_config_persistence_contract_is_single_writer():
    config = (ROOT / "config" / "Config.qml").read_text()
    # Runtime settings live in one file, written through one save path.
    assert "shell.json" in config and "Paths.config" in config
    assert config.count("function onSaveRequested()") == 1
    plugins = (ROOT / "config" / "PluginsConfig.qml").read_text()
    assert "saveRequested()" in plugins, "plugin settings must persist via Config.save"
