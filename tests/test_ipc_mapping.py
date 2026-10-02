"""IPC mapping: every IpcHandler target in QML must be documented in
docs/IPC.md, and every documented target must exist in QML."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
QML_DIRS = [ROOT / d for d in ("modules", "services")]

TARGET_RE = re.compile(r'IpcHandler\s*\{\s*target:\s*"([^"]+)"')


def _qml_targets():
    found = {}
    for d in QML_DIRS:
        for path in d.rglob("*.qml"):
            for target in TARGET_RE.findall(path.read_text()):
                found.setdefault(target, []).append(
                    str(path.relative_to(ROOT))
                )
    return found


def _doc_targets():
    doc = (ROOT / "docs" / "IPC.md").read_text()
    return set(re.findall(r'`([a-zA-Z]+)`', doc))


def test_all_ipc_targets_documented():
    qml_targets = _qml_targets()
    doc = (ROOT / "docs" / "IPC.md").read_text()
    missing = [t for t in qml_targets if f'"{t}"' not in doc and f'`{t}`' not in doc]
    assert not missing, f"undocumented IPC targets: {missing}"
    assert len(qml_targets) >= 10, f"expected >=10 IPC targets, got {len(qml_targets)}"


def test_documented_targets_exist():
    qml_targets = _qml_targets()
    doc_targets = _doc_targets()
    known = set(qml_targets)
    orphans = [
        t
        for t in ("wallpaper", "appearance", "mpris", "notifs", "hypr",
                  "gameMode", "colours", "brightness", "drawers", "lock",
                  "welcome")
        if t not in known
    ]
    assert not orphans, f"documented IPC targets missing from QML: {orphans}"
    assert known & doc_targets, "no overlap between QML targets and IPC.md"


def _handler_functions(source, target):
    m = re.search(r'target:\s*"' + re.escape(target) + r'"(.*?)(?=target:\s*"|\Z)',
                  source, re.S)
    assert m, f"no IpcHandler for target {target!r}"
    return set(re.findall(r'function\s+(\w+)\s*\(', m.group(1)))


def test_controlcenter_keyboard_roundtrip():
    """Settings must open AND close programmatically.

    Regression: `controlCenter` only exposed `open([pane])`, so every
    open stacked a new floating window nothing could dismiss except the
    WM. `open` + `close` + single-window reuse close the loop.
    """
    shortcuts = (ROOT / "modules" / "Shortcuts.qml").read_text()
    funcs = _handler_functions(shortcuts, "controlCenter")
    assert {"open", "close"} <= funcs, (
        f"controlCenter IPC must expose open+close, found: {sorted(funcs)}"
    )

    factory = (ROOT / "modules" / "controlcenter" / "WindowFactory.qml").read_text()
    assert "function closeAll()" in factory, "WindowFactory must track and close windows"
    assert 'sequences: ["Escape"]' in factory, "Settings window must close on Escape"

    doc = (ROOT / "docs" / "IPC.md").read_text()
    assert "controlCenter close" in doc, "IPC.md must document controlCenter close"


def test_drawers_ipc_tolerates_no_active_screen():
    """drawers IPC must not throw before a screen is active (issue #97):
    every Visibilities.getForActive() result is null-checked before use."""
    src = (ROOT / "modules" / "Shortcuts.qml").read_text()
    block = src[src.index('target: "drawers"'):]
    block = block[: block.index("IpcHandler", 1)] if "IpcHandler" in block[1:] else block
    calls = [m.end() for m in re.finditer(r"Visibilities\.getForActive\(\);", block)]
    assert calls, "drawers handler no longer reads Visibilities"
    for end in calls:
        following = block[end : end + 200]
        assert re.search(r"if \(!visibilities\)|visibilities &&", following), following
    state_fn = block[block.index("function state(") :]
    state_fn = state_fn[: state_fn.index("}", state_fn.index("{")) + 1]
    assert 'drawer !== ""' in state_fn, "state() must reject empty drawer names"
