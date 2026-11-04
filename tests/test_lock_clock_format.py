"""Lock screen clock-format row (shell#237 remainder).

The 12/24-hour preference already existed as
Config.services.useTwelveHourClock (consumed by the lock clock in
modules/lock/Center.qml, the bar clock, and Time), but no pane
exposed it. The Lock screen pane now binds it directly and persists
through Config.save(), like every other row in that pane.
"""
from pathlib import Path

ROOT = Path(__file__).parent.parent
PANE = (ROOT / "modules/controlcenter/lockscreen/LockScreenPane.qml").read_text()
LOCK_CENTER = (ROOT / "modules/lock/Center.qml").read_text()


def test_lock_pane_exposes_clock_format_bound_to_real_config():
    assert "checked: Config.services.useTwelveHourClock" in PANE
    assert "Config.services.useTwelveHourClock = checked;" in PANE
    # The lock surface really consumes the same knob.
    assert "Config.services.useTwelveHourClock" in LOCK_CENTER
