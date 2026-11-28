"""Welcome navigation readiness & window structure contract."""
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


def test_window_uses_lazy_scene_loader():
    text = WINDOW.read_text()
    assert "Loader {" in text
    assert "sceneLoader" in text
    assert "activeContentSource" in text
    for scene in ("arrival", "personalize", "workstation", "companion",
                  "practice", "extensions", "showcase", "trust", "ready"):
        assert f'"{scene}"' in text, f"Window.qml sceneFiles missing {scene}"
