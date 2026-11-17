"""Customisability principle: every shipped surface size is a Control Center setting.

Each size below is persisted in shell.json, has a factory default, and is
edited by a `SizeSlider` in the owning Control Center pane whose range
contains the default, so a user can always go back to the shipped value.
"""
import json
import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
CC = ROOT / "modules" / "controlcenter"
FACTORY = json.loads((ROOT / "config" / "shell.default.json").read_text())

# (pane file, config target, key, factory section path)
SIZES = [
    ("launcher/Settings.qml", "Config.launcher.sizes", "itemWidth", ("launcher", "sizes")),
    ("launcher/Settings.qml", "Config.launcher.sizes", "itemHeight", ("launcher", "sizes")),
    ("launcher/Settings.qml", "Config.launcher.sizes", "wallpaperWidth", ("launcher", "sizes")),
    ("launcher/Settings.qml", "Config.launcher.sizes", "wallpaperHeight", ("launcher", "sizes")),
    ("notifications/NotificationsPane.qml", "Config.notifs.sizes", "width", ("notifs", "sizes")),
    ("notifications/NotificationsPane.qml", "Config.notifs.sizes", "image", ("notifs", "sizes")),
    ("notifications/NotificationsPane.qml", "Config.sidebar.sizes", "width", ("sidebar", "sizes")),
    ("notifications/NotificationsPane.qml", "Config.utilities.sizes", "toastWidth", ("utilities", "sizes")),
    ("session/SessionPane.qml", "Config.session.sizes", "button", ("session", "sizes")),
    ("lockscreen/LockScreenPane.qml", "Config.lock.sizes", "centerWidth", ("lock", "sizes")),
    ("launcher/Settings.qml", "Config.launcher", "maxShown", ("launcher",)),
    ("launcher/Settings.qml", "Config.launcher", "maxWallpapers", ("launcher",)),
    ("launcher/Settings.qml", "Config.launcher", "dragThreshold", ("launcher",)),
    ("notifications/NotificationsPane.qml", "Config.notifs", "groupPreviewNum", ("notifs",)),
    ("notifications/NotificationsPane.qml", "Config.notifs", "expandThreshold", ("notifs",)),
    ("notifications/NotificationsPane.qml", "Config.utilities", "maxToasts", ("utilities",)),
    ("taskbar/PopoutSizes.qml", "Config.bar.sizes", "trayMenuWidth", ("bar", "sizes")),
    ("taskbar/PopoutSizes.qml", "Config.bar.sizes", "batteryWidth", ("bar", "sizes")),
    ("taskbar/PopoutSizes.qml", "Config.bar.sizes", "networkWidth", ("bar", "sizes")),
    ("taskbar/PopoutSizes.qml", "Config.bar.sizes", "kbLayoutWidth", ("bar", "sizes")),
    ("taskbar/PopoutSizes.qml", "Config.bar.sizes", "windowPreviewSize", ("bar", "sizes")),
    ("appearance/sections/LookSection.qml", "Config.controlCenter.sizes", "heightMult", ("controlCenter", "sizes")),
    ("appearance/sections/LookSection.qml", "Config.controlCenter.sizes", "ratio", ("controlCenter", "sizes")),
]


def _slider(pane: str, target: str, key: str) -> dict:
    text = (CC / pane).read_text()
    pat = re.compile(
        r"SizeSlider\s*\{\s*target:\s*" + re.escape(target) + r"\s*key:\s*\"" + key + r"\"(.*?)\n\s*\}",
        re.S,
    )
    m = pat.search(text)
    assert m, f"{pane}: no SizeSlider for {target}.{key}"
    body = m.group(1)
    num = lambda name: float(re.search(name + r":\s*([\d.]+)", body).group(1))
    return {"from": num("from"), "to": num("to"), "default": num("defaultValue")}


@pytest.mark.parametrize("pane,target,key,path", SIZES)
def test_size_is_a_bounded_setting_with_factory_default(pane, target, key, path):
    s = _slider(pane, target, key)
    node = FACTORY
    for part in path:
        node = node[part]
    assert node[key] == s["default"], "Reset must restore the factory value"
    assert s["from"] < s["default"] < s["to"], "range must bracket the default"


def test_size_slider_commits_and_resets():
    qml = (CC / "components" / "SizeSlider.qml").read_text()
    assert "Config.save()" in qml
    assert "Math.max(root.from, Math.min(root.to" in qml, "values are clamped to the range"
    assert "root.target[root.key] = root.defaultValue" in qml
    assert "Accessible.name" in qml


def test_sizes_are_searchable():
    reg = (CC / "PaneRegistry.qml").read_text()
    for sid in ("launcher-sizes", "notification-sizes", "session-size", "lock-size"):
        assert f'id: "{sid}"' in reg


def test_idle_and_battery_defaults_match_factory():
    qml = (CC / "power" / "IdleBatteryPanel.qml").read_text()
    idle = {t["idleAction"] if isinstance(t["idleAction"], str) else "suspend": t["timeout"]
            for t in FACTORY["general"]["idle"]["timeouts"]}
    assert (idle["lock"], idle["dpms off"], idle["suspend"]) == (180, 300, 600)
    for kind, minutes in (("lock", 3), ("dpms", 5), ("suspend", 10)):
        assert f'timeoutMinutes("{kind}", {minutes})' in qml and "factory: %d" % minutes in qml
    levels = sorted((l["level"] for l in FACTORY["general"]["battery"]["warnLevels"]), reverse=True)
    assert levels == [20, 10, 5]
    assert FACTORY["general"]["battery"]["criticalLevel"] == 3
    for n in (20, 10, 5, 3):
        assert f"factory: {n}" in qml
    assert "PowerPane" and "IdleBatteryPanel {}" in (CC / "power" / "PowerPane.qml").read_text()

def test_placement_choices_default_to_factory_and_are_consumed():
    assert FACTORY["launcher"]["align"] == "center" and FACTORY["osd"]["align"] == "center"
    panels = (ROOT / "modules" / "drawers" / "Panels.qml").read_text()
    for needle in ("Config.launcher.align", "Config.osd.align"):
        assert needle in panels
    for pane, target, opts in (("launcher/Settings.qml", "Config.launcher", ("left", "center", "right")),
                               ("osd/OsdPane.qml", "Config.osd", ("top", "center", "bottom"))):
        qml = (CC / pane).read_text()
        assert f"target: {target}" in qml and 'key: "align"' in qml and 'defaultValue: "center"' in qml
        for o in opts:
            assert f'id: "{o}"' in qml

def test_sounds_are_off_by_default_and_wired():
    s = FACTORY["sounds"]
    assert s["enabled"] is False and s["theme"] == "freedesktop" and s["volume"] == 0.5
    assert set(s["events"]) == {"notification", "battery", "charger"}
    svc = (ROOT / "services" / "Sounds.qml").read_text()
    assert "pw-play" in svc and "Config.sounds.enabled" in svc
    assert "replace(/[^A-Za-z0-9_.-]/g" in svc, "theme name is sanitised before building a path"
    assert 'Sounds.play("notification"' in (ROOT / "services" / "Notifs.qml").read_text()
    bat = (ROOT / "modules" / "BatteryMonitor.qml").read_text()
    assert 'Sounds.play("battery"' in bat and 'Sounds.play("charger"' in bat
    for ev in s["events"]:
        assert f'"{ev}"' in svc, ev
    panel = (CC / "notifications" / "SoundsPanel.qml").read_text()
    assert "SoundsPanel {}" in (CC / "notifications" / "NotificationsPane.qml").read_text()
    assert "Config.sounds.enabled" in panel and "defaultValue: 0.5" in panel
