"""FileView children must be adapter-typed on current Quickshell.

Quickshell's `FileView` default property is its `adapter`
(`qs::io::FileViewAdapter*`). A bare `Connections` child inside the
`FileView` block is assigned to that property and fails config load:

    Cannot assign object of type "Connections" to property of type
    "qs::io::FileViewAdapter*"

(reported on pelicano after a quickshell update; older Quickshell
silently parented the object, which is why it shipped). The plugins
save listener belongs at Config root, next to the `FileView`.
"""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG_QML = ROOT / "config" / "Config.qml"


def _block_span(text: str, start: int) -> tuple[int, int]:
    """Return (open, close) brace indices for the block at `start`."""
    open_at = text.index("{", start)
    depth = 0
    for i in range(open_at, len(text)):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return open_at, i
    raise AssertionError("unbalanced braces")


def test_no_connections_inside_fileview():
    text = CONFIG_QML.read_text(encoding="utf-8")
    fv_at = text.index("FileView {")
    open_at, close_at = _block_span(text, fv_at)
    block = text[open_at:close_at]
    assert "Connections" not in block, (
        "Connections inside FileView is assigned to FileView.adapter "
        "and breaks config load on current Quickshell; move it to "
        "the Config root")


def test_plugins_save_connections_at_root():
    text = CONFIG_QML.read_text(encoding="utf-8")
    fv_at = text.index("FileView {")
    _, close_at = _block_span(text, fv_at)
    after = text[close_at:]
    assert "Connections {" in after, (
        "plugins onSaveRequested listener missing at Config root")
    assert "target: adapter.plugins" in after
    assert "onSaveRequested" in after
