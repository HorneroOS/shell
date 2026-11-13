"""Contract tests for the PluginKit host-owned tooltip (#370).

Structural like tests/test_pluginkit_ui.py; the placement arithmetic
itself is exercised at runtime via the offscreen QML probe described in
docs/PLUGINS.md (placementFor on all four edges + clamping).
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "plugin/qml/Hornero/PluginKit"
SRC = (KIT / "UiTooltip.qml").read_text(encoding="utf-8")

INTERACTIVE = ["UiButton", "UiToggle", "UiSlider"]


def test_uitooltip_declared_in_qmldir():
    qmldir = (KIT / "qmldir").read_text(encoding="utf-8")
    assert "UiTooltip 1.0 UiTooltip.qml" in qmldir


def test_uitooltip_public_contract():
    assert "required property Item target" in SRC
    assert 'property string text: ""' in SRC
    assert "property int delay: 500" in SRC
    assert "property int timeout: 0" in SRC
    assert 'property string preferredSide: "auto"' in SRC
    for side in ("auto", "above", "below", "left", "right"):
        assert f'"{side}"' in SRC


def test_uitooltip_shows_on_hover_and_focus():
    assert "HoverHandler" in SRC
    assert "hoverHandler.hovered" in SRC
    assert "target.activeFocus" in SRC
    # Visible only while triggered, after the delay timer, with text.
    assert "root._triggered" in SRC
    assert "showTimer" in SRC
    assert "root.text.length > 0" in SRC


def test_uitooltip_escape_dismisses_and_resets():
    assert 'sequence: "Esc"' in SRC
    assert "onActivated: root.dismiss()" in SRC
    assert "function dismiss()" in SRC
    assert "_dismissed = true" in SRC
    # Dismissal clears when the trigger is left, so re-entry re-shows.
    assert "_dismissed = false" in SRC


def test_uitooltip_accessible_role_and_description():
    assert "Accessible.role: Accessible.ToolTip" in SRC
    assert "Accessible.name: root.text" in SRC
    assert "Accessible.description" in SRC
    for name in INTERACTIVE:
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        assert "Accessible.description: root.tooltipText" in src, name


def test_uitooltip_placement_flips_and_clamps():
    assert "function placementFor(" in SRC
    # Auto side: rails get right/left, bars get below/above by half.
    assert "availW * 0.18" in SRC
    assert "availW * 0.82" in SRC
    assert '"below" : "above"' in SRC or '? "below" : "above"' in SRC
    # Chosen side flips when it would clip the surface.
    for side in ("above", "below", "left", "right"):
        assert f'side = "{side}"' in SRC, side
    # Final position is always clamped inside the surface margins.
    assert "Math.max(margin, Math.min(newX, maxX))" in SRC
    assert "Math.max(margin, Math.min(newY, maxY))" in SRC
    assert "mapToItem(parent" in SRC


def test_uitooltip_repositions_on_move_and_resize():
    for handler in ("onXChanged", "onYChanged", "onWidthChanged", "onHeightChanged"):
        assert handler in SRC, handler
    # Surface (parent) resize covers scale changes.
    assert "target: root.parent" in SRC


def test_uitooltip_has_no_interactive_content():
    for forbidden in ("MouseArea", "TapHandler", "onClicked", "Button", "TextField"):
        assert forbidden not in SRC, forbidden
    assert "modal: false" in SRC
    assert "focus: false" in SRC


def test_uitooltip_uses_theme_tokens_only():
    for token in (
        "Theme.surfaceContainerHighest",
        "Theme.onSurface",
        "Theme.roundingSmall",
        "Theme.fontSizeSmall",
        "Theme.spacingSmall",
    ):
        assert token in SRC, token
    assert "qs." not in SRC
    assert "Quickshell" not in SRC


def test_interactive_controls_wire_tooltiptext_through_uitooltip():
    for name in INTERACTIVE:
        src = (KIT / f"{name}.qml").read_text(encoding="utf-8")
        assert 'property string tooltipText: ""' in src, name
        assert "UiTooltip {" in src, name
        assert "target: root" in src, name
        assert "text: root.tooltipText" in src, name
        # The pre-#370 hover-only Controls tooltip must not return.
        assert "ToolTip.visible" not in src, name
