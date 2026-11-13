"""Native polkit agent contracts (shell#352, PR-1 additive slice).

Structural tests in the style of test_lock_ownership.py: the agent is
wired once, submits only on explicit confirmation, fails closed on
every dismissal, never logs or persists the secret, and no-ops when
another session agent already holds the polkit registration.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
POLKIT_DIR = ROOT / "modules" / "polkit"
HOST_QML = POLKIT_DIR / "PolkitHost.qml"
DIALOG_QML = POLKIT_DIR / "PolkitDialog.qml"
SHELL_QML = ROOT / "shell.qml"
# Installed Quickshell 0.3.2 type descriptions (present on dev hosts,
# may be absent in CI; the API-surface test then checks the names are
# at least declared consistently in our own sources).
QMLTYPES = Path(
    "/usr/lib/qt6/qml/Quickshell/Services/Polkit/"
    "quickshell-service-polkit.qmltypes"
)

# Every PolkitAgent/AuthFlow member the QML below may touch. Verified
# against quickshell-service-polkit.qmltypes (Quickshell 0.3.2):
# PolkitAgent: isRegistered, flow; AuthFlow: message, actionId,
# inputPrompt, responseVisible, supplementaryMessage,
# supplementaryIsError, isResponseRequired, isCompleted, submit(),
# cancelAuthenticationRequest(), and the authentication* signals.
FLOW_MEMBERS = [
    "message",
    "actionId",
    "inputPrompt",
    "responseVisible",
    "supplementaryMessage",
    "supplementaryIsError",
    "isResponseRequired",
    "isCompleted",
    "submit",
    "cancelAuthenticationRequest",
]
AGENT_MEMBERS = ["isRegistered", "flow"]


def _host() -> str:
    return HOST_QML.read_text()


def _dialog() -> str:
    return DIALOG_QML.read_text()


def test_module_exists_and_wired_once_in_shell_root():
    assert HOST_QML.exists()
    assert DIALOG_QML.exists()
    shell = SHELL_QML.read_text()
    assert 'import "modules/polkit"' in shell
    assert shell.count("PolkitHost {}") == 1
    # The host owns exactly one agent registration.
    assert _host().count("PolkitAgent {") == 1


def test_only_verified_qmltypes_api_is_used():
    """All flow/agent members referenced exist in the real qmltypes."""
    combined = _host() + _dialog()
    used_flow = set(re.findall(r"\.flow\.(\w+)", combined)) | set(
        re.findall(r"win\.flow\.(\w+)", combined)
    )
    assert used_flow <= set(FLOW_MEMBERS), f"unverified AuthFlow members: {used_flow}"
    used_agent = set(re.findall(r"(?:agent|polkitAgent)\.(\w+)", combined))
    assert used_agent <= set(AGENT_MEMBERS), f"unverified PolkitAgent members: {used_agent}"
    if QMLTYPES.exists():
        types = QMLTYPES.read_text()
        for member in FLOW_MEMBERS + AGENT_MEMBERS:
            assert f'"{member}"' in types or f"name: \"{member}\"" in types, member
        for signal in (
            "authenticationSucceeded",
            "authenticationFailed",
            "authenticationRequestCancelled",
            "isRegisteredChanged",
        ):
            assert signal in types, signal


def test_dialog_shows_action_id_and_message():
    src = _dialog()
    assert "win.flow.message" in src
    assert "win.flow.actionId" in src
    assert "win.flow.inputPrompt" in src
    assert "win.flow.supplementaryMessage" in src
    assert "win.flow.supplementaryIsError" in src


def test_echo_mode_bound_to_response_visible():
    src = _dialog()
    assert "responseVisible" in src
    assert "TextField.Password" in src
    assert "TextField.Normal" in src
    # Echo follows the PAM prompt, it is not a fixed Normal mode.
    assert re.search(r"echoMode:.*responseVisible.*TextField\.Normal.*TextField\.Password", src)


def test_submit_only_on_explicit_confirm():
    src = _dialog()
    # Exactly one submit site, inside confirm().
    assert src.count(".submit(") == 1
    assert "function confirm()" in src
    confirm_body = src[src.index("function confirm()") : src.index("function cancelRequest()")]
    assert ".submit(secretField.text)" in confirm_body
    assert "isResponseRequired" in confirm_body
    # Both explicit user actions route through confirm().
    assert "onAccepted: win.confirm()" in src
    assert 'qsTr("Authenticate")' in src
    assert "onClicked: win.confirm()" in src
    # No automatic submission paths in the dialog.
    assert "Timer" not in src
    assert "onTextChanged" not in src
    assert "Component.onCompleted" not in src or ".submit(" not in src.split("Component.onCompleted")[1].split("}")[0]


def test_cancel_escape_and_close_fail_closed():
    src = _dialog()
    # Exactly one cancel site, inside the cancelRequest() funnel.
    assert src.count("cancelAuthenticationRequest()") == 1
    cancel_body = src[src.index("function cancelRequest()") : src.index("onFlowChanged")]
    assert "cancelAuthenticationRequest()" in cancel_body
    # Cancel button, Escape shortcut and window close all funnel there.
    assert 'qsTr("Cancel")' in src
    assert "onClicked: win.cancelRequest()" in src
    assert '"Escape"' in src
    assert "onActivated: win.cancelRequest()" in src
    assert "onVisibleChanged" in src
    visible_body = src[src.index("onVisibleChanged") : src.index("Connections {")]
    assert "cancelRequest()" in visible_body


def test_secret_never_logged_or_persisted_and_cleared():
    combined = _host() + _dialog()
    # No log line may reference the field or its text.
    for line in combined.splitlines():
        if "console." in line:
            assert "secretField" not in line and ".text" not in line, line
    # No persistence machinery anywhere in the module.
    for token in ("FileView", "LocalStorage", "Settings {", "Persistent", "writeFile"):
        assert token not in combined, token
    src = _dialog()
    # Field clears on completion and cancellation (and submit/failure).
    assert 'secretField.text = ""' in src
    for handler in (
        "onIsCompletedChanged",
        "onAuthenticationRequestCancelled",
        "onAuthenticationSucceeded",
        "onAuthenticationFailed",
    ):
        assert handler in src, handler
    assert "function clearSecret()" in src


def test_unregistered_agent_logs_once_and_noops():
    host = _host()
    assert "polkitAgent.isRegistered" in host
    assert "_unregisteredLogged" in host
    # One guarded warning site only.
    assert host.count("console.warn") == 1
    # The dialog never shows while unregistered.
    src = _dialog()
    assert re.search(r"visible:.*agent\.isRegistered", src)


def test_additive_slice_does_not_remove_external_agent():
    """PR-1 is additive: no reference to removing polkit-gnome anywhere."""
    combined = _host() + _dialog() + SHELL_QML.read_text()
    assert "polkit-gnome" not in combined
