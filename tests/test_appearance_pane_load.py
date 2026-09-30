"""AppearancePane load contract: the pane must instantiate.

Two root-level Component.onCompleted handlers are a QML compile
error ("Property value set multiple times") that fails the whole
pane load and renders a blank Settings page — with Quickshell only
logging a WARN. Pin a single root completion handler that performs
both initializations, and pin the expand-all click to the
setAllSections API (no stray undefined references).
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PANE = ROOT / "modules" / "controlcenter" / "appearance" / "AppearancePane.qml"


def test_single_root_completion_handler():
    src = PANE.read_text()
    root_level = re.findall(r"^    Component\.onCompleted", src, re.M)
    assert len(root_level) == 1, (
        f"expected exactly 1 root onCompleted, found {len(root_level)}"
    )


def test_completion_initializes_both():
    src = PANE.read_text()
    assert "_sectionsReady = true" in src
    assert "resetPendingSelections()" in src


def test_no_undefined_expand_references():
    src = PANE.read_text()
    assert "shouldExpand" not in src
    assert "root.setAllSections(!sidebarLayout.allSectionsExpanded)" in src
