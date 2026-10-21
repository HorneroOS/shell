"""Lock surface accessibility contract.

The lock is the one surface a screen-reader user cannot bypass, so
its two controls must keep their Accessible declarations: the
password field (editable text, named, with instructions) and the
Unlock button. Runtime exposure is probed separately by
tests/atspi/run-lock-probe.sh (needs a Wayland session).
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INPUT_FIELD = ROOT / "modules" / "lock" / "InputField.qml"
CENTER = ROOT / "modules" / "lock" / "Center.qml"


def test_password_field_is_named_editable_text():
    src = INPUT_FIELD.read_text()
    assert "Accessible.role: Accessible.EditableText" in src
    assert 'Accessible.name: qsTr("Password")' in src
    assert "Accessible.description:" in src


def test_unlock_button_is_named():
    src = CENTER.read_text()
    assert "Accessible.role: Accessible.Button" in src
    assert 'Accessible.name: qsTr("Unlock")' in src
