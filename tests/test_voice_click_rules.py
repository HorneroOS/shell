"""Voice click rules (D6): right-click is never dismissive.

Toasts align with notifications: left/middle dismiss, right is
ignored. Rules documented in docs/NOTIFICATIONS.md.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOASTS = ROOT / "modules" / "utilities" / "toasts" / "Toasts.qml"
NOTIF = ROOT / "modules" / "notifications" / "Notification.qml"


def _accepted_buttons(src: str) -> str:
    m = re.search(r"acceptedButtons:\s*(.+)", src)
    assert m, "acceptedButtons binding missing"
    return m.group(1)


def test_toast_ignores_right_click():
    buttons = _accepted_buttons(TOASTS.read_text())
    assert "Qt.RightButton" not in buttons, "D6: toast must ignore right-click"
    assert "Qt.LeftButton" in buttons
    assert "Qt.MiddleButton" in buttons


def test_notification_ignores_right_click():
    buttons = _accepted_buttons(NOTIF.read_text())
    assert "Qt.RightButton" not in buttons, "notification must ignore right-click"
    assert "Qt.LeftButton" in buttons
    assert "Qt.MiddleButton" in buttons


def test_click_rules_documented():
    doc = (ROOT / "docs" / "NOTIFICATIONS.md").read_text()
    assert "Click rule" in doc
    assert "D6" in doc
