"""Unit tests for the Welcome VM matrix generator (no hypervisor needed).

welcome-schemes.py reads the shell's own Hornero Signal tables, so these
tests pin the live-scheme contract the guest consumes (schema v2).
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

LIB = Path(__file__).resolve().parent / "lib"
GEN = LIB / "welcome-schemes.py"
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from signal_tokens import OPTIONAL_ROLES, ROLES  # noqa: E402


def _generate(mode: str) -> dict:
    proc = subprocess.run(
        [sys.executable, str(GEN), "--mode", mode],
        capture_output=True, text=True, timeout=60,
    )
    assert proc.returncode == 0, proc.stderr
    return json.loads(proc.stdout)


def _assert_shape(doc: dict, theme_id: str, mode: str) -> None:
    assert doc["schemaVersion"] == 2
    assert doc["id"] == theme_id
    assert doc["mode"] == mode
    assert set(ROLES) <= set(doc["palette"]) <= set(ROLES) | set(OPTIONAL_ROLES)
    for role, value in doc["palette"].items():
        assert isinstance(value, str) and value.startswith("#") and len(value) == 7, role
        int(value[1:], 16)
    assert len(doc["terminal"]) == 16


def test_day_scheme_matches_builtin():
    doc = _generate("day")
    _assert_shape(doc, "hornero-signal-day", "light")
    assert doc["palette"]["ground"] == "#E8EDF4"


def test_contrast_scheme_matches_builtin():
    doc = _generate("contrast")
    _assert_shape(doc, "hornero-signal-contrast", "dark")
    assert doc["palette"]["ink"] == "#FFFFFF"
