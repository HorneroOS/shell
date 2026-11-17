"""Javi Radio runtime: QML wiring and security contract (no compositor)."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMP = ROOT / "modules" / "companion"


def code(path):
    """QML source without // comments, so prose cannot trip the bans."""
    return re.sub(r"//[^\n]*", "", path.read_text())


RADIO = code(COMP / "JaviRadio.qml")
PANEL = code(COMP / "RadioPanel.qml")
HOST = (COMP / "CompanionHost.qml").read_text()


def test_radio_is_a_thin_client_over_inline_ask():
    assert "InlineAsk.ask(" in RADIO
    # no second backend: no processes, no horneroctl, no network
    for banned in ("Process", "horneroctl", "execDetached", "XMLHttpRequest", "WebSocket"):
        assert banned not in RADIO, banned
        assert banned not in PANEL, banned


def test_radio_never_approves_or_escalates():
    for banned in ("approve(", "clarify(", "askStop", "attachments", "chatMode", "Clipboard", "grim", "agent"):
        assert banned not in RADIO and banned not in PANEL, banned
    assert "Radio.classify(" in RADIO
    # the hand-off is a user action, never automatic
    assert "function openWorkbench()" in RADIO
    assert RADIO.count("handoffRequested()") == 1
    assert "onClicked: JaviRadio.openWorkbench()" in PANEL


def test_closing_discards_the_run_and_the_text():
    close = RADIO.split("function close()")[1].split("function ask")[0]
    assert close.index('root.outcome = "idle"') < close.index("InlineAsk.cancel()")
    assert 'root.question = ""' in close and 'root.answer = ""' in close


def test_every_entry_point_is_wired():
    assert 'CustomShortcut' in PANEL and 'name: "javiRadio"' in PANEL
    assert 'target: "javiradio"' in PANEL
    for fn in ("function open()", "function toggle()", "function openFrom(", "function ask(", "function close()", "function status()"):
        assert fn in PANEL, fn
    assert 'JaviRadio.openFrom("javi")' in HOST and 'JaviRadio.openFrom("menu")' in HOST
    bar = (ROOT / "modules" / "bar" / "components" / "RadioButton.qml").read_text()
    assert 'JaviRadio.toggleFrom("bar")' in bar
    assert 'roleValue: "javiRadio"' in (ROOT / "modules" / "bar" / "Bar.qml").read_text()
    assert "javiRadio" in (ROOT / "modules" / "controlcenter" / "taskbar" / "barorder.js").read_text()
    launcher = (ROOT / "config" / "LauncherConfig.qml").read_text()
    assert re.search(r'name:\s*"Javi Radio".*?"javiradio", "openFrom", "launcher"', launcher, re.S)
    assert "RadioPanel {}" in (ROOT / "shell.qml").read_text()
    assert "onHandoffRequested" in HOST


def test_closed_radio_has_no_surface_and_only_the_card_takes_input():
    assert "active: JaviRadio.open" in PANEL
    assert "mask: Region" in PANEL and "item: card" in PANEL
    assert PANEL.count("Timer {") == 0


def test_companion_is_mirrored_without_waking_it():
    mirror = RADIO.split("function mirror(")[1].split("function finish")[0]
    assert "CompanionStore.visible" in mirror and '"sleeping"' in mirror


def test_radio_section_in_pane_covers_every_setting():
    cc = ROOT / "modules" / "controlcenter" / "companion"
    pane = (cc / "CompanionPane.qml").read_text()
    section = (cc / "RadioSection.qml").read_text()
    assert "RadioSection {}" in pane
    for key in ('"enabled"', '"entryPoints.', '"clickOnJavi"', '"showInBar"', '"keepOpenAfterAnswer"', '"answerBubble"'):
        assert key in section, key
    for entry in ("shortcut", "launcher", "javi", "bar", "plugin", "menu"):
        assert f'"id": "{entry}"' in section, entry
    assert 'resetPref("radio")' in section
