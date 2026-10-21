"""Windows pane extension contract (shell#235): focus follow-mouse
and user window rules must drive the real horneroctl hypr windows
backend, read state back from status/list, and never fake Niri."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANE = ROOT / "modules" / "controlcenter" / "windows" / "WindowsPane.qml"


def pane_text() -> str:
    return PANE.read_text(encoding="utf-8")


def test_follow_mouse_wired() -> None:
    text = pane_text()
    assert '"--follow-mouse", Math.round(newValue)' in text
    assert "d.follow_mouse" in text
    assert "root.followMouse" in text


def test_rules_backend_wired() -> None:
    text = pane_text()
    assert '"horneroctl", "hypr", "windows", "rules", "list", "--json"' in text
    assert '"rules", "add", "--match", root.ruleMatch, "--pattern", root.rulePattern, "--effect", root.ruleEffect, "--yes", "--json"' in text
    assert '"rules", "remove", "--name", name, "--yes", "--json"' in text


def test_rules_apply_note_honest() -> None:
    text = pane_text()
    assert "reload" in text.lower()
    # No stale 'arrive in later slices' claim.
    assert "arrive in later slices" not in text
