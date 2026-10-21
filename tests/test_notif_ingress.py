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


def test_duplicate_collapse_policy():
    src = NOTIFS.read_text()
    assert "dedupWindowMs" in src and "_isDuplicate" in src
    # Duplicates are dropped at ingress, before entering the list.
    assert "root._isDuplicate(notif)" in src


def test_per_app_cap_and_critical_exemption():
    src = NOTIFS.read_text()
    assert "maxPerApp" in src and "_enforcePerApp" in src
    # Critical urgency is exempt from both flood rules.
    assert src.count("NotificationUrgency.Critical") >= 2


BATTERY = ROOT / "modules" / "BatteryMonitor.qml"
VPN = ROOT / "services" / "VPN.qml"


def test_critical_promotion_entry_point():
    """Shell-detected critical conditions file real notifications.

    They must enter the same list (history + persistence), carry
    critical urgency, and pop up under DND like external critical
    ingress — not vanish with the toast.
    """
    src = NOTIFS.read_text()
    assert "function promoteCritical(" in src
    assert "urgency: NotificationUrgency.Critical" in src
    # Promoted entries are filed by the shell itself.
    assert 'qsTr("HorneroOS")' in src


def test_battery_critical_promotes():
    src = BATTERY.read_text()
    assert "Notifs.promoteCritical" in src
    # Only the critical level promotes; plain warnings stay toasts.
    assert "level.critical" in src


def test_vpn_drop_promotes_but_user_disconnect_does_not():
    src = VPN.read_text()
    assert "Notifs.promoteCritical" in src
    # A disconnect the user asked for is not a "drop": the flag set
    # by disconnect() must gate the promotion.
    assert "userInitiatedDisconnect" in src


def test_promotion_documented():
    doc = (ROOT / "docs" / "NOTIFICATIONS.md").read_text()
    assert "promoteCritical" in doc
