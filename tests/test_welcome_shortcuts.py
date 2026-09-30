"""Welcome Shortcuts page contract: the searchable keybinding cheatsheet
lives in Welcome (moved out of the dashboard Keys tab) and must stay
typeable and cute.

Covers the move: the page is registered in nav order, the dashboard no
longer hosts a keys view, the search autofocuses when the page shows,
and the cozy visual contract (group cards, keycap chips, category
filter chips, result count) holds."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WELCOME = ROOT / "modules" / "welcome"
PAGES = WELCOME / "pages"
SHORTCUTS = PAGES / "ShortcutsPage.qml"
SHORTCUT_LIST = WELCOME / "ShortcutList.qml"
WINDOW = WELCOME / "Window.qml"
WELCOME_QML = WELCOME / "Welcome.qml"
LEARN = PAGES / "LearnPage.qml"
DASH = ROOT / "modules" / "dashboard"
DRAWERS = ROOT / "modules" / "drawers" / "Drawers.qml"
IPCDOC = ROOT / "docs" / "IPC.md"


def test_shortcuts_page_registered_in_nav_order():
    assert SHORTCUTS.is_file(), "welcome Shortcuts page missing"
    window = WINDOW.read_text()
    assert 'id: "shortcuts"' in window, "navPages missing shortcuts entry"
    stack = window.split("StackLayout", 1)[1]
    assert "ShortcutsPage {}" in stack, "StackLayout missing ShortcutsPage"
    assert '"shortcuts"' in WELCOME_QML.read_text(), \
        "Welcome.qml pages missing shortcuts"


def test_dashboard_keys_tab_removed():
    tabs = (DASH / "Tabs.qml").read_text()
    assert "Keys" not in tabs, "dashboard Keys tab must move to Welcome"
    content = (DASH / "Content.qml").read_text()
    assert "Keybindings" not in content, "dashboard Keybindings pane remains"
    assert not (DASH / "Keybindings.qml").exists(), \
        "dashboard Keybindings.qml must move to Welcome"


def test_shortcuts_search_typeable():
    assert SHORTCUT_LIST.is_file(), "ShortcutList component missing"
    text = SHORTCUT_LIST.read_text()
    assert "placeholderText" in text, "search needs an affordance hint"
    assert re.search(r"onTextChanged:\s*root\.query\s*=\s*text", text)
    assert "function matches(row" in text
    page = SHORTCUTS.read_text()
    assert re.search(r"onVisibleChanged[\s\S]*?focusSearch\(\)", page), (
        "Shortcuts page must focus search when shown")
    assert "Layout." not in page, "page files stay Layout-free (see ActionCard pattern)"


def test_drawers_keep_dashboard_keyboard_focus():
    text = DRAWERS.read_text()
    m = re.search(r"WlrLayershell\.keyboardFocus:\s*(.+)", text)
    assert m, "keyboardFocus binding missing in Drawers.qml"
    # keyboardFocus follows the focus grab (#84); the dashboard reaches
    # OnDemand through the grab on explicit opens and on a click inside
    # a hover-opened dashboard (its rename field).
    assert "focusGrab.active" in m.group(1)
    grab = next(line for line in text.splitlines() if line.strip().startswith("active:"))
    assert "visibilities.dashboard" in grab, (
        "dashboard must stay in the focus-grab set for its text inputs")


def test_shortcuts_cozy_visual_contract():
    text = SHORTCUT_LIST.read_text()
    assert "component Keycap" in text, "key combos render as keycap chips"
    assert ".parts" in text, "chips split mods from key"
    assert "component FilterChip" in text, "group filter chips missing"
    assert "function iconFor" in text
    for group in ("Launch & apps", "Shell", "Workspaces", "Windows", "System"):
        assert group in text, f"group missing: {group}"
    assert "m3primaryContainer" in text, "group count pill missing"
    assert "ShortcutHints.entries" in text, (
        "page must reuse the ShortcutHints data layer, not reload")


def test_learn_page_links_shortcuts():
    text = LEARN.read_text()
    assert 'Actions.openWelcome("shortcuts")' in text, (
        "Learn cheatsheet card must deep-link the Shortcuts page")


def test_ipc_docs_list_shortcuts_page():
    text = IPCDOC.read_text()
    assert "shortcuts" in text, "docs/IPC.md welcome pages must list shortcuts"


def test_shortcut_labels_are_human_readable():
    """Cheatsheet rows must describe actions, not dispatcher internals.

    Regression: rows rendered raw manifest ids (Centerwindow unnamed,
    Killactive unnamed, Layoutmsg colresize conf). describe() translates
    dispatcher+args using the config keybindings wording; unknown pairs
    fall back to a prettified dispatcher, never a raw id.
    """
    text = SHORTCUT_LIST.read_text()
    assert "function describe(entry" in text, "ShortcutList needs describe()"
    assert "root.describe(e)" in text, "rows must render describe(), not humanize(id)"
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
    assert "unnamed" not in text.lower(), "raw :unnamed ids must not leak into labels"


def test_shortcut_entries_keep_manifest_args():
    """ShortcutHints.entries must carry manifest args, not drop them.

    Regression: parse() built entries as {id, dispatcher, mods, key},
    so describe() saw empty args and every layoutmsg/fullscreen row
    fell back to a bare dispatcher label ("Layoutmsg", "Fullscreen").
    """
    hints = (WELCOME / "ShortcutHints.qml").read_text()
    assert re.search(r"all\.push\(\{[^}]*\bargs\b", hints), (
        "entries must forward the manifest args field to the cheatsheet")


def test_shortcut_keycaps_use_printed_glyphs():
    """Keycap chips show what is printed on the key, not XKB names.

    Regression: pills rendered raw XKB names ("SUPER apostrophe",
    "SUPER comma", "SUPER minus"). keyGlyph() translates symbolic key
    names; unknown names pass through (never blank).
    """
    text = SHORTCUT_LIST.read_text()
    assert "function keyGlyph(key" in text, "ShortcutList needs keyGlyph()"
    assert "root.keyGlyph(entry.key)" in text, "chips must render keyGlyph(), not raw key"
    for pair in ('"apostrophe": "\'"', '"comma": ","', '"minus": "-"',
                 '"equal": "="', '"slash": "/"', '"question": "?"',
                 '"escape": "Esc"', '"mouse:272": "Left click"'):
        assert pair in text, f"keycap glyph missing: {pair}"
    assert "XF86" in text, "media keys must prettify the XF86 prefix"
