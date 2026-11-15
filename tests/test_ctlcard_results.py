"""CtlCard renders horneroctl probe results as label/value rows.

The Control Center Health & sync cards (and the System probes) used to dump
`key : value` output as one mono text block; long paths wrapped into the
keys. The result is now parsed into rows (label column + value column) and
any non-key line keeps a full-width row. Regression for the Appearance
Health & sync pane composition.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CARD = (ROOT / "modules/controlcenter/components/CtlCard.qml").read_text(encoding="utf-8")
KEY_VALUE = re.compile(r"^([A-Za-z0-9_.-]+)\s*:\s*(.*)$")


def test_result_rows_function_and_key_value_regex_present():
    assert "function resultRows(): var" in CARD
    assert 'line.match(/^([A-Za-z0-9_.-]+)\\s*:\\s*(.*)$/)' in CARD


def test_key_value_lines_split_into_key_and_value():
    assert KEY_VALUE.match("scheme.flavour : expressive").groups() == ("scheme.flavour", "expressive")
    assert KEY_VALUE.match("gtk.colorPolicy: prefer-light").groups() == ("gtk.colorPolicy", "prefer-light")
    m = KEY_VALUE.match("wallpaper : /usr/share/hornero/x/y.png")
    assert m.group(2) == "/usr/share/hornero/x/y.png"


def test_non_key_lines_are_not_split():
    assert KEY_VALUE.match("plain line without key") is None


def test_values_wrap_inside_their_column():
    assert "wrapMode: Text.WrapAnywhere" in CARD
    assert "Layout.maximumWidth: 120" in CARD
