"""Welcome Shortcuts contract: the searchable keybinding cheatsheet lives in
Welcome (moved out of the dashboard Keys tab) and stays typeable and clear."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WELCOME = ROOT / "modules" / "welcome"
VIEWS = WELCOME / "views"
SCENES = WELCOME / "scenes"
SHORTCUTS_VIEW = VIEWS / "ShortcutsView.qml"
EXPLORE_VIEW = VIEWS / "ExploreView.qml"
SHORTCUT_LIST = WELCOME / "ShortcutList.qml"
WELCOME_QML = WELCOME / "Welcome.qml"
ARRIVAL = SCENES / "ArrivalScene.qml"
PRACTICE = SCENES / "PracticeScene.qml"
DASH = ROOT / "modules" / "dashboard"
DRAWERS = ROOT / "modules" / "drawers" / "Drawers.qml"
IPCDOC = ROOT / "docs" / "IPC.md"


def test_shortcuts_view_and_explore_registered():
    assert SHORTCUTS_VIEW.is_file(), "welcome ShortcutsView missing"
    assert EXPLORE_VIEW.is_file(), "welcome ExploreView missing"
    assert "ShortcutsView.qml" in EXPLORE_VIEW.read_text()
    assert '"shortcuts"' in WELCOME_QML.read_text()


def test_dashboard_keys_tab_removed():
    tabs = (DASH / "Tabs.qml").read_text()
    assert 'qsTr("Keys")' not in tabs, "dashboard Keys tab must move to Welcome"
    content = (DASH / "Content.qml").read_text()
    assert "Keybindings" not in content, "dashboard Keybindings pane remains"
    assert not (DASH / "Keybindings.qml").exists(), \
        "dashboard Keybindings.qml must move to Welcome"


def test_shortcuts_search_typeable():
    assert SHORTCUT_LIST.is_file(), "ShortcutList component missing"
    text = SHORTCUT_LIST.read_text()
    assert "placeholderText" in text
    assert re.search(r"onTextChanged:\s*root\.query\s*=\s*text", text)
    assert "function matches(row" in text
    view = SHORTCUTS_VIEW.read_text()
    assert re.search(r"onVisibleChanged[\s\S]*?focusSearch\(\)", view), (
        "Shortcuts view must focus search when shown")


def test_drawers_keep_dashboard_keyboard_focus():
    text = DRAWERS.read_text()
    m = re.search(r"WlrLayershell\.keyboardFocus:\s*(.+)", text)
    assert m, "keyboardFocus binding missing in Drawers.qml"
    assert "keyboardIntent" in m.group(1)
    assert "active: Compositor.isHyprland && win.keyboardIntent" in text
    keyboard_intent = next(line for line in text.splitlines() if "property bool keyboardIntent:" in line)
    assert "visibilities.dashboard" in keyboard_intent


def test_shortcuts_cozy_visual_contract():
    text = SHORTCUT_LIST.read_text()
    assert "component Keycap" in text
    assert ".parts" in text
    assert "component FilterChip" in text
    assert "function iconFor" in text
    for group in ("Launch & apps", "Shell", "Workspaces", "Windows", "System"):
        assert group in text, f"group missing: {group}"
    assert "signalWell" in text
    assert "ShortcutHints.entries" in text


def test_practice_scene_links_shortcuts():
    text = PRACTICE.read_text()
    assert 'Actions.openWelcome("shortcuts")' in text


def test_ipc_docs_list_shortcuts_page():
    text = IPCDOC.read_text()
    assert "shortcuts" in text


def test_shortcut_labels_are_human_readable():
    text = SHORTCUT_LIST.read_text()
    assert "function describe(entry" in text
    assert "root.describe(e)" in text
    for label in ("Close active window", "Move window to center",
                  "Toggle floating", "Toggle maximize",
                  "Promote focused window into its own column",
                  "Swap column with left neighbor",
                  "Swap column with right neighbor",
                  "Move viewport left one column",
                  "Narrow column", "Widen column (fine)",
                  "Fit active window to column",
                  "Drag to move window", "Drag to resize window",
                  "Go to workspace ",
                  "Move window to workspace ", "Focus window ",
                  "Toggle scratchpad"):
        assert label in text, f"cheatsheet missing label: {label}"
    assert "unnamed" not in text.lower()


def test_shortcut_entries_keep_manifest_args():
    hints = (WELCOME / "ShortcutHints.qml").read_text()
    assert re.search(r"all\.push\(\{[^}]*\bargs\b", hints)


def test_shortcut_keycaps_use_printed_glyphs():
    text = SHORTCUT_LIST.read_text()
    assert "function keyGlyph(key" in text
    assert "root.keyGlyph(entry.key)" in text
    for pair in ('"apostrophe": "\'"', '"comma": ","', '"minus": "-"',
                 '"equal": "="', '"slash": "/"', '"question": "?"',
                 '"escape": "Esc"', '"mouse:272": "Left click"'):
        assert pair in text
    assert "XF86" in text


def test_shortcuts_page_never_shows_build_wording():
    text = SHORTCUT_LIST.read_text()
    assert "Regenerate" not in text and "shortcuts manifest" not in text
    assert "visible: root.groupNames.length > 1" in text
    hints = (WELCOME / "ShortcutHints.qml").read_text()
    assert "Compositor.refreshHyprlandBinds()" in hints
    assert '["hyprctl", "binds", "-j"]' in (ROOT / "services" / "Compositor.qml").read_text()
    assert "onLoadFailed: root.fallback()" in hints


def test_arrival_scene_has_immediate_ctas():
    arrival = ARRIVAL.read_text()
    assert "Set up my desktop" in arrival
    assert "Explore Hornero" in arrival
    assert "Start using Hornero" in arrival
