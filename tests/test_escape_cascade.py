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


def test_keyboard_focus_follows_grab():
    """Explicit modal grabs use compositor-safe layer focus; hover stays unfocused."""
    src = DRAWERS.read_text()
    focus_line = next(
        line for line in src.splitlines() if "WlrLayershell.keyboardFocus:" in line
    )
    assert "keyboardIntent" in focus_line
    assert "keyboardIntent && Compositor.isNiri" in focus_line
    assert "WlrKeyboardFocus.Exclusive" in src
    assert "WlrKeyboardFocus.OnDemand" in src
    assert "WlrKeyboardFocus.None" in src
    assert "active: Compositor.isHyprland && win.keyboardIntent" in src


def test_niri_focus_loss_releases_exclusive_drawer_focus():
    src = DRAWERS.read_text()
    assert "function dismissNiriTransientSurfaces()" in src
    assert "focusedWindowAtKeyboardIntent" in src
    assert "function onFocusedWindowChanged(): void" in src
    assert "Niri.focusedWindow?.id" in src
    assert "function pointerInsideKeyboardRoot(pointX: real, pointY: real): bool" in src
    assert "Compositor.isNiri && win.keyboardIntent" in src
    assert "dismissNiriTransientSurfaces();" in src
    assert "if (Compositor.isNiri && !active && keyboardIntent)" not in src
    for state in ("launcher", "session", "sidebar", "dashboard", "utilities", "layoutPicker"):
        assert f"visibilities.{state} = false" in src
    assert "panels.popouts.keyboardIntent = false" in src
    assert "panels.popouts.hasCurrent = false" in src


def test_click_outside_covers_utilities():
    src = DRAWERS.read_text()
    assert "interactions.utilitiesKeyboardIntent && visibilities.utilities" in src
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


def test_grab_covers_all_cascade_drawers():
    """Physical keys reach the surface via HyprlandFocusGrab, not Qt
    item focus — so every drawer dismissTopmost() can close needs a
    grab term (nested-proven: grab-less dashboard never saw Escape)."""
    src = DRAWERS.read_text()
    for vis in ("launcher", "session", "sidebar", "dashboard", "utilities", "layoutPicker"):
        assert f"visibilities.{vis}" in src, f"{vis} missing from keyboard intent"


def test_dashboard_grab_is_explicit_only():
    """Hover-opened dashboard must not steal typing from other apps;
    only explicit opens (shortcut/IPC/action, mouse outside the area)
    grab. The showOnHover=false config keeps its unconditional grab."""
    src = DRAWERS.read_text()
    keyboard_intent = next(line for line in src.splitlines() if "property bool keyboardIntent:" in line)
    assert "interactions.dashboardKeyboardIntent" in keyboard_intent
    assert "!Config.dashboard.showOnHover" in keyboard_intent


def test_utilities_grab_is_explicit_only():
    """Utilities opens on bottom-edge hover like the dashboard, so it
    follows the same rule: hover opens never take the keyboard."""
    src = DRAWERS.read_text()
    keyboard_intent = next(line for line in src.splitlines() if "property bool keyboardIntent:" in line)
    assert "interactions.utilitiesKeyboardIntent && visibilities.utilities" in keyboard_intent


def test_click_inside_promotes_keyboard_intent():
    """A click inside a hover-opened drawer is keyboard intent (rename
    field); intent survives the shortcut->hover hand-off and clears
    when the drawer closes."""
    src = (ROOT / "modules" / "drawers" / "Interactions.qml").read_text()
    for name in ("dashboard", "utilities"):
        assert f"property bool {name}KeyboardIntent" in src
        assert f"{name}KeyboardIntent = true" in src
        assert f"root.{name}KeyboardIntent = false" in src


def test_shortcut_active_inferred_from_mouse():
    """Explicit vs hover is inferred at open time: flag flips while the
    mouse is outside the area means keyboard-driven (grab); hovering
    over a shortcut-opened drawer hands control back to hover."""
    src = (ROOT / "modules" / "drawers" / "Interactions.qml").read_text()
    assert "property bool dashboardShortcutActive" in src
    assert "root.dashboardShortcutActive = true" in src
    assert "id: interactions" in DRAWERS.read_text()


def test_no_qt_focus_handoffs_in_drawers():
    """forceActiveFocus() handoffs do not deliver Escape (proven inert
    in nested validation: Qt focus never sticks without compositor
    keyboard focus) and must not creep back into drawer open paths."""
    for rel in (
        "modules/dashboard/Content.qml",
        "modules/dashboard/Wrapper.qml",
        "modules/sidebar/Content.qml",
        "modules/utilities/Content.qml",
        "modules/utilities/Wrapper.qml",
        "modules/layoutpicker/Content.qml",
    ):
        src = (ROOT / rel).read_text()
        assert "forceActiveFocus()" not in src, f"{rel} regained a focus handoff"


def test_drawer_roots_stay_focusable_for_s4():
    """Content roots keep focus:true as S4 keyboard-navigation seeds;
    the grab (not these flags) delivers S3 Escape today."""
    for rel in (
        "modules/dashboard/Content.qml",
        "modules/sidebar/Content.qml",
        "modules/utilities/Content.qml",
    ):
        src = (ROOT / rel).read_text()
        assert "focus: true" in src, f"{rel} lost its focusable root"


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


def test_hover_is_edge_triggered():
    """Hover may only open on enter-edge and close on leave-edge.

    Level-triggered hover (`visibilities.x = showX`) reopens a drawer
    right after an explicit Escape dismissal while the mouse sits
    still inside the area.
    """
    src = (ROOT / "modules" / "drawers" / "Interactions.qml").read_text()
    assert "dashboardHoverInside" in src
    assert "utilitiesHoverInside" in src
    assert "visibilities.dashboard = showDashboard" not in src
    assert "visibilities.utilities = showUtilities" not in src
