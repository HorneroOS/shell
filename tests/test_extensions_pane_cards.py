"""Extensions pane cards (shell#470): installed extensions read like native
rows (icon, name, quiet version, manifest description, placement/trust/state
chips); hashes and the raw revision live in Details only."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PANE = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text(encoding="utf-8")
SERVICE = (ROOT / "services/Plugins.qml").read_text(encoding="utf-8")
HOST = (ROOT / "modules/plugins/PluginHost.qml").read_text(encoding="utf-8")


def test_manifest_description_reaches_the_entries():
    assert "Plugins.markDescription(slot.modelData.id, manifest.description);" in HOST
    fn = SERVICE[SERVICE.index("function markDescription("):]
    assert "(current.description || \"\") === text" in fn  # unchanged: no reassignment
    assert "text.length <= 400" in SERVICE


def test_cards_show_description_and_chips_and_hide_hashes_by_default():
    assert "text: row.modelData.description ?? \"\"" in PANE
    for fn in ("placementIcon", "placementLabel", "trustLabel"):
        assert f"function {fn}(" in PANE
    assert PANE.count("ExtensionChip {") >= 3
    hashes = PANE[PANE.index('qsTr("Catalogue revision: %1\\nExpected payload SHA-256: %2")') - 400:]
    assert "visible: root.expandedPluginId === row.modelData.id &&" in hashes


def test_sandbox_warning_is_the_header_intro():
    header = PANE[PANE.index("PaneHeader {"):PANE.index("PaneHeader {") + 400]
    assert re.search(r"intro: qsTr\(\"Every enabled QML plugin runs as your user without a sandbox", header)
