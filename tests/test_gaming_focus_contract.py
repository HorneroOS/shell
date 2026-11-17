"""Gaming/fullscreen focus contract: the shell must never take keyboard
focus away from a fullscreen game and must never put a bar over it.

These are static contracts over the QML (the live behaviour is covered by
qa scenario experience/gaming-fullscreen in the disposable VM):

- the only surfaces allowed to request Exclusive keyboard focus are the ones
  the person opens on purpose (area picker, companion chat, Niri-only
  drawers keyboard intent, which the fullscreen handler closes first);
- every shell layer window that could be drawn over content sits on the Top
  layer or below, so a fullscreen toplevel covers it; only the area picker
  (a user-invoked screenshot tool) uses Overlay;
- while a window is fullscreen on a screen the Drawers window drops its
  input regions, closes every drawer and disables the bar.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML_DIRS = ("modules", "components", "services")


def qml_files():
    for d in QML_DIRS:
        yield from (ROOT / d).rglob("*.qml")
    yield ROOT / "shell.qml"


def hits(pattern: str):
    rx = re.compile(pattern)
    out = []
    for f in qml_files():
        for n, line in enumerate(f.read_text().splitlines(), 1):
            if line.lstrip().startswith("//"):
                continue
            if rx.search(line):
                out.append((str(f.relative_to(ROOT)), n))
    return out


def test_exclusive_keyboard_focus_is_only_requested_by_intentional_surfaces():
    allowed = {
        "modules/areapicker/AreaPicker.qml",   # screenshot tool the person invoked
        "modules/companion/CompanionHost.qml",  # chat the person opened
        "modules/companion/RadioPanel.qml",     # Javi Radio the person opened
        "modules/drawers/Drawers.qml",          # Niri-only keyboardIntent branch
    }
    files = {f for f, _ in hits(r"WlrKeyboardFocus\.Exclusive")}
    assert files <= allowed, f"unexpected Exclusive keyboard focus in {sorted(files - allowed)}"


def test_only_the_area_picker_uses_the_overlay_layer():
    files = {f for f, _ in hits(r"WlrLayer\.Overlay")}
    assert files == {"modules/areapicker/AreaPicker.qml"}


def test_drawers_stand_down_under_a_fullscreen_window():
    src = (ROOT / "modules" / "drawers" / "Drawers.qml").read_text()
    assert "readonly property bool hasFullscreen: Compositor.hasFullscreenOnScreen(screen)" in src
    handler = src[src.index("onHasFullscreenChanged:"):]
    handler = handler[: handler.index("}")]
    for drawer in ("launcher", "session", "dashboard", "sidebar", "utilities", "layoutPicker"):
        assert f"visibilities.{drawer} = false;" in handler, drawer
    assert "regions: win.hasFullscreen ? [] : inputRegions.instances" in src
    assert "disabled: scope.barDisabled || win.hasFullscreen" in src
    assert "frameVisible: Config.border.frameEnabled && !win.hasFullscreen" in src


def test_hover_surfaces_never_hold_the_keyboard():
    src = (ROOT / "modules" / "drawers" / "Drawers.qml").read_text()
    # Keyboard focus follows an explicit keyboard intent; hover-only is None.
    assert "keyboardIntent && Compositor.isNiri" in src
    assert ": keyboardIntent ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None" in src
