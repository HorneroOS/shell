"""Accessible-name gate for MouseArea-driven controls (shell#221).

Every QML file that drives interaction through MouseArea /
CustomMouseArea must either expose an Accessible.name for its
interactive controls or be listed below with the reason its
MouseAreas are not independently nameable controls (backdrop,
wheel-only, hover-only, focus guard, or infrastructure whose
parent control already carries the name). The allowlist must stay
exact: a file that gains names leaves the list, and a new unnamed
interactive surface fails here instead of silently shipping.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

ALLOWLIST = {
    "modules/areapicker/Picker.qml":
        "full-screen area-selection surface; the selection geometry is "
        "the interaction and Escape cancels (Keys.onEscapePressed)",
    "modules/bar/components/workspaces/SpecialWorkspaces.qml":
        "drag/wheel scroller over the workspace strip; the workspace "
        "buttons inside carry their own Accessible names",
    "modules/controlcenter/ControlCenter.qml":
        "wheel tab-switch guard during the opening animation; tabs are "
        "named NavRail buttons",
    "modules/controlcenter/Panes.qml":
        "focus guard: onPressed re-focuses the pane and is not accepted",
    "modules/controlcenter/appearance/sections/ThemeModeSection.qml":
        "hover-only live preview (acceptedButtons: Qt.NoButton); the "
        "mode itself is chosen with named radio controls",
    "modules/dashboard/Performance.qml":
        "wheel-only disk cycling on the storage gauge; the gauge data "
        "is also rendered as text",
    "modules/dashboard/Tabs.qml":
        "CustomMouseArea is the contentItem of a TabButton whose text "
        "names it (verified as AT-SPI page tabs)",
    "modules/drawers/Interactions.qml":
        "drawer backdrop / wheel interaction layer; panels opened from "
        "named bar controls",
    "modules/controlcenter/network/WirelessPasswordDialog.qml":
        "backdrop click dismisses; the dialog's field and buttons are "
        "named controls",
    "modules/utilities/RecordingDeleteModal.qml":
        "backdrop click dismisses plus a click shield; the dialog "
        "actions are named TextButtons",
    "components/StateLayer.qml":
        "ripple/hover layer embedded in parent controls that carry "
        "the Accessible name (ButtonBase and friends)",
    "components/controls/CustomMouseArea.qml":
        "wheel-threshold infrastructure base class with no click "
        "semantics of its own",
    "components/controls/StyledInputField.qml":
        "wrapper around a real TextInput, which the platform bridge "
        "exposes as editable text",
    "components/controls/StyledScrollBar.qml":
        "Qt ScrollBar template; scrolling is also available via the "
        "flickable it is attached to",
    "components/controls/StyledSwitch.qml":
        "Qt Switch template named by its embedding ToggleRow/SwitchRow "
        "(Accessible.name set there)",
}

NAMED_EXPECTATIONS = {
    "modules/bar/components/TrayItem.qml": ["modelData.title"],
    "modules/bar/components/OsIcon.qml": ["Open launcher"],
    "modules/utilities/toasts/Toasts.qml": ["Dismiss notification"],
    "modules/sidebar/NotifDockList.qml": ["Notifications from"],
    "modules/sidebar/NotifGroupList.qml": ["modelData.summary"],
    "modules/companion/CompanionHost.qml": [
        "Dismiss Javi message", "Javi, el Hornero", "parent.label"],
    "modules/launcher/Content.qml": ["Clear search"],
    "modules/welcome/ShortcutList.qml": ["chip.label"],
    "modules/dashboard/dash/Calendar.qml": [
        "Previous month", "Next month"],
    "modules/dashboard/dash/User.qml": ["Change profile picture"],
}


def _mousearea_files():
    out = []
    for d in ("modules", "components"):
        for p in sorted((ROOT / d).rglob("*.qml")):
            if "MouseArea" in p.read_text(errors="ignore"):
                out.append(p)
    return out


def test_every_mousearea_file_is_named_or_allowlisted():
    unnamed = set()
    for p in _mousearea_files():
        text = p.read_text(errors="ignore")
        if "Accessible.name" not in text and "accessibleName" not in text:
            unnamed.add(str(p.relative_to(ROOT)))
    assert unnamed == set(ALLOWLIST), (
        f"unnamed not allowlisted: {sorted(unnamed - set(ALLOWLIST))}; "
        f"stale allowlist entries: {sorted(set(ALLOWLIST) - unnamed)}")


def test_allowlist_reasons_are_real():
    for path, reason in ALLOWLIST.items():
        assert len(reason) >= 20, f"{path}: reason too thin"
        assert (ROOT / path).exists(), f"{path}: allowlisted file gone"


def test_named_controls_carry_meaningful_names():
    for path, needles in NAMED_EXPECTATIONS.items():
        text = (ROOT / path).read_text(errors="ignore")
        assert "Accessible.role" in text, f"{path}: name without role"
        for n in needles:
            assert n in text, f"{path}: expected name source {n!r} missing"
