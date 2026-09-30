"""Escape cascade: one central dismissal point (Phase 3 S3).

Inner content with transient state (rename, armed session action,
dialogs) keeps its own handler; every drawer-level close routes
through Drawers.dismissTopmost().
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DRAWERS = ROOT / "modules" / "drawers" / "Drawers.qml"


def test_central_handler_covers_all_drawers():
    src = DRAWERS.read_text()
    assert "function dismissTopmost()" in src
    assert "Keys.onEscapePressed" in src
    for vis in (
        "visibilities.layoutPicker",
        "visibilities.session",
        "visibilities.launcher",
        "visibilities.dashboard",
        "visibilities.sidebar",
        "visibilities.utilities",
    ):
        assert vis in src, f"{vis} missing from Drawers.qml"
    # OSD clears alongside any central dismissal.
    assert "visibilities.osd = false" in src


def test_focus_set_covers_all_drawers():
    """keyboardFocus must include every drawer or Escape never arrives."""
    src = DRAWERS.read_text()
    focus_line = next(
        line
        for line in src.splitlines()
        if "WlrLayershell.keyboardFocus" in line and "visibilities" in line
    )
    for vis in ("launcher", "session", "layoutPicker", "dashboard", "sidebar", "utilities"):
        assert f"visibilities.{vis}" in focus_line, f"{vis} missing from focus set"


def test_click_outside_covers_utilities():
    src = DRAWERS.read_text()
    grab_line = next(
        line for line in src.splitlines() if line.strip().startswith("active:")
    )
    assert "visibilities.utilities" in grab_line
    assert src.count("visibilities.utilities = false") >= 2  # grab + cascade


def test_no_per_drawer_escape_handlers():
    """Launcher/layoutPicker must not handle Escape; central owns it.

    (Direct visibility writes for launch/close-button actions stay —
    only the Escape path is centralized.)
    """
    launcher = (ROOT / "modules" / "launcher" / "Content.qml").read_text()
    assert "onEscapePressed" not in launcher
    picker = (ROOT / "modules" / "layoutpicker" / "Content.qml").read_text()
    assert "onEscapePressed" not in picker


def test_inner_state_handlers_retained():
    """Two-stage dismiss: rename and armed-session keep first Escape."""
    rename = (ROOT / "modules" / "dashboard" / "dash" / "WsActionsBar.qml").read_text()
    assert "Keys.onEscapePressed" in rename
    session = (ROOT / "modules" / "session" / "Content.qml").read_text()
    assert "Keys.onEscapePressed" in session
    assert "armedAction" in session


def test_drawer_contents_take_focus():
    """Dashboard/sidebar/utilities grab focus on open for key delivery."""
    for rel in (
        "modules/dashboard/Content.qml",
        "modules/sidebar/Content.qml",
        "modules/utilities/Content.qml",
    ):
        src = (ROOT / rel).read_text()
        assert "forceActiveFocus()" in src, f"{rel} never takes focus"


def test_companion_menu_dismiss_paths():
    """Companion menu: Escape + click-outside + bubble right-click."""
    src = (ROOT / "modules" / "companion" / "CompanionHost.qml").read_text()
    assert "Keys.onEscapePressed" in src
    assert "HyprlandFocusGrab" in src
    assert "menu.close()" in src
    assert "Qt.LeftButton | Qt.RightButton" in src


def test_fullscreen_clears_drawers():
    src = DRAWERS.read_text()
    handler = src.split("onHasFullscreenChanged")[1].split("}")[0]
    for vis in ("launcher", "session", "dashboard", "sidebar", "utilities", "layoutPicker"):
        assert vis in handler, f"{vis} survives fullscreen"


def test_policy_documented():
    doc = (ROOT / "docs" / "INTERACTION.md").read_text()
    assert "dismissTopmost" in doc
    assert "Companion menu" in doc
