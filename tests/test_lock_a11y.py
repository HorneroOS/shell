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


def test_lock_card_is_large_calm_and_never_crossed_by_the_hairline():
    """VA-14: bigger module, 12 px alert with glyph and alert role, num lock
    never announced, diagonal clipped to the strip left of the centre."""
    from pathlib import Path
    root = Path(__file__).resolve().parent.parent / "modules" / "lock"
    center = (root / "Center.qml").read_text()
    content = (root / "Content.qml").read_text()
    assert "Math.max(520, Config.lock.sizes.centerWidth * centerScale)" in center
    assert "Accessible.role: Accessible.AlertMessage" in center and '"alert-triangle"' in center
    assert "Num lock is ON" not in center and "Num lock and" not in center
    assert "(root.width - center.implicitWidth) / 2" in content, "hairline clipped beside the centre column"
