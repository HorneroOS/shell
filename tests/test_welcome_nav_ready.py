"""Welcome sidebar navigation contract: clicking (or arrowing through)
the nav rail must switch pages.

Regression: Window.qml's onCompleted assigned win.x/win.y, which do not
exist on FloatingWindow. The thrown error aborted onCompleted before
_navReady was set, so onCurrentIndexChanged ignored every user
navigation while IPC `welcome open <page>` kept working. The nav sync
must run first and unconditionally, and no client-side positioning may
reappear above (or anywhere near) the _navReady line.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WINDOW = ROOT / "modules" / "welcome" / "Window.qml"


def _on_completed_body() -> str:
    text = WINDOW.read_text()
    assert text.count("Component.onCompleted") == 1, \
        "Window.qml must have exactly one root onCompleted"
    return text.split("Component.onCompleted", 1)[1]


def test_no_client_side_positioning():
    body = _on_completed_body()
    assert "win.x" not in body and "win.y" not in body, \
        "FloatingWindow has no x/y: client-side centering throws and aborts onCompleted"


def test_nav_ready_set_unconditionally_first():
    body = _on_completed_body()
    ready = body.find("_navReady = true")
    assert ready != -1, "onCompleted must set _navReady"
    head = body[:ready]
    assert "if (" not in head and "if(" not in head, \
        "_navReady must be set unconditionally (no branches above it)"
    assert "navList.currentIndex" in head, \
        "nav sync must run before _navReady is set"


def test_nav_handler_guard_preserved():
    text = WINDOW.read_text()
    assert re.search(r"onCurrentIndexChanged:\s*\{[^}]*if\s*\(!win\._navReady\)", text), \
        "nav handler must keep the creation guard on _navReady"
