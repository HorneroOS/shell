"""Notification ingress defensiveness (S12): the live list is bounded.

A spammy sender must not grow memory, the center list, or the
persisted JSON without limit. Overflow closes oldest-first.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NOTIFS = ROOT / "services" / "Notifs.qml"


def test_list_size_bounded():
    src = NOTIFS.read_text()
    assert "readonly property int maxListSize" in src
    assert "root.list.length > root.maxListSize" in src
    assert "root.list.slice(root.maxListSize)" in src


def test_bound_documented():
    doc = (ROOT / "docs" / "NOTIFICATIONS.md").read_text()
    assert "maxListSize" in doc
