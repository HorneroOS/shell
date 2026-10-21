"""S4 focus/keyboard contract: one implementation, no ad-hoc dupes.

Interactive.qml owns Tab stop + Enter/Space activation + outer ring +
focus-reason report for StateLayer-based controls. Templates-based
controls keep native key handling and only gain the shared ring.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTROLS = ROOT / "components" / "controls"
CONTROL_CENTER = ROOT / "modules" / "controlcenter"


def _state_layer_blocks(source: str):
    """Return complete StateLayer blocks without matching nested items."""
    start = 0
    while (index := source.find("StateLayer {", start)) >= 0:
        opening = index + len("StateLayer ")
        depth = 0
        quote = None
        escaped = False
        line_comment = False
        block_comment = False
        cursor = opening
        while cursor < len(source):
            char = source[cursor]
            following = source[cursor + 1] if cursor + 1 < len(source) else ""
            if line_comment:
                if char == "\n":
                    line_comment = False
            elif block_comment:
                if char == "*" and following == "/":
                    block_comment = False
                    cursor += 1
            elif quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
            elif char == "/" and following == "/":
                line_comment = True
                cursor += 1
            elif char == "/" and following == "*":
                block_comment = True
                cursor += 1
            elif char in ("'", '"', "`"):
                quote = char
            elif char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    end = cursor + 1
                    yield source[index:end]
                    start = end
                    break
            cursor += 1
        else:
            raise AssertionError("unclosed StateLayer block")


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


def test_control_center_activations_use_the_keyboard_interactive_layer():
    """Clickable rows are keyboard controls; only the custom list and text
    editor keep mouse-only StateLayers for their existing keyboard model."""
    mouse_only = {
        CONTROL_CENTER / "SettingsSearch.qml",
        CONTROL_CENTER / "network" / "WirelessPasswordDialog.qml",
    }
    remaining = {}
    for path in CONTROL_CENTER.rglob("*.qml"):
        for block in _state_layer_blocks(path.read_text()):
            if "onClicked" in block:
                remaining[path] = remaining.get(path, 0) + 1

    assert remaining == {path: 1 for path in mouse_only}

    settings_search = (CONTROL_CENTER / "SettingsSearch.qml").read_text()
    assert "Qt.Key_Down" in settings_search and "Qt.Key_Return" in settings_search
    password_dialog = (CONTROL_CENTER / "network" / "WirelessPasswordDialog.qml").read_text()
    assert "passwordContainer.forceActiveFocus()" in password_dialog


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


def test_bluetooth_fab_actions_cannot_fire_after_menu_closes():
    src = (CONTROL_CENTER / "bluetooth" / "Details.qml").read_text()
    action = src.split("// These menu actions remain", 1)[1]
    action = action.split("RowLayout {\n                    id: fabMenuItemInner", 1)[0]
    assert "disabled: !root.session.bt.fabMenuOpen" in action
    assert "if (!root.session.bt.fabMenuOpen)" in action
    assert "fabState.forceActiveFocus()" in action
    assert action.index("fabState.forceActiveFocus()") < action.index(
        "root.session.bt.fabMenuOpen = false"
    )
    assert action.index("if (!root.session.bt.fabMenuOpen)") < action.index(
        "root.session.bt.fabMenuOpen = false"
    )
def test_floating_settings_close_button_is_keyboard_accessible():
    src = (ROOT / "modules" / "controlcenter" / "WindowTitle.qml").read_text()
    assert "Interactive {" in src
    assert "Accessible.role: Accessible.Button" in src
    assert 'Accessible.name: qsTr("Close Settings window")' in src
    assert 'Accessible.description: qsTr("Close the floating Settings window")' in src


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


def test_status_popout_keyboard_intent_does_not_steal_focus_on_hover():
    """Status cards opened by keyboard join the existing focus root; ordinary
    hover remains grab-free so bar previews never steal typing."""
    status = (ROOT / "modules" / "bar" / "components" / "StatusIcons.qml").read_text()
    bar = (ROOT / "modules" / "bar" / "Bar.qml").read_text()
    wrapper = (ROOT / "modules" / "bar" / "popouts" / "Wrapper.qml").read_text()
    drawers = (ROOT / "modules" / "drawers" / "Drawers.qml").read_text()

    assert "Accessible.role: Accessible.Button" in status
    assert "Keys.onReturnPressed" in status and "Keys.onSpacePressed" in status
    assert "root.popoutRequested(name, this)" in status
    assert "popouts.keyboardIntent = true" in bar
    hover_handler = bar.split("function checkPopoutAt", 1)[1].split("function handleWheelAt", 1)[0]
    assert hover_handler.index("popouts.keyboardIntent = false") < hover_handler.index("const hit = entryAt")
    assert "if (!hasCurrent)" in wrapper and "keyboardIntent = false" in wrapper
    assert "panels.popouts.keyboardIntent && panels.popouts.hasCurrent" in drawers


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


def test_lock_controls_have_accessible_names():
    # #221 slice 1: the safety-critical lock controls must be named:
    # the password field (EditableText with usage description) and
    # the icon-only Unlock button.
    center = (ROOT / "modules/lock/Center.qml").read_text(encoding="utf-8")
    field = (ROOT / "modules/lock/InputField.qml").read_text(encoding="utf-8")
    assert 'Accessible.role: Accessible.Button' in center
    assert 'Accessible.name: qsTr("Unlock")' in center
    assert 'Accessible.role: Accessible.EditableText' in field
    assert 'Accessible.name: qsTr("Password")' in field


def test_launcher_rows_have_accessible_names():
    # #221 slice 2: every clickable launcher row is a custom Item, so
    # without an explicit name it is invisible to assistive tech. Each
    # row must expose Button role + a name from its visible label.
    items = ROOT / "modules/launcher/items"
    for name in (
        "ActionItem.qml",
        "AiItem.qml",
        "AppearanceItem.qml",
        "AppItem.qml",
        "CalcItem.qml",
        "FileItem.qml",
        "SchemeItem.qml",
        "VariantItem.qml",
        "WallpaperItem.qml",
        "WindowItem.qml",
    ):
        src = (items / name).read_text(encoding="utf-8")
        assert "Accessible.role: Accessible.Button" in src, name
        assert "Accessible.name:" in src, name


def test_dashboard_cards_have_accessible_names():
    # #221 slice 3: dashboard workspace/window cards and quick-toggle
    # chips are custom clickable Items/Rects; name them from their
    # visible labels. Static evidence only, no AT-SPI claim.
    dash = ROOT / "modules/dashboard/dash"
    for name in ("WorkspaceCard.qml", "SpecialWsCard.qml", "WindowListItem.qml", "QuickToggles.qml"):
        src = (dash / name).read_text(encoding="utf-8")
        assert "Accessible.role: Accessible.Button" in src, name
        assert "Accessible.name:" in src, name
    window_item = (dash / "WindowListItem.qml").read_text(encoding="utf-8")
    assert 'qsTr("Toggle floating")' in window_item
    assert 'qsTr("Close window")' in window_item


def test_shared_controls_have_accessible_names():
    # #221 slice 4: the shared controls carry names into every Control
    # Center pane that uses them. Text-bearing buttons name themselves
    # from their visible label; icon-only buttons and sliders expose
    # an accessibleName the caller fills in.
    controls = ROOT / "components/controls"
    for name in ("TextButton.qml", "IconTextButton.qml", "ButtonBase.qml"):
        src = (controls / name).read_text(encoding="utf-8")
        assert "Accessible.role: Accessible.Button" in src, name
        assert "Accessible.name: label.text" in src, name
    icon_button = (controls / "IconButton.qml").read_text(encoding="utf-8")
    assert "property string accessibleName" in icon_button
    assert "Accessible.name: root.accessibleName" in icon_button
    slider = (controls / "StyledSlider.qml").read_text(encoding="utf-8")
    assert "Accessible.role: Accessible.Slider" in slider
    assert "property string accessibleName" in slider
    radio = (controls / "StyledRadioButton.qml").read_text(encoding="utf-8")
    assert "Accessible.role: Accessible.RadioButton" in radio
    for name in ("ToggleRow.qml", "SwitchRow.qml"):
        src = (controls / name).read_text(encoding="utf-8")
        assert "Accessible.role: Accessible.CheckBox" in src, name
        assert "Accessible.name: root.label" in src, name


def test_icon_buttons_have_accessible_names():
    # #221 slice 5: icon-only IconButtons are named via accessibleName
    # at every call site (welcome close, appearance expand/reset/apply,
    # Javi chat actions, media transport, utility toggles/recordings,
    # notifications clear, workspace rename, VPN priority/delete).
    expected = {
        "modules/welcome/Window.qml": ["Close Welcome"],
        "modules/controlcenter/appearance/AppearancePane.qml": [
            "Collapse all sections", "Reset pending appearance changes",
            "Apply appearance changes"],
        "modules/controlcenter/network/VpnSettings.qml": [
            "Move VPN provider down", "Remove VPN provider"],
        "modules/dashboard/dash/WsActionsBar.qml": [
            "Confirm workspace rename", "Cancel workspace rename"],
        "modules/companion/ChatPanel.qml": [
            "Clear chat history", "Close chat", "Switch chat session",
            "New chat", "Attach file", "Record voice message"],
        "modules/dashboard/Media.qml": [
            "Previous track", "Next track", "Raise player", "Quit player"],
        "modules/utilities/cards/Record.qml": [
            "Pause recording", "Stop recording"],
        "modules/utilities/cards/Toggles.qml": [
            "Toggle Wi-Fi", "Toggle Bluetooth", "Toggle microphone",
            "Toggle game mode", "Toggle do not disturb", "Toggle VPN"],
        "modules/utilities/cards/RecordingList.qml": [
            "Expand recordings", "Play recording",
            "Open recordings folder", "Delete recording"],
        "modules/sidebar/NotifDock.qml": ["Clear all notifications"],
        "modules/layoutpicker/Content.qml": ["Close layout picker"],
    }
    for rel, names in expected.items():
        src = (ROOT / rel).read_text(encoding="utf-8")
        for name in names:
            assert f'qsTr("{name}")' in src, f"{rel}: {name}"
        assert "accessibleName:" in src, rel


def test_sliders_have_accessible_names():
    # #221 slice 6: every StyledSlider call site names itself (the
    # bar InlineSlider already carried its own Accessible name).
    expected = {
        "modules/controlcenter/components/SliderInput.qml": [
            "accessibleName: root.label"],
        "modules/controlcenter/audio/AudioPane.qml": [
            'qsTr("Output volume")', 'qsTr("Input volume")',
            "Volume for %1"],
        "modules/dashboard/Media.qml": ['qsTr("Playback position")'],
        "modules/bar/popouts/Audio.qml": ['qsTr("Volume")'],
        "modules/bar/components/InlineSlider.qml": [
            'qsTr("Volume")', 'qsTr("Brightness")'],
    }
    for rel, needles in expected.items():
        src = (ROOT / rel).read_text(encoding="utf-8")
        for needle in needles:
            assert needle in src, f"{rel}: {needle}"
