"""The deck host must define every member its handlers and bindings use.

Regression: #573 removed PluginDesktopWidgets.measuredNeed/noteNeed while the
frame handler and the deck binding still used them, so every measurement threw
`Property 'noteNeed' ... is not a function` on a real host (found there, not
by the offscreen harness)."""
import re
from pathlib import Path

HOST = (Path(__file__).resolve().parent.parent / "modules" / "plugins" / "PluginDesktopWidgets.qml").read_text()


def test_host_defines_what_it_uses_for_measured_need():
    assert re.search(r"property var measuredNeed\b", HOST)
    assert re.search(r"function noteNeed\(id: string, need: real\)", HOST)
    assert "root.noteNeed(id, need)" in HOST
    assert "Experience.deckItems(hints, root.measuredNeed)" in HOST


def test_every_root_function_called_in_the_host_is_defined():
    called = set(re.findall(r"root\.([a-zA-Z]+)\(", HOST))
    defined = set(re.findall(r"function ([a-zA-Z]+)\(", HOST))
    assert not (called - defined), called - defined
