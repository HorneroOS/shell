"""Extensions pane reports PluginKit 3 compatibility from facts only."""
from pathlib import Path

PANE = (Path(__file__).parent.parent / "modules/controlcenter/extensions/ExtensionsPane.qml").read_text()


def test_kit_status_uses_reported_schema_version_and_never_guesses():
    assert "function kitStatus(entry): var" in PANE
    assert "version === 3" in PANE and "version === 1 || version === 2" in PANE
    assert 'qsTr("PluginKit: not reported")' in PANE
    assert 'qsTr("Needs PluginKit 3")' in PANE


def test_both_installed_and_catalogue_rows_show_compatibility():
    assert "root.kitStatus(row.entry)" in PANE
    assert "root.kitStatus(catRow.modelData)" in PANE


def test_maturity_is_semver_only():
    assert 'major === 0 ? qsTr("Pre-1.0") : ""' in PANE


def test_intro_states_the_pluginkit3_refusal():
    assert "refused until they are ported to PluginKit 3" in PANE
