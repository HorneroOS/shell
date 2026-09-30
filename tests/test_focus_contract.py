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


def test_debug_focus_state_observable():
    src = (ROOT / "modules" / "drawers" / "Drawers.qml").read_text()
    assert "function focusState(): string" in src
    # PanelWindow has no active/activeFocusItem properties: reading them
    # returned undefined and made #84 look like an activation failure.
    assert "win.contentItem.Window.activeFocusItem" in src
    assert "win.contentItem.Window.active" in src
    assert "win.activeFocusItem" not in src
    assert "win.active," not in src
    assert "FocusMode.keyboard" in src
    assert "focusGrab.active" in src


def test_tab_trap_in_every_focusable():
    """Tab stays inside the keyboard-holding drawer (#84): the bar and
    all drawers share one window and FocusScope does not confine Qt's
    tab chain, so each focusable delegates to FocusMode.handleTab."""
    for name in (
        "Interactive.qml",
        "StyledSwitch.qml",
        "StyledSlider.qml",
        "FilledSlider.qml",
        "StyledRadioButton.qml",
    ):
        src = (CONTROLS / name).read_text()
        assert "Keys.onTabPressed: event => FocusMode.handleTab(root, event, false)" in src, name
        assert "Keys.onBacktabPressed: event => FocusMode.handleTab(root, event, true)" in src, name


def test_text_field_tab_trap():
    src = (CONTROLS / "StyledTextField.qml").read_text()
    assert "FocusMode.handleTab(root, event, false)" in src
    assert "FocusMode.handleTab(root, event, true)" in src


def test_focus_mode_scopes_tab_to_current_root():
    src = (ROOT / "services" / "FocusMode.qml").read_text()
    assert "property Item currentRoot" in src
    assert "function step(from: Item, forward: bool): bool" in src
    assert "nextItemInFocusChain(forward)" in src
    drawers = (ROOT / "modules" / "drawers" / "Drawers.qml").read_text()
    assert "FocusMode.currentRoot = win.keyboardRoot" in drawers
    assert "onActiveChanged: win.syncFocusRoot()" in drawers
    assert "FocusMode.enter(" in drawers


def test_click_intent_overlay_stays_out_of_input_mask():
    """The input mask is built from panels.children; a full-size child of
    Panels would make the drawers layer swallow every desktop click
    (PR #87 review). The click-intent overlay must be a sibling."""
    src = (ROOT / "modules" / "drawers" / "Drawers.qml").read_text()
    start = src.index("                Panels {")
    end = src.index("\n                }\n", start)
    assert "PointHandler" not in src[start:end]
    assert "anchors.fill: parent" not in src[start:end]
    assert "anchors.fill: panels" in src
    assert "for (const p of panels.children)" in src


def test_launcher_vim_tab_opts_out_of_trap():
    """Qt runs onTabPressed before onPressed; vim-mode list navigation on
    Tab needs the search field to opt out of the drawer Tab trap."""
    field = (CONTROLS / "StyledTextField.qml").read_text()
    assert "property bool trapTab: true" in field
    launcher = (ROOT / "modules" / "launcher" / "Content.qml").read_text()
    assert "trapTab: !Config.launcher.vimKeybinds" in launcher
    # Shift+Tab must be matched before plain Tab.
    assert launcher.index("Qt.Key_Backtab") < launcher.index("event.key === Qt.Key_Tab) {")


def test_tab_skips_clipped_offscreen_items():
    src = (ROOT / "services" / "FocusMode.qml").read_text()
    assert "function shown(scope: Item, item: Item): bool" in src
    assert "a.clip" in src
    dash = (ROOT / "modules" / "dashboard" / "Content.qml").read_text()
    view = dash[dash.index("id: view\n"):]
    assert "clip: true" in view[:400], "dashboard view must clip for FocusMode.shown"


def test_keyboard_root_matches_grab_owner():
    """Tab must not be trapped in a hover-opened drawer that never asked
    for the keyboard while another drawer holds the grab."""
    src = (ROOT / "modules" / "drawers" / "Drawers.qml").read_text()
    line = next(l for l in src.splitlines() if "readonly property Item keyboardRoot:" in l)
    assert "interactions.dashboardKeyboardIntent" in line
    assert "interactions.utilitiesKeyboardIntent" in line
    assert "traymenu" in line
