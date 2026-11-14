"""Dashboard header tabs keyboard contract (#401).

Static contract in repo style (mirrors test_focus_contract.py): the
Tabs.qml TabButtons were mouse-only — Tab never reached them and
arrows/Return did nothing. They now follow the launcher/FocusMode
model: roving activeFocusOnTab, shared FocusRing, arrow/Home/End
focus traversal, Return/Enter/Space activation, Tab delegated to
the drawer trap. Escape and mouse behaviour are unchanged.

QML-runtime note: Tabs.qml binds shell singletons (PersistentProperties,
Colours, Config, Appearance via qs.*), so it cannot load under plain
qmltestrunner offscreen like the DashboardLayout/PluginKit fixtures;
this suite is the honest static evidence, no live-session claim.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABS = ROOT / "modules" / "dashboard" / "Tabs.qml"


def _src():
    return TABS.read_text(encoding="utf-8")


def _tab_component():
    src = _src()
    return src[src.index("component Tab: TabButton") :]


def test_tab_order_is_the_header_order():
    src = _src()
    labels = ["Dashboard", "Media", "Performance", "Weather", "Workspaces", "Extensions"]
    positions = [src.index(f'qsTr("{label}")') for label in labels]
    assert positions == sorted(positions)


def test_tabs_are_focusable_roving_tab_stop():
    tab = _tab_component()
    # Roving stop: only the selected tab is a Tab stop, so initial
    # focus (FocusMode.enter) lands on the current tab, not tab 0.
    assert "activeFocusOnTab: tab.current" in tab


def test_visible_focus_ring_uses_shared_convention():
    tab = _tab_component()
    assert "FocusRing {" in tab
    ring = (ROOT / "components" / "controls" / "FocusRing.qml").read_text()
    assert "Colours.focusRing" in ring
    assert "FocusMode.keyboard" in ring
    # Focus reason reported so the ring is keyboard-only, never stale
    # after a mouse click (Interactive.qml convention).
    assert "FocusMode.reportFocus(tab.pressed)" in tab


def test_tab_delegates_to_drawer_trap():
    tab = _tab_component()
    assert "Keys.onTabPressed: event => FocusMode.handleTab(tab, event, false)" in tab
    assert "Keys.onBacktabPressed: event => FocusMode.handleTab(tab, event, true)" in tab


def test_arrow_home_end_traverse_focus_only():
    tab = _tab_component()
    for key in ("onLeftPressed", "onRightPressed"):
        assert f"Keys.{key}" in tab, key
    assert "(tab.TabBar.index - 1 + bar.count) % bar.count" in tab  # Left wraps
    assert "(tab.TabBar.index + 1) % bar.count" in tab  # Right wraps
    # Home/End have no dedicated Keys signals in Qt Quick; they must
    # dispatch through Keys.onPressed on Qt.Key_Home / Qt.Key_End.
    assert "Keys.onPressed" in tab
    assert "event.key === Qt.Key_Home" in tab
    assert "event.key === Qt.Key_End" in tab
    assert "bar.itemAt(0)" in tab  # Home
    assert "bar.itemAt(bar.count - 1)" in tab  # End
    # Arrows/Home/End move focus only; switching needs an activation key.
    for key in ("onLeftPressed", "onRightPressed"):
        line = next(l for l in tab.splitlines() if f"Keys.{key}" in l)
        assert "currentTab" not in line, f"{key} must not switch tabs"
        assert "forceActiveFocus" in line
    assert "currentTab" not in tab[tab.index("Keys.onPressed"):tab.index("Keys.onReturnPressed")]


def test_only_real_qt_keys_signals_are_used():
    # Regression (#402 live failure): Keys.onHomePressed/onEndPressed
    # do not exist, so QML rejected the whole Tabs type at load.
    import re

    tab = _tab_component()
    used = set(re.findall(r"Keys\.(on\w+)", tab))
    valid = {
        "onPressed", "onTabPressed", "onBacktabPressed", "onLeftPressed",
        "onRightPressed", "onReturnPressed", "onEnterPressed", "onSpacePressed",
    }
    assert used <= valid, f"non-existent Keys signals: {used - valid}"


def test_return_enter_space_activate_focused_tab():
    tab = _tab_component()
    for key in ("onReturnPressed", "onEnterPressed", "onSpacePressed"):
        line = next(l for l in tab.splitlines() if f"Keys.{key}" in l)
        assert "root.state.currentTab = tab.TabBar.index" in line, key


def test_no_initial_focus_steal_and_escape_untouched():
    tab = _tab_component()
    # No open-time handoff in the tab row: Drawers.syncFocusRoot seeds
    # focus only when the drawer does not already own it.
    assert "Component.onCompleted" not in tab
    assert "onEscapePressed" not in _src()
    drawers = (ROOT / "modules" / "drawers" / "Drawers.qml").read_text()
    assert "!(current && FocusMode.contains(win.keyboardRoot, current))" in drawers
    assert "visibilities.dashboard = false" in drawers  # cascade unchanged


def test_mouse_behaviour_unchanged():
    src = _src()
    assert "CustomMouseArea" in src
    assert "root.state.currentTab = tab.TabBar.index;" in src  # click switches
    assert "function onWheel(event: WheelEvent): void" in src  # wheel switches
    assert "cursorShape: Qt.PointingHandCursor" in src


def test_mouse_click_clears_keyboard_focus_mode():
    # Pointer input is delegated to the CustomMouseArea, so the
    # TabButton never becomes pressed and reportFocus(tab.pressed)
    # cannot classify the arrival: the click must report pointer
    # mode explicitly or the keyboard ring stays stale after a click.
    src = _src()
    assert "FocusMode.reportPointer();" in src
    focus_mode = (ROOT / "services" / "FocusMode.qml").read_text()
    assert "function reportPointer(): void" in focus_mode
