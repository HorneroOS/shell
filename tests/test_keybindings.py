"""Keys tab contract: the dashboard keybindings cheatsheet must stay
typeable and cute.

Regression cover for the broken-search era: the drawers surface kept
`WlrKeyboardFocus.None` while only the dashboard was open, so keystrokes
never reached the search field. The tab must also autofocus its search
when it becomes current (launcher-style) and keep its keycap-chip
visual contract (group cards, per-key chips, result count)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DRAWERS = ROOT / "modules" / "drawers" / "Drawers.qml"
CONTENT = ROOT / "modules" / "dashboard" / "Content.qml"
KEYS = ROOT / "modules" / "dashboard" / "Keybindings.qml"


def test_drawers_take_keyboard_focus_for_dashboard():
    text = DRAWERS.read_text()
    m = re.search(r"WlrLayershell\.keyboardFocus:\s*(.+)", text)
    assert m, "keyboardFocus binding missing in Drawers.qml"
    assert "visibilities.dashboard" in m.group(1), (
        "dashboard must join the OnDemand keyboard-focus set or its "
        "text inputs never receive keystrokes")


def test_keys_tab_autofocuses_search_when_current():
    text = KEYS.read_text()
    assert "property bool isCurrent" in text
    assert re.search(r"onIsCurrentChanged[\s\S]*?forceActiveFocus\(\)", text), (
        "Keys tab must force search focus when it becomes current")
    content = CONTENT.read_text()
    assert re.search(r"Keybindings\s*\{\s*isCurrent:", content), (
        "dashboard Content must drive Keybindings.isCurrent")


def test_keys_search_filters_and_counts():
    text = KEYS.read_text()
    assert "placeholderText" in text, "search needs an affordance hint"
    assert re.search(r"onTextChanged:\s*root\.query\s*=\s*text", text)
    assert "function matches(row" in text
    assert "filteredCount()" in text, "result count must reflect the filter"


def test_keys_cozy_visual_contract():
    text = KEYS.read_text()
    assert "component Keycap" in text, "key combos render as keycap chips"
    assert ".parts" in text, "chips split mods from key"
    assert "m3surfaceContainerHighest" in text
    assert "function iconFor" in text
    for group in ("Launch & apps", "Shell", "Workspaces", "Windows", "System"):
        assert group in text, f"group missing: {group}"
    assert "m3primaryContainer" in text, "group count pill missing"
