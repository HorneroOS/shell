"""Shared controls must carry their own Accessible declarations.

These controls are reused across panes, so one declaration here
covers every call site: ToggleButton (toggle role + checked
state), CollapsibleSection headers, the SearchBar clear button,
CustomSpinBox steppers, SplitButton halves and Welcome action
cards.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONTROLS = ROOT / "components" / "controls"


def _src(rel: str) -> str:
    return (ROOT / rel).read_text()


def test_toggle_button_is_a_named_toggle():
    src = _src("components/controls/ToggleButton.qml")
    assert "Accessible.role: Accessible.ToggleButton" in src
    assert "Accessible.checked: root.toggled" in src


def test_collapsible_header_is_a_named_button():
    src = _src("components/controls/CollapsibleSection.qml")
    assert "Accessible.role: Accessible.Button" in src
    assert "Accessible.name: root.title" in src


def test_searchbar_clear_button_is_named():
    src = _src("components/controls/SearchBar.qml")
    assert 'Accessible.name: qsTr("Clear search")' in src


def test_spinbox_steppers_are_named():
    src = _src("components/controls/CustomSpinBox.qml")
    assert 'Accessible.name: qsTr("Increase value")' in src
    assert 'Accessible.name: qsTr("Decrease value")' in src


def test_split_button_halves_are_named():
    src = _src("components/controls/SplitButton.qml")
    assert "Accessible.name: label.text" in src
    assert 'Accessible.name: qsTr("More options")' in src


def test_welcome_action_card_is_named():
    src = _src("modules/welcome/ActionCard.qml")
    assert "Accessible.name: root.title" in src
    assert "Accessible.description: root.description" in src
