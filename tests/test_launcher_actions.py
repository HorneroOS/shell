"""Launcher actions: shipped defaults stay visible despite persisted overrides.

Static QML contract tests (no compositor needed): shell.json
wholesale-replaces Config.launcher.actions, so Actions.qml must merge
baked-in defaults by name instead of trusting the persisted list.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ACTIONS = (ROOT / "modules" / "launcher" / "services" / "Actions.qml").read_text()
DEFAULTS = (ROOT / "config" / "LauncherConfig.qml").read_text()


def test_welcome_action_shipped_in_defaults():
    assert re.search(r'name:\s*"Welcome"', DEFAULTS), "no Welcome default action"
    # The welcome IPC handler requires its page argument: an arg-less
    # open is rejected ("Too few arguments"), so the shipped command
    # must name the start page explicitly.
    m = re.search(r'name:\s*"Welcome".*?command:\s*\[(.*?)\]',
                  DEFAULTS, re.DOTALL)
    assert m, "Welcome default has no command"
    assert '"start"' in m.group(1), \
        "Welcome command must pass the start page explicitly"


def test_actions_merge_baked_defaults_by_name():
    # A pristine defaults instance must exist alongside the live config.
    assert "bakedDefaults" in ACTIONS, "no baked-defaults instance"
    assert re.search(r"LauncherConfig\s*\{", ACTIONS), \
        "baked defaults must come from LauncherConfig"
    # Merge keyed by action name: persisted edits win, new defaults appear.
    assert "byName" in ACTIONS or "by_name" in ACTIONS, "no by-name merge"
    assert "bakedDefaults.actions" in ACTIONS, "defaults list not merged"


def test_actions_never_trust_persisted_list_alone():
    # The old wholesale-replace expression must be gone: every shipped
    # default would otherwise stay invisible for existing users.
    bare = re.search(r"model:\s*Config\.launcher\.actions\.filter", ACTIONS)
    assert bare is None, "persisted list used without defaults merge"


CONTENT = (ROOT / "modules" / "launcher" / "Content.qml").read_text()


def test_ask_hornero_action_and_ai_prompt_route():
    m = re.search(r'name:\s*"Ask Hornero".*?command:\s*\[(.*?)\]',
                  DEFAULTS, re.DOTALL)
    assert m and '"autocomplete", "ai"' in m.group(1)
    # `>ai <prompt>` forwards to the Companion IPC; the launcher never
    # talks to Hermes or horneroctl assistant directly.
    assert '"companion", "ask", prompt' in CONTENT
    assert '"horneroctl", "assistant"' not in CONTENT


APPLIST = (ROOT / "modules" / "launcher" / "AppList.qml").read_text()


def test_windows_provider_shipped_and_focuses_via_hypr():
    m = re.search(r'name:\s*"Windows".*?command:\s*\[(.*?)\]',
                  DEFAULTS, re.DOTALL)
    assert m and '"autocomplete", "win"' in m.group(1)
    # `>win <query>` state filters compositor toplevels by title/class…
    assert '"win"' in APPLIST
    assert "Hypr.toplevels.values.filter" in APPLIST
    # …and the delegate focuses through the Hypr service only.
    item = (ROOT / "modules" / "launcher" / "items" / "WindowItem.qml").read_text()
    assert "focuswindow address:0x" in item
    assert "horneroctl" not in item


def test_file_provider_bounded_and_opens_via_xdg():
    m = re.search(r'name:\s*"Files".*?command:\s*\[(.*?)\]',
                  DEFAULTS, re.DOTALL)
    assert m and '"autocomplete", "file"' in m.group(1)
    assert '"file"' in APPLIST and "runFileSearch" in APPLIST
    # Bounded by design: depth cap, result cap, XDG dirs only.
    assert "-maxdepth 4" in APPLIST and "head -50" in APPLIST
    item = (ROOT / "modules" / "launcher" / "items" / "FileItem.qml").read_text()
    assert '"xdg-open"' in item
