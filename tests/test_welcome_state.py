"""Welcome state contract: tolerant parse/default matrix, v1->v2 migration,
single-writer horneroctl discipline, and session-guard static guarantees."""
import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
WELCOME = ROOT / "modules" / "welcome"
STATE_QML = WELCOME / "State.qml"
SESSION_QML = WELCOME / "Session.qml"
MODEL_JS = ROOT / "services" / "welcome_model.js"

SCHEMA_VERSION = 1
DEFAULT_REVISION = "p1"


def _run_model_parse(raw):
    node = shutil.which("node")
    assert node, "node is required to test services/welcome_model.js"
    src = MODEL_JS.read_text(encoding="utf-8").replace(".pragma library", "", 1)
    arg = json.dumps(raw)
    proc = subprocess.run(
        [node, "-e", f"{src}\nconst st = parseState({arg}); console.log(JSON.stringify(st));"],
        capture_output=True, text=True, check=True,
    )
    return json.loads(proc.stdout)


def welcome_parse(raw):
    """Python mirror / bridge to welcome_model.js parseState() for v1 matrix."""
    st = _run_model_parse("" if raw is None else raw)
    return st["showOnLogin"], st["contentRevision"], st["lastSeenContentRevision"]


def sanitize_session(raw):
    """Python mirror of Session.qml sanitize() plus the env fallback."""
    if isinstance(raw, (list, tuple)):
        for candidate in list(raw) + ["default"]:
            if candidate:
                raw = candidate
                break
    clean = re.sub(r"[^A-Za-z0-9_-]", "_", str(raw or ""))[:64]
    return clean or "default"


def encode_canonical(show, rev="p1", seen="", first="", last=""):
    return (
        "{\n"
        f'  "schemaVersion": {SCHEMA_VERSION},\n'
        f'  "showOnLogin": {str(show).lower()},\n'
        f'  "contentRevision": "{rev}",\n'
        f'  "lastSeenContentRevision": "{seen}",\n'
        f'  "firstOpenedAt": "{first}",\n'
        f'  "lastOpenedAt": "{last}"\n'
        "}\n"
    )


PARSE_CASES = [
    ("missing_file", None, (True, "p2", "")),
    ("empty_file", "", (True, "p2", "")),
    ("explicit_true", encode_canonical(True), (True, "p1", "")),
    ("explicit_false", encode_canonical(False), (False, "p1", "")),
    ("malformed", "{not json", (True, "p2", "")),
    ("json_array", "[1, 2]", (True, "p2", "")),
    ("json_null", "null", (True, "p2", "")),
    ("json_string", '"hello"', (True, "p2", "")),
    ("wrong_version", '{"schemaVersion": 99, "showOnLogin": false}', (True, "p2", "")),
    ("missing_version", '{"showOnLogin": false}', (True, "p2", "")),
    ("missing_show", '{"schemaVersion": 1}', (True, "p2", "")),
    ("show_wrong_type", '{"schemaVersion": 1, "showOnLogin": "yes"}', (True, "p2", "")),
    ("show_null", '{"schemaVersion": 1, "showOnLogin": null}', (True, "p2", "")),
    ("extra_keys_ignored", '{"schemaVersion": 1, "showOnLogin": false, "future": {"x": 1}, "v": 2}', (False, "p1", "")),
    ("revision_missing_keeps_show", '{"schemaVersion": 1, "showOnLogin": false}', (False, "p1", "")),
    ("revision_wrong_type_keeps_show", '{"schemaVersion": 1, "showOnLogin": false, "contentRevision": 7}', (False, "p1", "")),
    ("revision_seen", '{"schemaVersion": 1, "showOnLogin": true, "contentRevision": "p1", "lastSeenContentRevision": "p1"}', (True, "p1", "p1")),
    ("seen_wrong_type", '{"schemaVersion": 1, "showOnLogin": true, "lastSeenContentRevision": 3}', (True, "p1", "")),
    ("opt_out_wins_over_new_content", '{"schemaVersion": 1, "showOnLogin": false, "contentRevision": "p2"}', (False, "p2", "")),
]


@pytest.mark.parametrize(("name", "raw", "expected"),
                         [(n, r, e) for n, r, e in PARSE_CASES],
                         ids=[n for n, _, _ in PARSE_CASES])
def test_parse_matrix(name, raw, expected):
    assert welcome_parse(raw) == expected, name


def test_encode_key_order_is_canonical():
    text = encode_canonical(False, rev="p2", seen="p1")
    keys = re.findall(r'"(\w+)":', text)
    assert keys == ["schemaVersion", "showOnLogin", "contentRevision",
                    "lastSeenContentRevision", "firstOpenedAt", "lastOpenedAt"]
    assert welcome_parse(text) == (False, "p2", "p1")


SANITIZE_CASES = [
    ("wayland-1", "wayland-1"),
    ("c1", "c1"),
    ("a/b:c.d", "a_b_c_d"),
    ("wayland 1", "wayland_1"),
    ("", "default"),
    ("!!!", "___"),
    ("x" * 100, "x" * 64),
    ("sess-01_ok", "sess-01_ok"),
]


@pytest.mark.parametrize(("raw", "expected"), SANITIZE_CASES)
def test_sanitize_cases(raw, expected):
    assert sanitize_session(raw) == expected


def test_session_env_fallback_order():
    assert sanitize_session(["", "", ""]) == "default"
    assert sanitize_session(["sess", "wayland-1", "default"]) == "sess"
    assert sanitize_session(["", "wayland-1", "default"]) == "wayland-1"


def test_state_qml_tolerant_reader():
    text = STATE_QML.read_text()
    assert "FileView" in text
    assert 'Paths.state' in text and '/welcome/state.json' in text
    assert "welcome_model.js" in text
    assert "WelcomeModel.parseState" in text


def _strip_comments(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return "\n".join(line.split("//")[0] for line in text.splitlines())


def test_state_qml_single_writer_only_horneroctl():
    text = _strip_comments(STATE_QML.read_text())
    for banned in ("rename", "writeFile", "write(", "DataStream", "TextStream",
                   "openUrl", "state.json\" +", "state.json' +"):
        assert banned not in text, f"State.qml must not write directly ({banned})"
    assert "execDetached" not in text, "State.qml must use the queued Process writer"
    enqueued = re.findall(r"_enqueue\(\s*\[(.*?)\]", text, re.DOTALL)
    assert enqueued, "expected horneroctl writes enqueued in State.qml"
    for argv in enqueued:
        assert "horneroctl" in argv, f"non-horneroctl spawn: {argv}"
        assert "welcome" in argv, f"horneroctl spawn outside welcome contract: {argv}"
        assert "--yes" in argv, f"mutation without --yes: {argv}"
    pumps = re.findall(r"writer\.command\s*=", text)
    assert len(pumps) == 1, f"single writer must assign command exactly once, found {len(pumps)}"


def test_session_qml_guard_shape():
    text = _strip_comments(SESSION_QML.read_text())
    assert "FileView" in text
    assert "seen-" in text
    assert "XDG_SESSION_ID" in text
    assert "WAYLAND_DISPLAY" in text
    assert "shouldAutoOpen" in text
    assert "noteAlreadySeen" in text
    assert "showOnLogin" in text
    assert "[^A-Za-z0-9_-]" in text
    assert "execDetached" not in text
    assert "Process" in text
    for banned in ("rm ", "rm\"", "sudo", "sh -c", "bash -c", "eval ", "$("):
        assert banned not in text, f"Session.qml must not run {banned!r}"
    assert "horneroctl" not in text
