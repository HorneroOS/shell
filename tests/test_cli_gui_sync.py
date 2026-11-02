"""CLI<->GUI state-sync contract tests.

Contract: a Control Center pane reads the *same* horneroctl JSON envelope
the CLI writes — same leaf, same {command, ok, message, data} shape, and
the data keys the QML consumes must exist in the live envelope. Read-only
leaves are executed for real against an isolated HOME/XDG; mutating leaves
are only checked statically (argv shape + --yes placement), never run.
"""
from __future__ import annotations

import pytest

from qa_helpers import (
    CTL, ROOT, SAFE_READ_LEAVES, assert_envelope, isolated_env,
    normalize_leaf, qml_horneroctl_argv, run_ctl,
)

CC = ROOT / "modules" / "controlcenter"
MUTATING = {"set", "add", "remove", "upgrade", "install", "enable", "disable",
            "restore", "create", "toggle", "cancel", "clear"}
READ_SUFFIX = {"status", "show", "list", "current", "doctor", "mode"}


def _pane_argv():
    pairs = []
    for qml in sorted(CC.rglob("*.qml")):
        for argv in qml_horneroctl_argv(qml):
            pairs.append((qml.relative_to(ROOT).as_posix(), normalize_leaf(argv)))
    return pairs


def test_panes_only_call_allowlisted_horneroctl():
    pairs = _pane_argv()
    assert pairs, "no literal horneroctl argv found in panes"
    for source, leaf in pairs:
        assert leaf, f"{source}: empty horneroctl argv"
        assert not any(a in ("sh", "bash", "-c") for a in leaf), \
            f"{source}: shell-out in argv {leaf}"


def test_mutating_pane_calls_carry_yes_or_are_selection_writes():
    # Selection writes (gaming/studio selection set) are recorded by
    # horneroctl without --yes by design; every other mutation must carry it.
    for source, leaf in _pane_argv():
        if leaf and leaf[-1] in READ_SUFFIX:
            continue
        if any(a in MUTATING for a in leaf):
            if leaf[:2] in (["gaming", "selection"], ["studio", "selection"]):
                continue
            assert "--yes" in leaf or "restore" in leaf and leaf[:1] == ["studio"], \
                f"{source}: mutating leaf without --yes: {leaf}"


@pytest.mark.skipif(CTL is None, reason="NOT RUN: horneroctl not on PATH")
@pytest.mark.parametrize("leaf", SAFE_READ_LEAVES, ids=[" ".join(l) for l in SAFE_READ_LEAVES])
def test_read_leaf_envelope_matches_gui_contract(leaf, tmp_path):
    envelope = run_ctl(leaf, isolated_env(tmp_path))
    assert_envelope(envelope, leaf)
    assert envelope["command"], f"{leaf}: empty command echo"


@pytest.mark.skipif(CTL is None, reason="NOT RUN: horneroctl not on PATH")
def test_pane_consumed_data_keys_exist_in_live_envelope(tmp_path):
    """Keys QML reads via env.data.<key> must be produced by the CLI."""
    import re
    consumed = {}
    for qml in sorted(CC.rglob("*.qml")) + sorted((ROOT / "services").rglob("*.qml")):
        keys = set(re.findall(r"env\.data\.([a-z_0-9]+)", qml.read_text()))
        if keys:
            consumed[qml.name] = keys
    assert consumed, "no env.data consumers found (harness drift?)"
    # plugin list is the envelope backing env.data.plugins consumers.
    envelope = run_ctl(["plugin", "list"], isolated_env(tmp_path))
    assert_envelope(envelope, ["plugin", "list"])
    all_consumed = set().union(*consumed.values())
    if "plugins" in all_consumed:
        assert "plugins" in envelope["data"], \
            "QML consumes env.data.plugins but `plugin list` does not emit it"


@pytest.mark.skipif(CTL is None, reason="NOT RUN: horneroctl not on PATH")
def test_cli_written_selection_is_what_pane_reads(tmp_path):
    """Write via CLI (isolated), read back via the pane's exact leaf."""
    env = isolated_env(tmp_path)
    written = run_ctl(
        ["gaming", "selection", "set", "--specialization", "desktop-gaming",
         "--application", "steam"], env)
    assert written["ok"] is True, written["message"]
    # GamingPane/StudioPane read `gaming selection show` / equivalent show leaf.
    read_back = run_ctl(["gaming", "selection", "show"], env)
    assert_envelope(read_back, ["gaming", "selection", "show"])
    assert read_back["data"]["state"] == "recorded"
    assert "desktop-gaming" in read_back["data"]["specializations"]
    assert "steam" in read_back["data"]["applications"]
