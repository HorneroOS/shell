"""Regression contract for concurrent wallpaper hash requests."""

from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "plugin/src/Hornero/Internal/cachingimagemanager.cpp"


def test_stale_hash_completion_does_not_clear_newer_path_marker():
    source = SOURCE.read_text()
    stale_completion = source.split("if (m_path != path)", maxsplit=1)[1].split(
        "const QSize size = effectiveSize();", maxsplit=1
    )[0]

    guard = stale_completion.index("if (m_shaPath == path)")
    clear = stale_completion.index("m_shaPath = QString();")
    assert guard < clear
