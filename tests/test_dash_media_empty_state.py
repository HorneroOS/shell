"""Dash media empty-state contract: with no active player the dash media
card must read as one deliberate placeholder, not three repeated
"No media" lines (website showroom caught the triple). Mirrors the
Media tab pattern: title keeps the single fallback, album hides when
inactive, artist shows the friendly hint. Kept in its own file so this
slice never conflicts with other dashboard test edits."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MEDIA = ROOT / "modules" / "dashboard" / "dash" / "Media.qml"


def test_dash_media_empty_state_says_no_media_once():
    text = MEDIA.read_text()
    assert text.count("No media") == 1, \
        "dash media must fall back to 'No media' exactly once"
    assert "visible: !!Players.active" in text, \
        "dash media album line must hide when no player is active"
    assert "Play some music for stuff to show up here!" in text, \
        "dash media artist line must show the friendly empty hint"
