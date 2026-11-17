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
    assert "root.commit(root.defaultValue)" in qml
    assert "Accessible.name" in qml


def test_sizes_are_searchable():
    reg = (CC / "PaneRegistry.qml").read_text()
    for sid in ("launcher-sizes", "notification-sizes", "session-size", "lock-size"):
        assert f'id: "{sid}"' in reg
