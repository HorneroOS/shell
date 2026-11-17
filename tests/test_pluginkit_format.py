"""PluginKit number formatting: whole numbers must not print as "17.00"."""

from __future__ import annotations

import subprocess

import pytest

from tests.pluginkit_harness import KIT, qmltestrunner

TEST = """import QtQuick
import QtTest
import "file://%(kit)s/Format.js" as Format

TestCase {
  name: "Format"
  function test_whole_numbers_have_no_fraction() {
    compare(Format.number(Qt.locale("en_US"), 17), "17")
    compare(Format.number(Qt.locale("en_US"), 17.0), "17")
    compare(Format.number(Qt.locale("en_US"), 1234567), "1,234,567")
    compare(Format.number(Qt.locale("es_AR"), 1234567), "1.234.567")
    compare(Format.number(Qt.locale("en_US"), 0), "0")
  }
  function test_fractions_are_trimmed() {
    compare(Format.number(Qt.locale("en_US"), 3.5), "3.5")
    compare(Format.number(Qt.locale("en_US"), 3.14159), "3.14")
    compare(Format.number(Qt.locale("en_US"), 3.001), "3")
    compare(Format.number(Qt.locale("es_AR"), 3.5), "3,5")
    compare(Format.number(Qt.locale("en_US"), 3.14159, 3), "3.142")
    compare(Format.number(Qt.locale("en_US"), 3.6, 0), "4")
  }
  function test_non_finite_is_empty() {
    compare(Format.number(Qt.locale("en_US"), NaN), "")
    compare(Format.number(Qt.locale("en_US"), Infinity), "")
  }
}
"""


@pytest.mark.skipif(qmltestrunner() is None, reason="qmltestrunner not installed")
def test_format_number(tmp_path):
    test = tmp_path / "tst_format.qml"
    test.write_text(TEST % {"kit": KIT}, encoding="utf-8")
    result = subprocess.run([str(qmltestrunner()), "-input", str(test), "-o", "-,txt"], capture_output=True,
                            text=True, timeout=60, env={"QT_QPA_PLATFORM": "offscreen", "PATH": "/usr/bin"})
    assert result.returncode == 0, result.stdout + result.stderr
    assert "FAIL" not in result.stdout
