"""Shared helpers for the shell QA suites (tests only, no QML feature code).

Honesty rule: a check that needs a Wayland session, hardware, or a VM is
reported as NOT RUN (pytest.skip with an explicit reason), never as PASS.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CTL = shutil.which("horneroctl")

# horneroctl read-only leaves that are safe to execute on any host:
# no --yes, no mutation verb, no hardware write, no network install.
SAFE_READ_LEAVES = [
    ["appearance", "status"],
    ["config", "show"],
    ["config", "validate"],
    ["doctor"],
    ["gaming", "doctor"],
    ["gaming", "selection", "show"],
    ["plugin", "list"],
    ["studio", "doctor"],
    ["studio", "jobs", "list"],
    ["studio", "mode"],
    ["studio", "selection", "show"],
    ["system", "info"],
]

ENVELOPE_KEYS = {"command", "ok", "message", "data"}


def isolated_env(tmp_path: Path) -> dict:
    """Env pointing HOME/XDG at a scratch tree so ctl writes stay local."""
    env = dict(os.environ)
    env["HOME"] = str(tmp_path / "home")
    env["XDG_CONFIG_HOME"] = str(tmp_path / "config")
    env["XDG_STATE_HOME"] = str(tmp_path / "state")
    env["XDG_CACHE_HOME"] = str(tmp_path / "cache")
    env["XDG_DATA_HOME"] = str(tmp_path / "data")
    for key in ("WAYLAND_DISPLAY", "DISPLAY"):
        env.pop(key, None)
    return env


def run_ctl(args: list[str], env: dict, timeout: int = 30) -> dict:
    """Run `horneroctl --json <args>` and return the parsed envelope."""
    assert CTL, "horneroctl not on PATH (NOT RUN elsewhere, hard fail here)"
    proc = subprocess.run(
        [CTL, "--json", *args], capture_output=True, text=True,
        timeout=timeout, env=env,
    )
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise AssertionError(
            f"horneroctl --json {' '.join(args)} did not emit a JSON envelope: "
            f"rc={proc.returncode} stdout={proc.stdout[:200]!r} stderr={proc.stderr[:200]!r}"
        ) from exc


def assert_envelope(env: dict, leaf: list[str]) -> None:
    assert ENVELOPE_KEYS <= set(env), f"{leaf}: envelope missing {ENVELOPE_KEYS - set(env)}"
    assert isinstance(env["ok"], bool), f"{leaf}: ok must be bool"
    assert isinstance(env["message"], str), f"{leaf}: message must be str"
    assert isinstance(env["data"], dict), f"{leaf}: data must be a map"
    for key, value in env["data"].items():
        assert isinstance(value, str), f"{leaf}: data[{key!r}] must be str, got {type(value)}"


def qml_horneroctl_argv(qml_path: Path) -> list[list[str]]:
    """Literal horneroctl argv arrays referenced by a QML file.

    Only fully-literal string arrays are returned; arrays built from
    variables are covered by the pane contract tests, not here.
    """
    text = qml_path.read_text()
    argv_list = []
    for match in re.finditer(r'\[\s*"horneroctl"((?:\s*,\s*"[^"]*")+)\s*\]', text):
        argv_list.append(re.findall(r'"([^"]*)"', match.group(1)))
    return argv_list


def normalize_leaf(argv: list[str]) -> list[str]:
    """Drop the --json flag wherever the pane placed it."""
    return [a for a in argv if a != "--json"]
