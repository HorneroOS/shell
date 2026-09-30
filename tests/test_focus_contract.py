"""S4 focus/keyboard contract: one implementation, no ad-hoc dupes.

Interactive.qml owns Tab stop + Enter/Space activation + outer ring +
focus-reason report for StateLayer-based controls. Templates-based
controls keep native key handling and only gain the shared ring.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTROLS = ROOT / "components" / "controls"


def test_interactive_owns_the_contract():
    src = (CONTROLS / "Interactive.qml").read_text()
    assert "activeFocusOnTab" in src
    assert "focus: !root.disabled" in src
    for key in ("Keys.onReturnPressed", "Keys.onEnterPressed", "Keys.onSpacePressed"):
        assert key in src, f"{key} missing from Interactive"
    assert "FocusRing" in src
    assert "FocusMode.reportFocus" in src
    assert "FocusMode.reportPointer" in src


def test_focus_ring_is_shared():
    src = (CONTROLS / "FocusRing.qml").read_text()
    assert "Colours.focusRing" in src
    assert "FocusMode.keyboard" in src
    assert "anchors.margins: -2" in src  # off-shape, no layout shift


def test_focus_mode_singleton():
    src = (ROOT / "services" / "FocusMode.qml").read_text()
    assert "pragma Singleton" in src
    assert "property bool keyboard" in src


def test_focus_token_exists():
    src = (ROOT / "services" / "Colours.qml").read_text()
    assert "readonly property color focusRing" in src


def test_migrated_controls_use_interactive():
    for rel in (
        "components/controls/ButtonBase.qml",
        "components/controls/IconButton.qml",
        "components/controls/TextButton.qml",
        "components/controls/IconTextButton.qml",
        "components/controls/ToggleButton.qml",
        "components/controls/SplitButton.qml",
        "components/controls/CustomSpinBox.qml",
        "components/controls/CollapsibleSection.qml",
        "modules/welcome/ActionCard.qml",
    ):
        src = (ROOT / rel).read_text()
        assert "Interactive {" in src, f"{rel} not migrated"
        assert "StateLayer {" not in src, f"{rel} still has bare StateLayer"


def test_presentational_statelayer_stays_unfocusable():
    """SearchBar's field hover wash has no action: it must NOT gain a
    tab stop. Only the clear button migrated."""
    src = (CONTROLS / "SearchBar.qml").read_text()
    assert "StateLayer {" in src  # the hover wash stays presentational
    assert "Interactive {" in src  # the clear button migrated


def test_no_duplicated_key_tables_in_migrated_controls():
    for rel in (
        "components/controls/ButtonBase.qml",
        "components/controls/IconButton.qml",
        "components/controls/TextButton.qml",
        "components/controls/IconTextButton.qml",
        "components/controls/ToggleButton.qml",
        "components/controls/SplitButton.qml",
        "components/controls/CustomSpinBox.qml",
        "components/controls/CollapsibleSection.qml",
        "modules/welcome/ActionCard.qml",
    ):
        src = (ROOT / rel).read_text()
        for key in ("Keys.onReturnPressed", "Keys.onSpacePressed", "activeFocusOnTab"):
            assert key not in src, f"{rel} duplicates {key}"


def test_templates_controls_gain_ring_only():
    for rel in (
        "components/controls/StyledSwitch.qml",
        "components/controls/StyledSlider.qml",
        "components/controls/FilledSlider.qml",
        "components/controls/StyledRadioButton.qml",
    ):
        src = (CONTROLS / Path(rel).name).read_text()
        assert "FocusRing {" in src, f"{rel} missing ring"
        assert "FocusMode.reportFocus" in src, f"{rel} missing reason report"
        assert "Keys.onSpacePressed" not in src, f"{rel} reimplements native keys"


def test_menu_keyboard_and_escape_first():
    src = (CONTROLS / "Menu.qml").read_text()
    assert "Keys.onUpPressed" in src
    assert "Keys.onDownPressed" in src
    assert "Keys.onEscapePressed" in src
    assert "event.accepted = true" in src  # closes before S3 cascade
    assert "activeFocusOnTab: root.expanded" in src  # single roving stop
    assert "StateLayer {" in src  # items stay mouse-driven


def test_rows_have_single_tab_stop():
    """Rows focus their inner control, never row + control."""
    for rel in (
        "components/controls/SwitchRow.qml",
        "components/controls/ToggleRow.qml",
    ):
        src = (ROOT / rel).read_text()
        assert "activeFocusOnTab" not in src, f"{rel} adds a row-level stop"
        assert "StyledSwitch {" in src


def test_contract_documented():
    doc = (ROOT / "docs" / "FOCUS.md").read_text()
    assert "Interactive.qml" in doc
    assert "FocusMode" in doc
    assert "focusRing" in doc
