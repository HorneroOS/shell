"""`controlCenter open <name>` must land on what it says (shell#653).

`chromatic` and `themes` are search sections of Appearance, not panes. They
used to be rejected only by luck of the registry and (on older trees) opened
the wrong pane. The IPC now resolves a name to {pane, section}; unknown names
still error. The frame-cost lock harness must stage every sibling module.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REGISTRY = (ROOT / "modules" / "controlcenter" / "PaneRegistry.qml").read_text()
SHORTCUTS = (ROOT / "modules" / "Shortcuts.qml").read_text()
FACTORY = (ROOT / "modules" / "controlcenter" / "WindowFactory.qml").read_text()
PERF = (ROOT / "tests" / "perf" / "run-framecost-lock.sh").read_text()


def _search_targets():
    block = REGISTRY.split("readonly property list<QtObject> searchTargets", 1)[1]
    return re.findall(r'string id: "([^"]+)"; readonly property string title: [^;]+; readonly property string pane: "([^"]+)"; readonly property string section: "([^"]*)"', block)


def _pane_ids():
    block = REGISTRY.split("readonly property list<QtObject> panes", 1)[1].split("searchTargets", 1)[0]
    return set(re.findall(r'readonly property string id: "([^"]+)"', block))


def test_chromatic_and_themes_are_sections_of_appearance_not_panes():
    targets = {t[0]: t for t in _search_targets()}
    assert targets["chromatic"][1:] == ("appearance", "chromatic")
    assert targets["themes"][1:] == ("appearance", "themes")
    assert "chromatic" not in _pane_ids() and "themes" not in _pane_ids()


def test_every_search_target_resolves_to_a_real_pane():
    panes = _pane_ids()
    for target_id, pane, _section in _search_targets():
        assert pane in panes, f"{target_id} points at unknown pane {pane}"


def test_ipc_resolves_names_and_still_rejects_unknown_ones():
    assert "function resolveTarget(id: string)" in REGISTRY
    handler = SHORTCUTS.split('target: "controlCenter"', 1)[1].split("function close", 1)[0]
    assert "PaneRegistry.resolveTarget(id)" in handler
    assert "error: unknown control-center pane" in handler
    assert "section: target.section" in handler


def test_window_reveals_the_section_on_open_and_reopen():
    assert "function openTarget(pane: string, section: string)" in FACTORY
    assert "existing.openTarget(pane," in FACTORY
    assert "cc.session.navigateTo(pane, section)" in FACTORY


def test_lock_framecost_harness_links_sibling_modules():
    assert 'cp -r "$repo/modules/lock" "$scratch/modules/lock"' in PERF
    assert 'ln -sfn "$m" "$scratch/modules/$(basename "$m")"' in PERF
