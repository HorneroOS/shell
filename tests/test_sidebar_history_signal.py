"""Sidebar notification history adopts the popup anatomy (VA-08)."""
from pathlib import Path

SIDEBAR = Path(__file__).resolve().parent.parent / "modules" / "sidebar"


def _src(name: str) -> str:
    return (SIDEBAR / name).read_text()


def test_group_card_uses_eyebrow_not_icon_tile():
    group = _src("NotifGroup.qml")
    assert "Instruments.Eyebrow" in group
    assert "glyphIconComp" not in group and "getNotifIcon" not in group, (
        "no generic icon tile in history")
    assert "Layout.preferredWidth: 20" in group, "app icon is 20 px"
    assert "x${root.notifCount}" in group and "root.notifCount > 1" in group
    # Urgent is an edge + eyebrow with a word, never a filled tile.
    assert "qsTr(\"Urgent\")" in group
    assert "color: root.urgency === NotificationUrgency.Critical ? Signal.palette.alert : Signal.palette.sunken" not in group


def test_collapsed_row_puts_title_and_body_on_separate_lines():
    notif = _src("Notif.qml")
    assert "anchors.top: summary.bottom" in notif.split("id: compactBody", 1)[1][:300]
    assert "dummySummary.right" not in notif


def test_header_has_count_and_text_clear():
    dock = _src("NotifDock.qml")
    assert 'channel: "04"' in dock and "root.notifCount}`" in dock
    assert "font.underline: true" in dock
    assert "color: Signal.palette.lifted" not in dock, "Clear all is not a filled button"
