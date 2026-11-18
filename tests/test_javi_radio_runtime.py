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
    assert 'InlineAsk.ask(q, "radio")' in RADIO
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
    assert RADIO.count("root.handoffRequested(") == 1
    assert "onClicked: JaviRadio.openWorkbench()" in PANEL


def test_closing_discards_the_run_and_the_text():
    close = RADIO.split("function close()")[1].split("function ask")[0]
    # reset() (outcome idle, text cleared) runs before the cancel
    assert close.index("root.reset()") < close.index('InlineAsk.cancel("radio")')
    reset = RADIO.split("function reset()")[1].split("function close")[0]
    assert 'root.outcome = "idle"' in reset
    assert 'root.question = ""' in reset and 'root.answer = ""' in reset


def test_every_entry_point_is_wired():
    assert 'CustomShortcut' in PANEL and 'name: "javiRadio"' in PANEL
    assert 'target: "javiradio"' in PANEL
    for fn in ("function open()", "function toggle()", "function openFrom(", "function prefill(", "function close()", "function status()"):
        assert fn in PANEL, fn
    assert 'JaviRadio.openFrom("javi")' in HOST and 'JaviRadio.openFrom("menu")' in HOST
    bar = (ROOT / "modules" / "bar" / "components" / "RadioButton.qml").read_text()
    assert 'JaviRadio.toggleFrom("bar")' in bar
    assert 'roleValue: "javiRadio"' in (ROOT / "modules" / "bar" / "Bar.qml").read_text()
    assert "javiRadio" in (ROOT / "modules" / "controlcenter" / "taskbar" / "barorder.js").read_text()
    launcher = (ROOT / "config" / "LauncherConfig.qml").read_text()
    # the launcher action opens Radio in-process, never over IPC
    assert re.search(r'name:\s*"Javi Radio".*?command: \["javiradio"\]', launcher, re.S)
    actions = (ROOT / "modules" / "launcher" / "services" / "Actions.qml").read_text()
    assert 'command[0] === "javiradio"' in actions and 'JaviRadio.openFrom("launcher")' in actions
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


IPC = PANEL.split('target: "javiradio"')[1].split("LazyLoader {")[0]


def test_ipc_never_submits_and_is_always_the_untrusted_class():
    # no IPC function asks a question
    assert "function ask(" not in IPC and "JaviRadio.ask(" not in IPC
    # every open goes through the IPC classifier, never openFrom(<gesture>)
    assert "JaviRadio.openFrom(" not in IPC and "toggleFrom(" not in IPC
    assert IPC.count("JaviRadio.openFromIpc(") == 3 and "JaviRadio.prefill(" in IPC
    ipc_fn = RADIO.split("function openFromIpc(")[1].split("function prefill")[0]
    assert "Radio.ipcEntry(" in ipc_fn
    # prefill only sets the draft
    pre = RADIO.split("function prefill(")[1].split("function toggleFrom")[0]
    assert "root.draft = Radio.cleanQuestion(" in pre and "ask(" not in pre
    # the only caller of JaviRadio.ask is the input's Enter handler
    assert PANEL.count("JaviRadio.ask(") == 1
    accepted = PANEL.split("onAccepted: {")[1].split("}")[0]
    assert "JaviRadio.ask(input.text)" in accepted and "if (JaviRadio.busy)" in accepted


def test_keyboard_is_on_demand_with_focus_loss_and_escape_always_works():
    assert "WlrKeyboardFocus.Exclusive" in PANEL  # niri only, via focusMode
    assert 'JaviRadio.focusMode === "exclusive"' in PANEL and 'JaviRadio.focusMode === "ondemand"' in PANEL
    assert "Radio.focusMode(root.open && root.keyboard, Compositor.backendId)" in RADIO
    assert "HyprlandFocusGrab {" in PANEL and "onCleared: JaviRadio.focusLost()" in PANEL
    lost = RADIO.split("function focusLost()")[1].split("function escape")[0]
    assert "root.keyboard = false" in lost and "if (!root.busy)" in lost and "root.close()" in lost
    # the input is read-only (not disabled) while asking
    assert "readOnly: JaviRadio.busy" in PANEL and "enabled: !JaviRadio.busy" not in PANEL
    # Escape lives on an always-enabled FocusScope around the card
    scope = PANEL.split("FocusScope {")[1]
    assert scope.index("Keys.onEscapePressed") < scope.index("id: card")
    assert "JaviRadio.escape()" in scope and "enabled:" not in scope.split("id: card")[0]
    assert "input.Keys.onEscapePressed" not in PANEL
    # clicks claim the keyboard (an IPC open starts without it)
    assert PANEL.count("JaviRadio.claimKeyboard()") == 2
    opn = RADIO.split("function openFrom(")[1].split("function openFromIpc")[0]
    assert "Radio.grantsKeyboard(e)" in opn


