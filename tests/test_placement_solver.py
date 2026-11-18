"""Anchored-surface solver (RFC 0001 §4) unit tests, run under node.

The cases live in tests/placement/placement.test.mjs (node:test) because
components/placement/Placement.js is a QML `.pragma library` script; this
wrapper makes them part of the pytest gate.
"""

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOLVER = ROOT / "components/placement/Placement.js"
CASES = ROOT / "tests/placement/placement.test.mjs"


def test_solver_unit_tests_pass_under_node():
    node = shutil.which("node")
    assert node, "node is required to execute the Placement.js unit tests"
    proc = subprocess.run([node, "--test", "--test-reporter=tap", str(CASES), str(CASES.with_name("matrix.test.mjs"))], capture_output=True, text=True, timeout=120, check=False)
    assert proc.returncode == 0, proc.stdout[-6000:] + proc.stderr[-2000:]
    assert "# fail 0" in proc.stdout


def test_solver_is_a_pure_qml_library():
    src = SOLVER.read_text()
    assert src.startswith(".pragma library")
    # Pure: no QML item access, no imports, no timers.
    for banned in ("Qt.", "import ", "mapToItem", "console."):
        assert banned not in src, banned
    assert "function solve(input)" in src
    assert "function seedRect(placement)" in src
