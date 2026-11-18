"""QML rejects a method whose name shadows a JavaScript global ("Illegal method
name"), and the whole component then fails to load, taking every type that
imports it down with it. qmllint does not flag it and CI has no `qs`, so this
static check is the guard. Regression: JaviRadio.escape() broke Companion,
the launcher actions and the Appearance pane on main (#665)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# JS global functions/objects that QML refuses as method names.
RESERVED = {"escape", "unescape", "eval", "isNaN", "isFinite", "parseInt", "parseFloat",
            "decodeURI", "decodeURIComponent", "encodeURI", "encodeURIComponent"}


def test_no_qml_method_shadows_a_javascript_global():
    bad = []
    for path in ROOT.rglob("*.qml"):
        if any(part in {".git", "build", "node_modules"} for part in path.parts):
            continue
        for n, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
            m = re.match(r"\s*function\s+(\w+)\s*\(", line)
            if m and m.group(1) in RESERVED:
                bad.append(f"{path.relative_to(ROOT)}:{n}: {m.group(1)}")
    assert not bad, bad