def test_reopen_starts_empty():
    opn = RADIO.split("function openFrom(")[1].split("function openFromIpc")[0]
    assert "if (!root.open)\n            root.reset();" in opn
    reset = RADIO.split("function reset()")[1].split("function close")[0]
    for field in ('root.question = ""', 'root.answer = ""', 'root.draft = ""', 'root.outcome = "idle"', "root.handoffPayload = null"):
        assert field in reset, field


def test_shared_inline_ask_has_an_ownership_token():
    ia = (ROOT / "services" / "InlineAsk.qml").read_text()
    assert "property string owner" in ia and "property int generation" in ia
    assert "root.generation = root.generation + 1" in ia
    assert 'if ((who ?? "") !== "" && who !== root.owner)' in ia
    # the launcher cancels only its own run
    for f in ("Content.qml", "AppList.qml"):
        src = (ROOT / "modules" / "launcher" / f).read_text()
        assert 'InlineAsk.cancel("launcher")' in src and "InlineAsk.cancel()" not in src, f
    # Radio cancels only its own run
    for fn in ("function close()", "function cancel()"):
        body = RADIO.split(fn)[1].split("\n    function ")[0]
        assert "root.ownsAsk" in body and 'InlineAsk.cancel("radio")' in body, fn
    assert 'InlineAsk.owner === "radio" && InlineAsk.generation === root.askGeneration' in RADIO
    # the token is taken before the call (InlineAsk bumps it synchronously)
    ask = RADIO.split("function ask(")[1].split("function cancel")[0]
    assert ask.index("root.askGeneration = InlineAsk.generation + 1") < ask.index('InlineAsk.ask(q, "radio")')
    # the result is read after busy drops (InlineAsk writes it afterwards)
    assert "Qt.callLater(root.finish)" in RADIO
    fin = RADIO.split("function finish()")[1]
    assert 'root.outcome = "superseded"' in fin and "if (mine && InlineAsk.busy)" in fin


def test_workbench_handoff_carries_the_pending_payload():
    assert "signal handoffRequested(var payload)" in RADIO
    wb = RADIO.split("function openWorkbench()")[1].split("function mirror")[0]
    assert "root.handoffPayload" in wb and "root.handoffRequested(payload)" in wb
    assert "root.handoffPayload = c.kind === \"handoff\" ? InlineAsk.finalPayload : null" in RADIO
    handler = HOST.split("function onHandoffRequested(payload)")[1].split("}\n    }")[0]
    assert "assistantBridge.notePayload(payload)" in handler
    # notePayload records the pending item; it never approves
    for banned in ("approve(", "deny(", "clarify("):
        assert banned not in handler, banned


def test_nest_wiring_is_inert_without_the_habitat():
    assert "readonly property bool radioHandlesNest: true" in HOST
    assert "target: root.habitat ?? null" in HOST and "ignoreUnknownSignals: true" in HOST
    assert 'JaviRadio.openFrom("nest")' in HOST
    assert 'property: "radioBusy"' in HOST and "value: JaviRadio.busy" in HOST


def test_radio_strings_are_catalogued():
    for literal in ('qsTr("Open the Workbench")', 'qsTr("Stop")', 'qsTr("Close")'):
        assert literal not in PANEL, literal
    for key in ("radio.workbench", "radio.stop", "radio.close", "radio.superseded", "radio.clickToType"):
        assert f'JaviVoice.line("{key}")' in PANEL, key


def test_docs_do_not_claim_radio_never_starts_a_run():
    doc = (ROOT / "docs" / "JAVI_RADIO.md").read_text()
    assert "never starts an agent run" not in doc
    assert "cannot be authenticated" in doc and "`keybind`" in doc
    assert "ask <entry> <text>" not in doc
