"""Perf baseline harness: the script is runnable, honest, and documented.

Static contract tests (no compositor needed): the harness contract is
asserted structurally so regressions fail here, not on a live machine.
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "perf-baseline.sh"
DOC = ROOT / "docs" / "PERF_BASELINE.md"


def test_harness_exists_and_runs():
    assert SCRIPT.exists(), "missing scripts/perf-baseline.sh"
    assert os.access(SCRIPT, os.X_OK), "harness must be executable"


def test_harness_is_safe_shell():
    text = SCRIPT.read_text()
    assert "set -euo pipefail" in text
    assert "--restart" in text, "startup timing must stay opt-in"
    assert "restart --yes" in text or "shell restart" in text


def test_harness_probes_named_metrics():
    text = SCRIPT.read_text()
    for probe in ("smaps_rollup", "ipc call", "hyprctl layers",
                  "quickshell --version", "startup_ready_ms",
                  "rss_kb", "pss_kb", "ipc_ms"):
        assert probe in text, f"harness missing probe {probe}"


def test_harness_finds_shell_by_either_process_name():
    # The shell runs as `quickshell` (distro binary) or `qs` (wrapper entry
    # point, e.g. the QA guest): both PID resolutions must share one lookup
    # that covers both, preferring the daemon over transient qs ipc clients.
    text = SCRIPT.read_text()
    assert "shell_pid() {" in text
    assert "pgrep -x quickshell" in text
    assert "pgrep -x -o qs" in text
    assert text.count('PID="$(shell_pid)"') == 2, "startup + post-restart must share shell_pid"
    assert "qs --version" in text, "version probe needs the qs fallback too"


def test_methodology_documented():
    assert DOC.exists(), "missing docs/PERF_BASELINE.md"
    text = DOC.read_text()
    for section in ("## What is measured", "## How to run",
                    "## How to compare", "## Rules"):
        assert section in text, f"doc missing {section}"
    assert "never committed" in text.lower()
    assert "never publish estimates" in text.lower()
