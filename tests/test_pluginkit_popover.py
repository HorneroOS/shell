"""Contract tests for the PluginKit host-owned popover (#371).

Structural like tests/test_pluginkit_tooltip.py; placement arithmetic,
initial/return focus, Escape dismissal and press-outside behaviour are
also exercised at runtime via an offscreen QML probe (stub Theme,
PySide6) run manually against this file.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "plugin/qml/Hornero/PluginKit"
SRC = (KIT / "UiPopover.qml").read_text(encoding="utf-8")


def test_uipopover_declared_in_qmldir():
    qmldir = (KIT / "qmldir").read_text(encoding="utf-8")
    assert "UiPopover 1.0 UiPopover.qml" in qmldir


def test_uipopover_public_contract():
    assert "required property Item target" in SRC
    assert 'property string accessibleName: ""' in SRC
    assert 'property string preferredSide: "auto"' in SRC
    assert "property int contentPadding: Theme.spacing" in SRC
    assert "property Item initialFocusItem: null" in SRC
    assert "default property alias content: container.data" in SRC
    assert "function toggle()" in SRC
    assert "property string actualSide" in SRC
    for side in ("auto", "above", "below", "left", "right"):
        assert f'"{side}"' in SRC


def test_uipopover_is_host_owned_popup_not_a_window():
    # Anchored Popup in the trigger's surface, never a plugin window.
    assert "Popup {" in SRC
    assert "Window" not in SRC
    assert "Quickshell" not in SRC
    assert "qs." not in SRC
    # Surface (window-root) parent picks the trigger's monitor, as with
    # UiTooltip: walk from the target to the topmost item.
    assert "while (p && p.parent)" in SRC
    assert "mapToItem(parent" in SRC


def test_uipopover_placement_flips_and_clamps_like_tooltip():
    tooltip = (KIT / "UiTooltip.qml").read_text(encoding="utf-8")
    assert "function placementFor(" in SRC
    assert "function placementFor(" in tooltip
    # Same auto-side thresholds and clamp as UiTooltip.placementFor.
    for snippet in (
        "availW * 0.18",
        "availW * 0.82",
        '? "below" : "above"',
        "Math.max(margin, Math.min(newX, maxX))",
        "Math.max(margin, Math.min(newY, maxY))",
    ):
        assert snippet in SRC, snippet
        assert snippet in tooltip, snippet
    for side in ("above", "below", "left", "right"):
        assert f'side = "{side}"' in SRC, side
    assert "root.actualSide = placed.side" in SRC


def test_uipopover_repositions_on_move_and_resize():
    for handler in ("onXChanged", "onYChanged", "onWidthChanged", "onHeightChanged"):
        assert handler in SRC, handler
    assert "target: root.parent" in SRC
    assert "onPreferredSideChanged" in SRC


def test_uipopover_initial_focus_enters_panel():
    assert "focus: true" in SRC
    assert "onOpened" in SRC
    assert "function _focusInitial()" in SRC
    assert "root.initialFocusItem" in SRC
    assert "_firstFocusable(container)" in SRC
    assert "activeFocusOnTab" in SRC
    assert "forceActiveFocus()" in SRC


def test_uipopover_escape_closes_before_cascade_and_returns_focus():
    # Escape endpoint on the panel accepts the event, so the drawers
    # cascade (Drawers.dismissTopmost, the unhandled-Escape sink) does
    # not also fire for the same press.
    assert "Keys.onEscapePressed" in SRC
    assert "event.accepted = true" in SRC
    assert "root.dismiss()" in SRC
    assert "function dismiss()" in SRC
    assert "_returnFocusToTarget = true" in SRC
    # Focus returns to the trigger from onClosed after an Escape close.
    assert "onClosed" in SRC
    assert "root.target.forceActiveFocus()" in SRC
    # No window-level Escape shortcut: it would steal the first Escape
    # from inner transient content (cascade tier 1).
    assert 'sequence: "Esc"' not in SRC
    # Popup must not add its own Escape close path that skips the
    # focus-return bookkeeping.
    assert "CloseOnEscape" not in SRC


def test_uipopover_click_outside_closes():
    assert "closePolicy: Popup.CloseOnPressOutside" in SRC
    assert "modal: false" in SRC
    assert "dim: false" in SRC


def test_uipopover_accessible_role_and_name():
    assert "Accessible.role: Accessible.Dialog" in SRC
    assert "Accessible.name: root.accessibleName" in SRC


def test_uipopover_uses_theme_tokens_only():
    for token in (
        "Theme.surfaceContainer",
        "Theme.outlineVariant",
        "Theme.rounding",
        "Theme.spacing",
        "Theme.spacingSmall",
    ):
        assert token in SRC, token
    assert "qs." not in SRC


def test_uipopover_documented_in_plugins_doc():
    doc = (ROOT / "docs/PLUGINS.md").read_text(encoding="utf-8")
    assert "UiPopover" in doc
    assert "toggle()" in doc
