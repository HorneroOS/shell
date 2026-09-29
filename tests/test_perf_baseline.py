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


def test_methodology_documented():
    assert DOC.exists(), "missing docs/PERF_BASELINE.md"
    text = DOC.read_text()
    for section in ("## What is measured", "## How to run",
                    "## How to compare", "## Rules"):
        assert section in text, f"doc missing {section}"
    assert "never committed" in text.lower()
    assert "never publish estimates" in text.lower()
