"""Extensions pane redesign: one search for both lists, an updates
strip, catalogue category chips, replacement reveal with scroll and
focus, human setting labels without internal state, and an honest
preview fallback. Static source contracts in the repo style."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PANE = (ROOT / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text(encoding="utf-8")
SECTION = (ROOT / "modules/controlcenter/extensions/PluginSettingsSection.qml").read_text(encoding="utf-8")
PREVIEW = (ROOT / "modules/controlcenter/extensions/PluginPreviewFrame.qml").read_text(encoding="utf-8")


def test_one_search_filters_installed_and_catalogue():
    assert "function unifiedQuery(): string" in PANE
    assert "onPluginSearchChanged:" in PANE and "onCatalogSearchChanged:" in PANE
    body = PANE.split("function filteredCatalogEntries", 1)[1].split("function declaredCapabilities", 1)[0]
    assert "root.unifiedQuery()" in body
    assert "root.pluginPlacementFilter" in body and "root.catalogCategoryFilter" in body


def test_updates_strip_only_when_updates_exist():
    assert "function updateEntries(): var" in PANE
    assert "visible: root.updateEntries().length > 0" in PANE
    assert 'qsTr("Updates")' in PANE and "Store.updateText(cat, root.es)" in PANE


def test_replacement_reveal_clears_filters_scrolls_and_focuses():
    body = PANE.split("function openReplacement", 1)[1].split("function refreshCatalog", 1)[0]
    for needle in ('root.pluginTrustFilter = "all"', 'root.pluginPlacementFilter = "all"',
                   'root.catalogCategoryFilter = "all"', "flick.contentY = 0",
                   "searchField.forceActiveFocus()", "root.expandedCatalogId = pluginId"):
        assert needle in body, needle


def test_header_stays_honest_about_no_sandbox():
    header = PANE[PANE.index("PaneHeader {"):PANE.index("PaneHeader {") + 500]
    assert "without a sandbox" in header and "not enforced permissions" in header
    assert "sandboxed" not in header.split("intro:")[1].split(")")[0].replace("without a sandbox", "")


def test_settings_labels_are_human_and_internal_state_is_hidden():
    assert "function isInternalSetting(key: string): bool" in SECTION
    assert "/EpochMs$/" in SECTION and 'decl.internal === true' in SECTION
    assert "words.charAt(0).toUpperCase()" in SECTION  # humanized fallback label


def test_preview_fallback_and_escape_close_detail():
    assert 'qsTr("No preview for this extension.")' in PREVIEW
    assert "visible: root.shown" in PREVIEW
    assert "Keys.onEscapePressed:" in PANE and 'root.expandedPluginId = ""' in PANE
