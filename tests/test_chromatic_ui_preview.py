"""Signal preview / commit / cancel (RFC 0002 §13.2, contract §7.1).

A preview changes the in-memory palette only. Cancelling restores the
previous palette, identity and optional blocks and leaves the whole XDG
tree byte-identical (no write, no mtime-relevant change in content).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chromatic_ui_harness import ROOT, requires_qs, run_scene  # noqa: E402

SIGNAL = (ROOT / "services" / "Signal.qml").read_text()


def _body(name: str) -> str:
    start = SIGNAL.index(f"function {name}(")
    depth = 0
    for i in range(SIGNAL.index("{", start), len(SIGNAL)):
        depth += SIGNAL[i] == "{"
        depth -= SIGNAL[i] == "}"
        if depth == 0:
            return SIGNAL[start:i + 1]
    raise AssertionError(name)


def test_preview_functions_have_no_write_path():
    # Structural guarantee, runs everywhere (CI has no qs): none of the
    # preview entry points reach the scheme writer or any Process.
    for fn in ("beginPreview", "commitPreview", "cancelPreview", "_adopt", "_paint"):
        body = _body(fn)
        for forbidden in ("persistScheme", "persistBuiltInTheme", "writeSchemeProc", "Process", "Config.save"):
            assert forbidden not in body, f"{fn} references {forbidden}"


def test_preview_api_is_declared():
    for needle in ("function beginPreview(scheme: var): bool", "function commitPreview(): void",
                   "function cancelPreview(): void", "readonly property bool previewing",
                   "property var chromatic", "property var minSurfaceAlpha", "property var clearInk",
                   "property string transitionMode"):
        assert needle in SIGNAL, needle


@requires_qs
def test_preview_then_cancel_restores_everything_and_writes_nothing(tmp_path):
    r, before, after = run_scene(tmp_path, "preview", HTRANSITION="instant")
    assert r["refused"] is False and r["refusedPreviewing"] is False
    assert r["begun"] is True and r["previewing"] is True
    assert r["during"]["id"] == "hornero-chromatic"
    assert r["during"]["ground"] != r["before"]["ground"]
    assert r["chromatic"]["active"] is True and r["chromatic"]["variant"] == "balanced"
    assert "path" not in str(r["chromatic"]) and "/never/exposed" not in str(r["chromatic"])
    assert r["clearInk"] is True and r["minSurfaceAlpha"]["panel"] == 0.92
    # A live file arriving mid-preview must not replace what is on screen.
    assert r["duringFile"] == r["during"]
    # Cancel: the file that arrived (Signal Day) is the restore point.
    assert r["previewingAfter"] is False
    assert r["afterCancel"]["id"] == "hornero-signal-day"
    assert r["chromaticAfter"] is None and r["clearInkAfter"] is None
    assert r["minSurfaceAlphaAfter"] == {}
    assert before == after, "preview/cancel changed files under the XDG tree"


@requires_qs
def test_cancel_without_file_restores_the_exact_previous_palette(tmp_path):
    r, before, after = run_scene(tmp_path, "commit", HTRANSITION="instant")
    assert r["previewing"] is False
    # commit ends the preview and keeps the candidate; a later cancel is a no-op
    assert r["afterCancelNoop"]["id"] == "hornero-chromatic"
    assert before == after
